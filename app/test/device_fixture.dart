import 'dart:convert';

import 'package:plant/data/device_client.dart';

Map<String, dynamic> deviceData({
  String source = 'device',
  int sequence = 42,
}) => {
  'source': source,
  'sequence': sequence,
  'sensors': <String, dynamic>{
    'temperature_c': 24.6,
    'humidity_rh': 61.0,
    'light_lux': 480.0,
    'soil_level': 'high',
    'touch_mask': 5,
  },
  'command': <String, dynamic>{'id': 2, 'code': 'TOUCH_DETECTED'},
};

DeviceSnapshot deviceSnapshot({String source = 'device', int sequence = 42}) =>
    DeviceSnapshot.decode(
      jsonEncode(deviceData(source: source, sequence: sequence)),
    );

class TestDeviceClient implements DeviceClient {
  TestDeviceClient(this.onRead);
  final Future<DeviceSnapshot> Function(Uri) onRead;
  int reads = 0;
  bool closed = false;

  @override
  Future<DeviceSnapshot> read(Uri endpoint) {
    ++reads;
    return onRead(endpoint);
  }

  @override
  void close() => closed = true;
}
