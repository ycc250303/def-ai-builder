import 'dart:async';

import 'package:flutter/foundation.dart';

import 'device_client.dart';

enum DeviceStatus { idle, connecting, live, stale, unavailable, invalid }

class DeviceMonitor extends ChangeNotifier {
  DeviceMonitor({
    DeviceClient Function()? createClient,
    DateTime Function()? now,
    this.interval = const Duration(seconds: 1),
    this.staleAfter = const Duration(seconds: 5),
  }) : _createClient = createClient ?? HttpDeviceClient.new,
       _now = now ?? DateTime.now;

  final DeviceClient Function() _createClient;
  final DateTime Function() _now;
  final Duration interval, staleAfter;
  DeviceStatus status = DeviceStatus.idle;
  DeviceSnapshot? snapshot;
  DateTime? receivedAt;
  String? error;
  DeviceClient? _client;
  Timer? _timer;
  int _session = 0;

  Future<void> connect(Uri endpoint) {
    stop(notify: false);
    snapshot = null;
    receivedAt = null;
    error = null;
    status = DeviceStatus.connecting;
    final client = _client = _createClient();
    final session = _session;
    notifyListeners();
    return _read(client, endpoint, session);
  }

  Future<void> _read(DeviceClient client, Uri endpoint, int session) async {
    try {
      final next = await client.read(endpoint);
      if (session != _session) return;
      final now = _now();
      // 协议没有启动编号，序号变化表示收到新采样；序号降低时重新计时。
      if (snapshot?.sequence != next.sequence ||
          snapshot?.source != next.source) {
        receivedAt = now;
      }
      snapshot = next;
      status = now.difference(receivedAt!) >= staleAfter
          ? DeviceStatus.stale
          : DeviceStatus.live;
      notifyListeners();
      if (session != _session) return;
      _timer = Timer(
        interval,
        () => unawaited(_read(client, endpoint, session)),
      );
    } on DeviceConnectionException catch (failure) {
      if (session != _session) return;
      _fail(DeviceStatus.unavailable, failure.message);
    } on DeviceProtocolException catch (failure) {
      if (session != _session) return;
      _fail(DeviceStatus.invalid, failure.message);
    }
  }

  void _fail(DeviceStatus next, String message) {
    _client?.close();
    _client = null;
    snapshot = null;
    receivedAt = null;
    error = message;
    status = next;
    notifyListeners();
  }

  void stop({bool notify = true}) {
    ++_session;
    _timer?.cancel();
    _timer = null;
    _client?.close();
    _client = null;
    snapshot = null;
    receivedAt = null;
    error = null;
    status = DeviceStatus.idle;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    stop(notify: false);
    super.dispose();
  }
}
