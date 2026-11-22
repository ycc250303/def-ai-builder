import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plant/data/device_client.dart';

import 'device_fixture.dart';

void main() {
  final endpoint = HttpDeviceClient.endpoint('http://192.168.4.1');

  test('解析硬件与电脑模拟来源，保留触点和触摸数据', () {
    for (final source in ['device', 'simulation']) {
      final value = DeviceSnapshot.decode(
        jsonEncode(deviceData(source: source)),
      );
      expect(value.source, source);
      expect(value.sequence, 42);
      expect(value.temperature, 24.6);
      expect(value.humidity, 61);
      expect(value.light, 480);
      expect(value.soilLevel, 'high');
      expect(value.touchMask, 5);
      expect(value.commandId, 2);
      expect(value.commandCode, 'TOUCH_DETECTED');
    }
  });

  test('传感器与设备事件的显式空值保持缺失', () {
    final data = deviceData();
    final sensors = data['sensors'] as Map<String, dynamic>;
    sensors.updateAll((_, _) => null);
    data['command'] = null;
    final value = DeviceSnapshot.decode(jsonEncode(data));
    expect([
      value.temperature,
      value.humidity,
      value.light,
      value.soilLevel,
      value.touchMask,
      value.commandId,
      value.commandCode,
    ], everyElement(isNull));
  });

  test('缺失字段、非法数值和事件格式立即暴露协议错误', () {
    final invalid = <Map<String, dynamic>>[
      {...deviceData(), 'source': 'unknown'},
      {...deviceData(), 'sequence': 1.5},
      {...deviceData(), 'sequence': -1},
      {
        ...deviceData(),
        'command': {'id': 1, 'code': 'invalid'},
      },
      {
        ...deviceData(),
        'command': {'id': '2', 'code': 'MONITORING'},
      },
      deviceData()..remove('command'),
    ];
    for (final field in [
      'temperature_c',
      'humidity_rh',
      'light_lux',
      'soil_level',
      'touch_mask',
    ]) {
      final data = deviceData();
      (data['sensors'] as Map<String, dynamic>).remove(field);
      invalid.add(data);
    }
    for (final (field, value) in [
      ('temperature_c', '24.6'),
      ('temperature_c', -41),
      ('humidity_rh', 101),
      ('light_lux', -1),
      ('soil_level', 'dry'),
      ('touch_mask', 4096),
      ('touch_mask', 0.5),
    ]) {
      final data = deviceData();
      (data['sensors'] as Map<String, dynamic>)[field] = value;
      invalid.add(data);
    }
    for (final data in invalid) {
      expect(
        () => DeviceSnapshot.decode(jsonEncode(data)),
        throwsA(isA<DeviceProtocolException>()),
      );
    }
    for (final body in ['[]', 'null', '{', '{"source":"device"}']) {
      expect(
        () => DeviceSnapshot.decode(body),
        throwsA(isA<DeviceProtocolException>()),
      );
    }
  });

  test('设备地址支持热点与电脑局域网端口，并限制访问范围', () {
    expect(endpoint.toString(), 'http://192.168.4.1/api/state');
    for (final address in [
      'http://10.0.0.2:8790',
      'http://172.16.0.2/',
      'http://127.0.0.1:8790/api/state',
    ]) {
      expect(HttpDeviceClient.endpoint(address).path, '/api/state');
    }
    for (final address in [
      'https://192.168.4.1',
      'http://example.com',
      'http://8.8.8.8',
      'http://192.168.4.1/other',
      'http://user@192.168.4.1',
      'http://192.168.4.1?x=1',
      'http://192.168.4.1#x',
      'http://172.32.0.1',
      'http://192.168.4.1:0',
      'invalid',
    ]) {
      expect(() => HttpDeviceClient.endpoint(address), throwsFormatException);
    }
  });

  test('HTTP 请求使用现有接口并禁用重定向', () async {
    final client = HttpDeviceClient(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url, endpoint);
        expect(request.followRedirects, isFalse);
        expect(request.headers['Accept'], 'application/json');
        return http.Response(jsonEncode(deviceData()), 200);
      }),
    );
    addTearDown(client.close);
    expect((await client.read(endpoint)).temperature, 24.6);
  });

  test('HTTP 错误、网络中断、超时和无效响应分别终止读取', () async {
    for (final status in [302, 404, 500]) {
      final client = HttpDeviceClient(
        client: MockClient((_) async => http.Response('', status)),
      );
      addTearDown(client.close);
      await expectLater(
        client.read(endpoint),
        throwsA(isA<DeviceConnectionException>()),
      );
    }
    final offline = HttpDeviceClient(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    addTearDown(offline.close);
    await expectLater(
      offline.read(endpoint),
      throwsA(isA<DeviceConnectionException>()),
    );
    final slow = HttpDeviceClient(
      client: MockClient((_) => Completer<http.Response>().future),
      timeout: const Duration(milliseconds: 10),
    );
    addTearDown(slow.close);
    await expectLater(
      slow.read(endpoint),
      throwsA(isA<DeviceConnectionException>()),
    );
    for (final body in ['not JSON', 'x' * 16385]) {
      final client = HttpDeviceClient(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      addTearDown(client.close);
      await expectLater(
        client.read(endpoint),
        throwsA(isA<DeviceProtocolException>()),
      );
    }
  });

  test('通过真实本地 HTTP 连接读取快照并取消未完成请求', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestStarted = Completer<void>();
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(deviceData()));
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    final client = HttpDeviceClient();
    addTearDown(client.close);
    final url = HttpDeviceClient.endpoint('http://127.0.0.1:${server.port}');
    final snapshot = await client.read(url);
    expect(snapshot.temperature, 24.6);
    // 另一个服务保留响应，验证超时会真实取消连接。
    final stalled = HttpDeviceClient(timeout: const Duration(milliseconds: 30));
    addTearDown(stalled.close);
    final stalledServer = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    stalledServer.listen((request) => requestStarted.complete());
    addTearDown(() => stalledServer.close(force: true));
    await expectLater(
      stalled.read(
        HttpDeviceClient.endpoint('http://127.0.0.1:${stalledServer.port}'),
      ),
      throwsA(isA<DeviceConnectionException>()),
    );
    expect(requestStarted.isCompleted, isTrue);
  });
}
