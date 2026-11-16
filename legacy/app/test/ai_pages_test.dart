import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hello_flutter/ai/ai_api.dart';
import 'package:hello_flutter/ai/ai_pages.dart';
import 'package:hello_flutter/auth/home_page.dart';
import 'package:hello_flutter/plants/plant_api.dart';

import 'support/fake_plant_api.dart';
import 'support/fake_ai_api.dart';

void main() {
  testWidgets('手机键盘打开时植物选框仍可选择', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final plants = FakePlantApi();
    final plant = await plants.create(const PlantInput(species: '绿萝'));
    final api = FakeAiApi()..plants.addAll(plants.plants);
    await showChat(tester, api, plants: plants);
    await tester.enterText(find.byKey(const Key('ai-question')), '它需要浇水吗？');
    await tester.tap(find.byKey(const Key('select-ai-plant')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(Key('ai-plant-${plant.id}')));
    await tester.pumpAndSettle();
    expect(find.text('当前植物：绿萝'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('植物按钮位于输入框左侧，选择可以持续保留、更换和清除', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final plants = FakePlantApi();
    final first = await plants.create(
      const PlantInput(species: '绿萝', nickname: '窗边绿萝'),
    );
    final second = await plants.create(
      const PlantInput(species: '吊兰', nickname: '阳台吊兰'),
    );
    final api = FakeAiApi()..plants.addAll(plants.plants);
    await showChat(tester, api, plants: plants);
    expect(find.text('通用问答'), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const Key('select-ai-plant'))).dx,
      lessThan(tester.getTopLeft(find.byKey(const Key('ai-question'))).dx),
    );
    await tester.enterText(find.byKey(const Key('ai-question')), '它需要浇水吗？');
    await tester.tap(find.byKey(const Key('select-ai-plant')));
    await tester.pumpAndSettle();
    expect(find.text('窗边绿萝'), findsOneWidget);
    expect(find.text('绿萝'), findsOneWidget);
    await tester.tap(find.byKey(Key('ai-plant-${first.id}')));
    await tester.pumpAndSettle();
    expect(find.text('当前植物：窗边绿萝'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('ai-question')))
          .controller!
          .text,
      '它需要浇水吗？',
    );
    await tester.tap(find.byKey(const Key('send-ai-question')));
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('select-ai-plant')))
          .onPressed,
      isNull,
    );
    api.finish();
    await tester.pumpAndSettle();
    expect(find.text('当前植物：窗边绿萝'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await showChat(tester, api, plants: plants);
    expect(find.text('当前植物：窗边绿萝'), findsOneWidget);
    await tester.tap(find.byKey(const Key('select-ai-plant')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ListTile>(find.byKey(Key('ai-plant-${first.id}'))).selected,
      isTrue,
    );
    await tester.tap(find.byKey(Key('ai-plant-${second.id}')));
    await tester.pumpAndSettle();
    expect(find.text('当前植物：阳台吊兰'), findsOneWidget);
    expect(find.text('检查土壤干湿。'), findsOneWidget);
    await tester.tap(find.byKey(const Key('select-ai-plant')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-plant-general')));
    await tester.pumpAndSettle();
    expect(find.text('通用问答'), findsOneWidget);
    expect(api.selectedPlants, [first.id, second.id, null]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('选框读取最新列表，加载失败可以重试，保存失败保留原选择', (tester) async {
    final plants = FakePlantApi()..failure = '植物列表暂时不可用';
    final api = FakeAiApi();
    await showChat(tester, api, plants: plants);
    await tester.tap(find.byKey(const Key('select-ai-plant')));
    await tester.pumpAndSettle();
    expect(find.text('植物列表暂时不可用'), findsOneWidget);
    plants.failure = null;
    final plant = await plants.create(const PlantInput(species: '玉树'));
    api.plants.addAll(plants.plants);
    await tester.tap(find.text('重新加载植物'));
    await tester.pumpAndSettle();
    expect(find.text('玉树'), findsNWidgets(2));
    api.selectionFailure = '会话正在生成回复';
    await tester.tap(find.byKey(Key('ai-plant-${plant.id}')));
    await tester.pumpAndSettle();
    expect(find.text('会话正在生成回复'), findsOneWidget);
    expect(find.text('通用问答'), findsOneWidget);
    expect(api.selectedPlants, isEmpty);
    api.selectionFailure = null;
    await plants.delete(plant.id);
    await tester.tap(find.byKey(const Key('select-ai-plant')));
    await tester.pumpAndSettle();
    expect(find.text('还没有植物，请先在植物页面创建档案'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(api.selectedPlants, isEmpty);
  });

  testWidgets('已删除的指定植物可以清除，切换后相同问题使用新的去重编号', (tester) async {
    final plants = FakePlantApi();
    final plant = await plants.create(const PlantInput(species: '芦荟'));
    final api = FakeAiApi()
      ..plants.addAll(plants.plants)
      ..items.add(
        const AiConversation(id: 'c1', title: '养护问答', scope: 'PLANT'),
      );
    await showChat(tester, api, plants: plants);
    expect(find.text('指定植物已删除，请重新选择'), findsOneWidget);
    await tester.tap(find.byKey(const Key('select-ai-plant')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-plant-general')));
    await tester.pumpAndSettle();
    expect(find.text('通用问答'), findsOneWidget);
    expect(api.selectedPlants, [null]);
    api.fail = true;
    await tester.enterText(find.byKey(const Key('ai-question')), '它的情况如何？');
    await tester.tap(find.byKey(const Key('send-ai-question')));
    await tester.pumpAndSettle();
    final oldRequest = api.requestIds.single;
    await tester.tap(find.byKey(const Key('select-ai-plant')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('ai-plant-${plant.id}')));
    await tester.pumpAndSettle();
    api.fail = false;
    await tester.tap(find.byKey(const Key('send-ai-question')));
    await tester.pump();
    expect(api.requestIds.last, isNot(oldRequest));
    api.finish();
    await tester.pumpAndSettle();
  });

  testWidgets('会话列表可以创建、打开、恢复历史并确认删除', (tester) async {
    final api = FakeAiApi();
    await tester.pumpWidget(
      MaterialApp(
        home: AiConversationsPage(
          api: api,
          plantApi: FakePlantApi(),
          plantId: 42,
        ),
      ),
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

  testWidgets('底部导航按植物、对话、用户排列并保留栏目状态', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakeAiApi();
    final plants = FakePlantApi();
    await plants.create(const PlantInput(species: '绿萝'));
    var loggedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          username: 'alice',
          onLogout: () async {
            loggedOut = true;
          },
          plantApi: plants,
          aiApi: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final destinations = navigation.destinations.cast<NavigationDestination>();
    expect(destinations.map((item) => item.label), ['植物', '对话', '用户']);
    expect(destinations.every((item) => item.icon is Icon), isTrue);
    expect(navigation.selectedIndex, 0);
    expect(find.byKey(const Key('plant-1')), findsOneWidget);
    expect(find.byKey(const Key('current-user')), findsNothing);
    expect(api.lists, 0);
    expect(find.byKey(const Key('open-ai-assistant')), findsNothing);
    await tester.tap(find.byKey(const Key('plant-1')));
    await tester.pumpAndSettle();
    expect(find.text('品种：绿萝'), findsOneWidget);
    expect(find.byKey(const Key('ask-plant-assistant')), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-conversations')));
    await tester.pumpAndSettle();
    expect(find.byType(AiConversationsPage), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byKey(const Key('add-plant')), findsNothing);
    expect(api.lists, 1);
    await tester.tap(find.byKey(const Key('new-conversation')));
    await tester.pumpAndSettle();
    expect(api.createdPlant, isNull);
    expect(find.byKey(const Key('ai-question')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('conversation-c1')), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    final loaded = api.lists;

    await tester.tap(find.byKey(const Key('nav-user')));
    await tester.pumpAndSettle();
    expect(find.text('alice'), findsOneWidget);
    expect(find.byKey(const Key('logout')), findsOneWidget);
    expect(find.byKey(const Key('refresh-plants')), findsNothing);
    await tester.tap(find.byKey(const Key('nav-conversations')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('conversation-c1')), findsOneWidget);
    expect(api.lists, loaded);
    await tester.tap(find.byKey(const Key('nav-plants')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plant-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-user')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    expect(loggedOut, isTrue);
    expect(tester.takeException(), isNull);
  });
}

Future<void> showChat(
  WidgetTester tester,
  FakeAiApi api, {
  FakePlantApi? plants,
}) async {
  if (api.items.isEmpty) {
    api.items.add(const AiConversation(id: 'c1', title: '养护问答'));
  }
  await tester.pumpWidget(
    MaterialApp(
      home: AiChatPage(
        api: api,
        plantApi: plants ?? FakePlantApi(),
        conversation: const AiConversation(id: 'c1', title: '养护问答'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
