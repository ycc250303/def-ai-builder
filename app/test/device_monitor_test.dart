import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plant/data/device_client.dart';
import 'package:plant/data/device_monitor.dart';

import 'device_fixture.dart';

void main() {
  final endpoint = HttpDeviceClient.endpoint('http://192.168.4.1');

  testWidgets('单次请求完成后轮询，重复序号过期，新序号恢复', (tester) async {
    var now = DateTime(2026, 11, 22);
    var sequence = 42;
    final client = TestDeviceClient(
      (_) async => deviceSnapshot(sequence: sequence),
    );
    final monitor = DeviceMonitor(createClient: () => client, now: () => now);
    addTearDown(monitor.dispose);
    await monitor.connect(endpoint);
    expect(monitor.status, DeviceStatus.live);
    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(monitor.status, DeviceStatus.stale);
    expect(monitor.receivedAt, DateTime(2026, 11, 22));
    sequence = 43;
    await tester.pump(const Duration(seconds: 1));
    expect(monitor.status, DeviceStatus.live);
    expect(monitor.receivedAt, now);
    sequence = 1;
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(monitor.snapshot!.sequence, 1);
    expect(monitor.receivedAt, now);
    monitor.stop();
    final reads = client.reads;
    await tester.pump(const Duration(seconds: 3));
    expect(client.reads, reads);
    expect(client.closed, isTrue);
  });

  testWidgets('等待响应时不并发请求，重新连接丢弃之前的响应', (tester) async {
    final pending = Completer<DeviceSnapshot>();
    final first = TestDeviceClient((_) => pending.future);
    final second = TestDeviceClient((_) async => deviceSnapshot(sequence: 99));
    final clients = [first, second];
    final monitor = DeviceMonitor(createClient: () => clients.removeAt(0));
    addTearDown(monitor.dispose);
    final oldRead = monitor.connect(endpoint);
    await tester.pump(const Duration(seconds: 4));
    expect(first.reads, 1);
    await monitor.connect(endpoint);
    expect(first.closed, isTrue);
    expect(monitor.snapshot!.sequence, 99);
    pending.complete(deviceSnapshot());
    await oldRead;
    expect(monitor.snapshot!.sequence, 99);
  });

  testWidgets('连接与协议错误停止读取并清除读数，手动重连恢复', (tester) async {
    for (final failure in [
      const DeviceConnectionException('offline'),
      const DeviceProtocolException('Invalid humidity_rh'),
    ]) {
      var fail = false;
      final client = TestDeviceClient((_) async {
        if (fail) throw failure;
        return deviceSnapshot();
      });
      final monitor = DeviceMonitor(createClient: () => client);
      await monitor.connect(endpoint);
      fail = true;
      await tester.pump(const Duration(seconds: 1));
      expect(
        monitor.status,
        failure is DeviceConnectionException
            ? DeviceStatus.unavailable
            : DeviceStatus.invalid,
      );
      expect(monitor.snapshot, isNull);
      expect(monitor.error, isNotNull);
      final reads = client.reads;
      await tester.pump(const Duration(seconds: 3));
      expect(client.reads, reads);
      fail = false;
      await monitor.connect(endpoint);
      expect(monitor.status, DeviceStatus.live);
      expect(monitor.error, isNull);
      monitor.dispose();
    }
  });

  testWidgets('停止与销毁后忽略迟到的错误和响应', (tester) async {
    final pending = Completer<DeviceSnapshot>();
    final client = TestDeviceClient((_) => pending.future);
    final monitor = DeviceMonitor(createClient: () => client);
    final read = monitor.connect(endpoint);
    monitor.dispose();
    pending.completeError(const DeviceConnectionException('cancelled'));
    await read;
    expect(client.closed, isTrue);
    expect(monitor.snapshot, isNull);
  });
}
