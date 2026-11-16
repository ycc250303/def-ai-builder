import 'dart:async';

import 'package:hello_flutter/ai/ai_api.dart';
import 'package:hello_flutter/plants/plant_api.dart';

AiMessage message(String role, String content, String status) => AiMessage(
  id: role,
  turnId: 't1',
  sequence: 1,
  role: role,
  content: content,
  status: status,
);

class FakeAiApi implements AiApi {
  final items = <AiConversation>[];
  List<AiMessage> history = [];
  final requestIds = <String>[];
  StreamController<AiEvent>? events;
  int? createdPlant;
  int loads = 0;
  int lists = 0;
  bool cancelled = false;
  bool fail = false;
  String? selectionFailure;
  final selectedPlants = <int?>[];
  final plants = <int, PlantProfile>{};

  @override
  Future<AiConversation> get(String id) async =>
      items.singleWhere((item) => item.id == id);

  @override
  Future<AiConversation> selectPlant(String id, int? plantId) async {
    if (selectionFailure != null) throw AiException(selectionFailure!);
    selectedPlants.add(plantId);
    final previous = await get(id);
    final saved = AiConversation(
      id: id,
      title: previous.title,
      scope: plantId == null ? 'GENERAL' : 'PLANT',
      plantId: plantId,
      plantName: plantId == null ? null : plants[plantId]!.nickname,
    );
    items[items.indexOf(previous)] = saved;
    return saved;
  }

  @override
  Future<List<AiConversation>> list({int offset = 0}) async {
    lists++;
    return items.skip(offset).toList();
  }

  @override
  Future<AiConversation> create({int? plantId}) async {
    createdPlant = plantId;
    final item = AiConversation(
      id: 'c1',
      title: '养护问答',
      plantId: plantId,
      scope: plantId == null ? 'GENERAL' : 'PLANT',
      plantName: plantId == null ? null : '绿萝',
    );
    items.add(item);
    return item;
  }

  @override
  Future<List<AiMessage>> messages(String id, {int? before}) async {
    loads++;
    return List.of(history);
  }

  @override
  AiCall send(String id, String requestId, String content) {
    requestIds.add(requestId);
    if (fail) return AiCall(Stream.error(const AiException('网络暂时不可用')), () {});
    events = StreamController<AiEvent>();
    return AiCall(events!.stream, () {
      if (!events!.isClosed) unawaited(events!.close());
    });
  }

  void finish() {
    history = [
      message('USER', '你好', 'COMPLETED'),
      message('ASSISTANT', '检查土壤干湿。', 'COMPLETED'),
    ];
    events!.add(const AiEvent('done', {'content': '检查土壤干湿。'}));
    unawaited(events!.close());
  }

  @override
  Future<void> cancel(String id, String turnId) async {
    cancelled = true;
    history = [
      message('USER', '你好', 'CANCELLED'),
      message('ASSISTANT', '部分回复', 'CANCELLED'),
    ];
  }

  @override
  Future<void> delete(String id) async {
    items.removeWhere((item) => item.id == id);
  }
}
