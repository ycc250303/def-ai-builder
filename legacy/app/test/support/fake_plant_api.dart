import 'package:hello_flutter/plants/plant_api.dart';

/// 页面交互测试使用的植物接口，记录输入并模拟后端默认值。
class FakePlantApi implements PlantApi {
  final plants = <int, PlantProfile>{};
  int _nextId = 1;
  PlantInput? lastInput;
  String? failure;
  var reads = 0;

  void _check() {
    if (failure != null) throw PlantException(failure!);
  }

  @override
  Future<List<PlantProfile>> list() async {
    _check();
    return plants.values.toList().reversed.toList();
  }

  @override
  Future<PlantProfile> get(int id) async {
    _check();
    reads++;
    return plants[id]!;
  }

  PlantProfile _save(int id, PlantInput input) {
    lastInput = input;
    final plant = PlantProfile(
      id: id,
      species: input.species,
      nickname: input.nickname ?? input.species,
      careStartDate: input.careStartDate ?? '2026-11-14',
      plantingDate: input.plantingDate,
      growingLocation: input.growingLocation,
      cultivationMethod: input.cultivationMethod,
      description: input.description,
    );
    plants[id] = plant;
    return plant;
  }

  @override
  Future<PlantProfile> create(PlantInput input) async {
    _check();
    return _save(_nextId++, input);
  }

  @override
  Future<PlantProfile> update(int id, PlantInput input) async {
    _check();
    return _save(id, input);
  }

  @override
  Future<void> delete(int id) async {
    _check();
    plants.remove(id);
  }
}
