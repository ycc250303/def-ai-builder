import 'dart:convert';

import 'legacy_data.dart';

import 'package:plant/data/app_store.dart';

class MemoryStorage implements LocalStorage {
  String? value;
  bool failWrites = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (failWrites) {
      throw StateError('保存失败');
    }
    this.value = value;
  }
}

Future<AppStore> seededStore(LocalStorage storage, {DateTime? now}) {
  final fixture = legacyData(now ?? DateTime.now());
  return storage
      .write(jsonEncode(fixture.toJson()))
      .then((_) => AppStore.load(storage, now: now));
}
