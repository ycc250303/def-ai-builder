import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class DeviceConnectionException implements Exception {
  const DeviceConnectionException(this.message);
  final String message;
}

class DeviceProtocolException implements Exception {
  const DeviceProtocolException(this.message);
  final String message;
}

/// 硬件快照独立于游戏采样，不参与宠物属性与行为计算。
class DeviceSnapshot {
  const DeviceSnapshot({
    required this.source,
    required this.sequence,
    required this.temperature,
    required this.humidity,
    required this.light,
    required this.soilLevel,
    required this.touchMask,
    required this.commandId,
    required this.commandCode,
  });

  final String source;
  final int sequence;
  final double? temperature, humidity, light;
  final String? soilLevel;
  final int? touchMask, commandId;
  final String? commandCode;

  factory DeviceSnapshot.decode(String body) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const DeviceProtocolException('Invalid JSON');
    }
    final root = _object(decoded, 'state');
    final source = root['source'];
    if (source != 'device' && source != 'simulation') {
      throw const DeviceProtocolException('Invalid source');
    }
    final sensors = _object(root['sensors'], 'sensors');
    double? reading(String key, {double? minimum, double? maximum}) {
      if (!sensors.containsKey(key)) {
        throw DeviceProtocolException('Missing sensors.$key');
      }
      final value = sensors[key];
      if (value == null) return null;
      if (value is! num ||
          !value.isFinite ||
          (minimum != null && value < minimum) ||
          (maximum != null && value > maximum)) {
        throw DeviceProtocolException('Invalid sensors.$key');
      }
      return value.toDouble();
    }

    final soil = sensors['soil_level'];
    if (!sensors.containsKey('soil_level') ||
        (soil != null && soil != 'high' && soil != 'low')) {
      throw const DeviceProtocolException('Invalid sensors.soil_level');
    }
    if (!sensors.containsKey('touch_mask')) {
      throw const DeviceProtocolException('Missing sensors.touch_mask');
    }
    final touch = sensors['touch_mask'];
    if (touch != null) _integer(touch, 'sensors.touch_mask', maximum: 4095);
    if (!root.containsKey('command')) {
      throw const DeviceProtocolException('Missing command');
    }
    final command = root['command'] == null
        ? null
        : _object(root['command'], 'command');
    final code = command?['code'];
    if (command != null &&
        (code is! String || !RegExp(r'^[A-Z0-9_]{1,47}$').hasMatch(code))) {
      throw const DeviceProtocolException('Invalid command.code');
    }
    return DeviceSnapshot(
      source: source as String,
      sequence: _integer(root['sequence'], 'sequence'),
      temperature: reading('temperature_c', minimum: -40, maximum: 125),
      humidity: reading('humidity_rh', minimum: 0, maximum: 100),
      light: reading('light_lux', minimum: 0),
      soilLevel: soil as String?,
      touchMask: touch as int?,
      commandId: command == null ? null : _integer(command['id'], 'command.id'),
      commandCode: code as String?,
    );
  }

  static Map<String, dynamic> _object(Object? value, String field) {
    if (value is! Map<String, dynamic>) {
      throw DeviceProtocolException('Invalid $field');
    }
    return value;
  }

  static int _integer(Object? value, String field, {int maximum = 0xffffffff}) {
    if (value is! int || value < 0 || value > maximum) {
      throw DeviceProtocolException('Invalid $field');
    }
    return value;
  }
}

abstract interface class DeviceClient {
  Future<DeviceSnapshot> read(Uri endpoint);
  void close();
}

class HttpDeviceClient implements DeviceClient {
  HttpDeviceClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 3),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;
  final Set<Completer<void>> _requests = {};

  /// 只接受明确的局域网 IPv4 地址，兼容设备热点与电脑模拟服务。
  static Uri endpoint(String address) {
    final uri = Uri.tryParse(address.trim());
    if (uri == null ||
        uri.scheme != 'http' ||
        uri.userInfo.isNotEmpty ||
        uri.port < 1 ||
        uri.port > 65535 ||
        uri.hasQuery ||
        uri.hasFragment ||
        !['', '/', '/api/state'].contains(uri.path)) {
      throw const FormatException('Invalid device address');
    }
    final parts = uri.host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 ||
        parts.any((p) => p == null || p < 0 || p > 255) ||
        parts.join('.') != uri.host ||
        !(parts[0] == 10 ||
            parts[0] == 127 ||
            (parts[0] == 192 && parts[1] == 168) ||
            (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31))) {
      throw const FormatException('Expected a local IPv4 address');
    }
    return uri.replace(path: '/api/state');
  }

  @override
  Future<DeviceSnapshot> read(Uri endpoint) async {
    endpoint = HttpDeviceClient.endpoint(endpoint.toString());
    final abort = Completer<void>();
    _requests.add(abort);
    final request = http.AbortableRequest(
      'GET',
      endpoint,
      abortTrigger: abort.future,
    )..followRedirects = false;
    request.headers['Accept'] = 'application/json';
    try {
      return await (() async {
        final response = await _client.send(request);
        if (response.statusCode != 200) {
          throw DeviceConnectionException('HTTP ${response.statusCode}');
        }
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 16384) {
            throw const DeviceProtocolException('Response exceeds 16 KiB');
          }
          bytes.addAll(chunk);
        }
        String body;
        try {
          body = utf8.decode(bytes);
        } on FormatException {
          throw const DeviceProtocolException('Invalid UTF-8');
        }
        return DeviceSnapshot.decode(body);
      })().timeout(timeout);
    } on TimeoutException {
      throw const DeviceConnectionException('Request timed out');
    } on http.ClientException catch (error) {
      throw DeviceConnectionException(error.message);
    } finally {
      if (!abort.isCompleted) abort.complete();
      _requests.remove(abort);
    }
  }

  @override
  void close() {
    for (final abort in _requests) {
      if (!abort.isCompleted) abort.complete();
    }
    _client.close();
  }
}
