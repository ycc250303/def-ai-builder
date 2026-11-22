import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plant/data/app_store.dart';
import 'package:plant/main.dart';
import 'package:plant/ui/garden_scene.dart';
import 'package:plant/ui/home_page.dart';
import 'package:plant/ui/mine_pages.dart';
import 'package:plant/ui/social_pages.dart';

import 'test_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await SceneLayout.shared);

  test('首次启动只创建默认资料，重新加载保持空白账号', () async {
    final storage = MemoryStorage();
    final store = await AppStore.load(storage);
    expect(store.data.gardens, isEmpty);
    expect(store.data.selectedId, isNull);
    expect(store.data.nickname, '小叶同学');
    expect(store.data.bio, isEmpty);
    expect(store.data.following, isEmpty);
    expect(store.data.followers, isEmpty);
    expect(store.data.notices, isEmpty);
    expect(store.data.requests, isEmpty);
    expect(store.data.posts.where((p) => p.userId == 'me'), isEmpty);
    await store.advance(DateTime.now().add(const Duration(days: 2)));
    final restored = await AppStore.load(storage);
    expect(restored.data.gardens, isEmpty);
    expect(jsonDecode(storage.value!)['version'], 3);
  });

  test('用户绑定植物创建初始宠物且没有预置设备、环境历史与行动', () async {
    final store = await AppStore.load(MemoryStorage());
    await store.addPlant('阳台绿萝', '布布');
    final g = store.data.selected;
    expect(store.data.gardens, hasLength(1));
    expect(g.pet.name, '布布');
    expect(g.pet.level, 1);
    expect(g.pet.xp, 0);
    expect(g.pet.history.single.formId, 'eggie');
    expect(g.deviceId, isNull);
    expect(g.readings, isEmpty);
    expect(g.action, isNull);
    expect(g.items, isEmpty);
    expect(g.explorationCount, 0);
    expect(g.events.single.title, '初次见面');
  });

  testWidgets('空白账号可以浏览导航、绑定第一株植物并在重新加载后恢复', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final storage = MemoryStorage();
    var store = await AppStore.load(storage);
    await store.language('zh');
    Future<void> step() async {
      await t.pump();
      await t.pump(const Duration(milliseconds: 700));
    }

    await t.pumpWidget(PlantMateApp(store: store, runClock: false));
    await step();
    expect(find.byType(GardenScene), findsNothing);
    expect(find.byType(StatsGrid), findsNothing);
    expect(find.text('绑定一株植物，开始新的故事'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nav-2')));
    await step();
    expect(find.text('小叶同学'), findsOneWidget);
    expect(find.text('窗边绿萝'), findsNothing);
    expect(find.text('团子'), findsNothing);
    await t.tap(find.widgetWithText(FilledButton, '绑定植物'));
    await step();
    await t.enterText(find.byType(TextFormField).at(0), '阳台绿萝');
    await t.enterText(find.byType(TextFormField).at(1), '布布');
    await t.ensureVisible(find.widgetWithText(FilledButton, '绑定植物'));
    await t.tap(find.widgetWithText(FilledButton, '绑定植物'));
    await step();
    await t.tap(find.byKey(const ValueKey('nav-0')));
    await step();
    expect(find.text('布布'), findsOneWidget);
    final id = store.data.selectedId;
    final nav = Navigator.of(t.element(find.byType(HomePage)));
    nav.push(MaterialPageRoute<void>(builder: (_) => MonitorPage(id: id!)));
    await step();
    expect(find.text('暂无记录'), findsWidgets);
    expect(t.takeException(), isNull);
    nav.pop();
    await step();
    await store.archivePlant(id!);
    await step();
    expect(find.byType(GardenScene), findsNothing);
    expect(find.byType(StatsGrid), findsNothing);
    await t.tap(find.widgetWithText(OutlinedButton, '我的植物'));
    await step();
    await t.tap(find.widgetWithText(TextButton, '重新绑定'));
    await step();
    expect(store.data.selectedId, id);
    nav.pop();
    await step();
    await t.pumpWidget(const SizedBox());
    store = await AppStore.load(storage);
    await t.pumpWidget(PlantMateApp(store: store, runClock: false));
    await step();
    expect(find.text('布布'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('空白账号发布入口展示绑定提示', (t) async {
    final store = await AppStore.load(MemoryStorage());
    await store.language('zh');
    await t.pumpWidget(PlantMateApp(store: store, runClock: false));
    await t.pump();
    Navigator.of(t.element(find.byType(HomePage)))
        .push(MaterialPageRoute<void>(builder: (_) => const PublishPage()));
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    expect(find.byType(AddPlantPage), findsNothing);
    expect(find.text('绑定一株植物，开始新的故事'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
