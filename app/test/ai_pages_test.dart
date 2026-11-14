import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hello_flutter/ai/ai_api.dart';
import 'package:hello_flutter/ai/ai_pages.dart';
import 'package:hello_flutter/auth/home_page.dart';
import 'package:hello_flutter/plants/plant_detail_page.dart';
import 'package:hello_flutter/plants/plant_api.dart';

import 'support/fake_plant_api.dart';

void main() {
  testWidgets('会话列表可以创建、打开、恢复历史并确认删除', (tester) async {
    final api = FakeAiApi();
    await tester.pumpWidget(
      MaterialApp(home: AiConversationsPage(api: api, plantId: 42)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('还没有会话'), findsOneWidget);
    await tester.tap(find.byKey(const Key('new-conversation')));
    await tester.pumpAndSettle();
    expect(api.createdPlant, 42);
    expect(find.byKey(const Key('ai-question')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('conversation-c1')));
    await tester.pumpAndSettle();
    expect(api.loads, greaterThan(1));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除会话'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(api.items, hasLength(1));
    await tester.tap(find.byTooltip('删除会话'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-conversation')));
    await tester.pumpAndSettle();
    expect(api.items, isEmpty);
  });

  testWidgets('手机页面逐步显示文本，完成后从数据库读取一致的历史', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakeAiApi();
    await showChat(tester, api);
    await tester.tap(find.byKey(const Key('send-ai-question')));
    await tester.pump();
    expect(find.text('请填写 1 到 4000 字的问题'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('ai-question')), '今天需要浇水吗？');
    await tester.tap(find.byKey(const Key('send-ai-question')));
    await tester.pump();
    api.events!.add(const AiEvent('accepted', {'turnId': 't1'}));
    api.events!.add(const AiEvent('delta', {'text': '检查土壤'}));
    await tester.pump();
    expect(find.text('检查土壤'), findsOneWidget);
    expect(find.byKey(const Key('cancel-ai-reply')), findsOneWidget);
    api.finish();
    await tester.pumpAndSettle();
    expect(find.text('检查土壤干湿。'), findsOneWidget);
    expect(api.history.last.status, 'COMPLETED');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('ai-question')))
          .controller!
          .text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('停止生成保存取消状态，页面允许再次提问', (tester) async {
    final api = FakeAiApi();
    await showChat(tester, api);
    await tester.enterText(find.byKey(const Key('ai-question')), '你好');
    await tester.tap(find.byKey(const Key('send-ai-question')));
    await tester.pump();
    api.events!.add(const AiEvent('accepted', {'turnId': 't1'}));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cancel-ai-reply')));
    await tester.pumpAndSettle();
    expect(api.cancelled, isTrue);
    expect(find.text('已取消'), findsOneWidget);
    expect(find.byKey(const Key('send-ai-question')), findsOneWidget);
  });

  testWidgets('请求失败保留输入和去重编号，重试可读取已有结果', (tester) async {
    final api = FakeAiApi()..fail = true;
    await showChat(tester, api);
    await tester.enterText(find.byKey(const Key('ai-question')), '你好');
    await tester.tap(find.byKey(const Key('send-ai-question')));
    await tester.pumpAndSettle();
    expect(find.text('网络暂时不可用'), findsOneWidget);
    final request = api.requestIds.single;
    api.fail = false;
    await tester.tap(find.byKey(const Key('send-ai-question')));
    await tester.pump();
    expect(api.requestIds.last, request);
    api.finish();
    await tester.pumpAndSettle();
    expect(find.text('检查土壤干湿。'), findsOneWidget);
  });

  testWidgets('重新打开会话可显示保存的失败回复和历史', (tester) async {
    final api = FakeAiApi()
      ..history = [
        message('USER', '昨天叶子发黄', 'FAILED'),
        message('ASSISTANT', '部分建议', 'FAILED'),
      ];
    await showChat(tester, api);
    expect(find.text('昨天叶子发黄'), findsOneWidget);
    expect(find.text('部分建议'), findsOneWidget);
    expect(find.text('生成失败'), findsOneWidget);
  });

  testWidgets('植物列表和植物主页均提供助手入口', (tester) async {
    final api = FakeAiApi();
    final plants = FakePlantApi();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          username: 'alice',
          onLogout: () async {},
          plantApi: plants,
          aiApi: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-ai-assistant')));
    await tester.pumpAndSettle();
    expect(find.byType(AiConversationsPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    final plant = await plants.create(const PlantInput(species: '绿萝'));
    await tester.pumpWidget(
      MaterialApp(
        home: PlantDetailPage(id: plant.id, api: plants, aiApi: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ask-plant-assistant')));
    await tester.tap(find.byKey(const Key('ask-plant-assistant')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AiConversationsPage>(find.byType(AiConversationsPage))
          .plantId,
      plant.id,
    );
  });
}

Future<void> showChat(WidgetTester tester, FakeAiApi api) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AiChatPage(
        api: api,
        conversation: const AiConversation(id: 'c1', title: '养护问答'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

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
  bool cancelled = false;
  bool fail = false;
  @override
  Future<List<AiConversation>> list({int offset = 0}) async =>
      items.skip(offset).toList();
  @override
  Future<AiConversation> create({int? plantId}) async {
    createdPlant = plantId;
    final item = AiConversation(id: 'c1', title: '养护问答', plantId: plantId);
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
