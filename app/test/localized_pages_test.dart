import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant/data/app_store.dart';
import 'package:plant/data/models.dart';
import 'package:plant/main.dart';
import 'package:plant/ui/garden_scene.dart';
import 'package:plant/ui/home_page.dart';
import 'package:plant/ui/mine_pages.dart';
import 'package:plant/ui/social_pages.dart';

import 'test_storage.dart';

Future<void> step(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 450));
}

Future<AppStore> render(
  WidgetTester t,
  String locale, {
  Size size = const Size(390, 844),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final store = await AppStore.load(MemoryStorage());
  await store.language(locale);
  await t.pumpWidget(PlantMateApp(store: store, runClock: false));
  await step(t);
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await SceneLayout.shared;
  });
  testWidgets('英文小屏幕导航与所有详情页面没有溢出', (t) async {
    final store = await render(t, 'en', size: const Size(320, 568));
    expect(find.text('Garden'), findsOneWidget);
    expect(t.takeException(), isNull);
    for (final i in [1, 2, 0]) {
      await t.tap(find.byKey(ValueKey('nav-$i')));
      await step(t);
      expect(t.takeException(), isNull);
    }
    final context = t.element(find.byType(HomePage));
    final nav = Navigator.of(context);
    await store.setVisitMode('g1', VisitMode.request);
    await store.simulateIncomingRequest('g1');
    for (final page in <Widget>[
      const PlantsPage(),
      const PetPage(id: 'g1'),
      const EvolutionPage(id: 'g2'),
      const DiaryPage(id: 'g1'),
      const MonitorPage(id: 'g1'),
      const DevicesPage(),
      const PrivacyPage(),
      const SettingsPage(),
      const EditProfilePage(),
      const AddPlantPage(),
      const PublishPage(),
      const NotificationsPage(),
      const SearchPage(),
      const GardenEditorPage(id: 'g1'),
      const ProfilePage(id: 'me'),
      const GardenVisitPage(ownerId: 'moon_leaf', gardenId: 'moon_leaf-garden'),
    ]) {
      nav.push(MaterialPageRoute<void>(builder: (_) => page));
      await step(t);
      expect(t.takeException(), isNull, reason: '${page.runtimeType}');
      nav.pop();
      await step(t);
    }
  });
  testWidgets('设置中切换语言即时更新当前页面并保存', (t) async {
    final store = await render(t, 'zh');
    final nav = Navigator.of(t.element(find.byType(HomePage)));
    nav.push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
    await step(t);
    expect(find.text('语言'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('language-en')));
    await step(t);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(store.data.language, 'en');
    final restored = await AppStore.load(store.storage);
    expect(restored.data.language, 'en');
    expect(t.takeException(), isNull);
  });
  testWidgets('参观申请与通知页模拟审批后可以进入花园', (t) async {
    final store = await render(t, 'zh');
    final nav = Navigator.of(t.element(find.byType(HomePage)));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const GardenVisitPage(
          ownerId: 'moss_post',
          gardenId: 'moss_post-garden',
        ),
      ),
    );
    await step(t);
    await t.tap(find.widgetWithText(FilledButton, '申请参观'));
    await step(t);
    expect(find.text('等待批准'), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, '通知'));
    await step(t);
    await t.tap(find.widgetWithText(FilledButton, '模拟主人批准'));
    await step(t);
    expect(store.data.requests.single.status, RequestStatus.approved);
    await t.tap(find.widgetWithText(TextButton, '参观花园'));
    await step(t);
    expect(find.textContaining('参观模式'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('场景编辑支持拖动收起并保存布局', (t) async {
    final store = await render(t, 'zh');
    final nav = Navigator.of(t.element(find.byType(HomePage)));
    nav.push(
      MaterialPageRoute<void>(builder: (_) => const GardenEditorPage(id: 'g1')),
    );
    await step(t);
    final editorScene = find.descendant(
      of: find.byType(GardenEditorPage),
      matching: find.byType(InteractiveViewer),
    );
    await t.tap(find.byKey(const ValueKey('browse-map')));
    await step(t);
    final viewer = t.widget<InteractiveViewer>(editorScene);
    expect(viewer.panEnabled, isTrue);
    expect(viewer.scaleEnabled, isTrue);
    final before = viewer.transformationController!.value.clone();
    await t.drag(editorScene, const Offset(0, 100));
    await step(t);
    expect(viewer.transformationController!.value, isNot(before));
    expect(store.garden('g1').items, isEmpty);
    await t.drag(editorScene, const Offset(0, -100));
    await step(t);
    await t.tap(find.byKey(const ValueKey('adjust-decorations')));
    await step(t);
    expect(t.widget<InteractiveViewer>(editorScene).panEnabled, isFalse);
    final item = find.byKey(const ValueKey('scene-item-ufo_right')).last;
    expect(item, findsOneWidget);
    await t.drag(item, const Offset(-35, -20));
    await step(t);
    await t.tap(item);
    await step(t);
    await t.tap(find.text('收起'));
    await step(t);
    await t.tap(find.widgetWithText(TextButton, '保存布置'));
    await step(t);
    final saved = store
        .garden('g1')
        .items
        .singleWhere((i) => i.id == 'ufo_right');
    expect(saved.visible, isFalse);
    expect(saved.x, lessThan(453));
    expect(t.takeException(), isNull);
  });
  testWidgets('纯文字动态从页面发布，无需标题和图片', (t) async {
    final store = await render(t, 'zh');
    final nav = Navigator.of(t.element(find.byType(HomePage)));
    nav.push(MaterialPageRoute<void>(builder: (_) => const PublishPage()));
    await step(t);
    await t.tap(find.byType(SwitchListTile));
    await step(t);
    await t.enterText(find.byType(TextFormField).last, '只分享一句话');
    await t.ensureVisible(find.widgetWithText(FilledButton, '发布动态'));
    await t.tap(find.widgetWithText(FilledButton, '发布动态'));
    await step(t);
    expect(store.data.posts.first.body, '只分享一句话');
    expect(store.data.posts.first.title, isEmpty);
    expect(store.data.posts.first.snapshot, isNull);
    expect(t.takeException(), isNull);
  });
}
