import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant/data/app_store.dart';
import 'package:plant/main.dart';
import 'package:plant/ui/home_page.dart';
import 'package:plant/ui/garden_scene.dart';
import 'package:plant/ui/common.dart';
import 'package:plant/ui/mine_pages.dart';
import 'package:plant/ui/social_pages.dart';

import 'test_storage.dart';

Future<void> render(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  AppStore? store,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  store ??= await seededStore(MemoryStorage());
  await store.language('zh');
  await tester.pumpWidget(PlantMateApp(store: store, runClock: false));
  await tester.pump();
}

Future<void> step(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await SceneLayout.shared;
  });
  testWidgets('成长进度条使用信息区域的完整宽度', (tester) async {
    await render(tester);
    expect(
      tester.getSize(find.byType(PixelProgress).last).width,
      closeTo(390 - 40, .1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('养育首页、全屏花园与底部导航正常切换', (tester) async {
    await render(tester);
    expect(find.text('团子'), findsOneWidget);
    expect(find.byType(StatsGrid), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-garden')));
    await step(tester);
    expect(find.byTooltip('返回养育首页'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await step(tester);
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('关注'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await step(tester);
    expect(find.text('小叶同学'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('切换植物更新对应宠物，重建后保留选择', (tester) async {
    final storage = MemoryStorage(), store = await seededStore(storage);
    await render(tester, store: store);
    await tester.tap(find.byKey(const ValueKey('plant-selector')));
    await step(tester);
    await tester.tap(find.text('书桌绿萝'));
    await step(tester);
    expect(store.data.selectedId, 'g2');
    expect(find.text('啵啵'), findsOneWidget);
    final restored = await AppStore.load(storage);
    expect(restored.data.selectedId, 'g2');
    expect(tester.takeException(), isNull);
  });
  testWidgets('搜索昵称和用户编号，私密花园显示提示', (tester) async {
    await render(tester);
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await step(tester);
    await tester.tap(find.byKey(const ValueKey('search-users')));
    await step(tester);
    await tester.enterText(find.byType(TextField), 'moon_leaf');
    await step(tester);
    expect(find.text('月亮种植员'), findsWidgets);
    expect(find.text('小绿的日常'), findsNothing);
    await tester.tap(find.text('参观花园'));
    await step(tester);
    expect(find.text('这座花园暂不允许你参观'), findsOneWidget);
    expect(find.byType(GardenVisitPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('发布校验必填项并把动态保存到模拟社区', (tester) async {
    final store = await seededStore(MemoryStorage());
    await render(tester, store: store);
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await step(tester);
    await tester.tap(find.byTooltip('发布动态'));
    await step(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, '发布动态'));
    await step(tester);
    await tester.tap(find.widgetWithText(FilledButton, '发布动态'));
    await step(tester);
    expect(find.text('请填写内容'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '我的新花园');
    await tester.enterText(fields.at(1), '今天也在慢慢长大');
    await tester.ensureVisible(find.widgetWithText(FilledButton, '发布动态'));
    await step(tester);
    await tester.tap(find.widgetWithText(FilledButton, '发布动态'));
    await step(tester);
    expect(store.data.posts.first.title, '我的新花园');
    expect(store.garden('g1').open, isFalse);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(768, 1024),
  ]) {
    testWidgets('不同屏幕尺寸下养育、社交与个人中心没有布局溢出 $size', (tester) async {
      await render(tester, size: size);
      expect(tester.takeException(), isNull);
      for (final i in [1, 2, 0]) {
        await tester.tap(find.byKey(ValueKey('nav-$i')));
        await step(tester);
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets('个人中心各详情页面可以打开且没有布局异常', (tester) async {
    await render(tester, size: const Size(390, 844));
    final context = tester.element(find.byType(HomePage));
    final nav = Navigator.of(context);
    for (final page in <Widget>[
      const PlantsPage(),
      const MonitorPage(id: 'g1'),
      const PetPage(id: 'g1'),
      const EvolutionPage(id: 'g1'),
      const DiaryPage(id: 'g1'),
      const DevicesPage(),
      const PrivacyPage(),
      const SettingsPage(),
      const EditProfilePage(),
      const AddPlantPage(),
    ]) {
      nav.push(MaterialPageRoute<void>(builder: (_) => page));
      await step(tester);
      expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
      nav.pop();
      await step(tester);
    }
  });
}
