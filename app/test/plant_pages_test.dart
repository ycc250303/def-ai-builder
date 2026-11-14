import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:hello_flutter/auth/home_page.dart';
import 'package:hello_flutter/plants/plant_api.dart';
import 'package:hello_flutter/plants/plant_form_page.dart';

import 'support/fake_plant_api.dart';

Future<void> showHome(WidgetTester tester, FakePlantApi api) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomePage(username: 'alice', onLogout: () async {}, plantApi: api),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  final button = find.byKey(const Key('save-plant'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('植物列表可以新建档案并查看主页', (tester) async {
    final api = FakePlantApi();
    await showHome(tester, api);
    expect(find.textContaining('还没有植物'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-plant')));
    await tester.pumpAndSettle();
    final decoration = tester
        .widget<InputDecorator>(
          find.descendant(
            of: find.byKey(const Key('plant-species')),
            matching: find.byType(InputDecorator),
          ),
        )
        .decoration;
    final label = decoration.label! as Text;
    final marker = (label.textSpan! as TextSpan).children!.single as TextSpan;
    expect(label.textSpan!.toPlainText(), '品种 *');
    expect(marker.text, '*');
    expect(marker.style!.color, Colors.red);
    expect(find.textContaining('选填'), findsNothing);
    expect(find.textContaining('留空'), findsNothing);
    expect(find.text('种植日期'), findsOneWidget);
    expect(find.text('开始养护日期'), findsOneWidget);
    await save(tester);
    expect(find.text('请填写植物品种'), findsOneWidget);
    expect(api.plants, isEmpty);
    await tester.enterText(find.byKey(const Key('plant-species')), ' 绿萝 ');
    await save(tester);
    expect(api.lastInput!.species, '绿萝');
    expect(api.lastInput!.nickname, isNull);
    expect(api.lastInput!.careStartDate, isNull);
    expect(find.byKey(const Key('plant-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('plant-1')));
    await tester.pumpAndSettle();
    expect(find.text('植物主页'), findsOneWidget);
    expect(find.text('品种：绿萝'), findsOneWidget);
    expect(find.text('种植日期：未填写'), findsOneWidget);
    expect(find.text('开始养护日期：2026-11-14'), findsOneWidget);
    expect(api.reads, 1);
  });

  testWidgets('编辑表单回填并支持修改选项和清空字段', (tester) async {
    final api = FakePlantApi();
    await api.create(
      const PlantInput(
        species: '绿萝',
        nickname: '小绿',
        plantingDate: '2025-01-02',
        careStartDate: '2025-01-03',
        growingLocation: 'INDOOR',
        cultivationMethod: 'SOIL',
        description: '窗边养护',
      ),
    );
    await showHome(tester, api);
    await tester.tap(find.byKey(const Key('plant-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-plant')));
    await tester.pumpAndSettle();
    expect(find.text('小绿'), findsOneWidget);
    expect(find.text('2025-01-02'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('plant-species')), '吊兰');
    await tester.enterText(find.byKey(const Key('plant-nickname')), '');
    await tester.tap(find.byKey(const Key('clear-planting-date')));
    await tester.tap(find.byKey(const Key('clear-care-start-date')));
    await tester.ensureVisible(find.byKey(const Key('growing-location')));
    await tester.tap(find.byKey(const Key('growing-location')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('室外').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('cultivation-method')));
    await tester.tap(find.byKey(const Key('cultivation-method')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('水培').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('plant-description')), '');
    await save(tester);
    expect(api.lastInput!.plantingDate, isNull);
    expect(api.lastInput!.careStartDate, isNull);
    expect(api.lastInput!.description, isNull);
    expect(api.lastInput!.growingLocation, 'OUTDOOR');
    expect(api.lastInput!.cultivationMethod, 'WATER');
    expect(find.text('吊兰'), findsOneWidget);
    expect(find.text('培养地：室外'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('plant-1')),
        matching: find.text('吊兰'),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('手机尺寸下可以选择日期并清空培养选项', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakePlantApi();
    await api.create(
      const PlantInput(
        species: '绿萝',
        growingLocation: 'INDOOR',
        cultivationMethod: 'SOIL',
      ),
    );
    await showHome(tester, api);
    await tester.tap(find.byKey(const Key('plant-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('edit-plant')));
    await tester.tap(find.byKey(const Key('edit-plant')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planting-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    for (final key in ['growing-location', 'cultivation-method']) {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('未填写').last);
      await tester.pumpAndSettle();
    }
    await save(tester);
    expect(
      api.lastInput!.plantingDate,
      matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
    );
    expect(api.lastInput!.growingLocation, isNull);
    expect(api.lastInput!.cultivationMethod, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('删除需要确认，取消保留档案，确定后刷新列表', (tester) async {
    final api = FakePlantApi();
    await api.create(const PlantInput(species: '绿萝'));
    await showHome(tester, api);
    await tester.tap(find.byKey(const Key('plant-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('delete-plant')));
    await tester.tap(find.byKey(const Key('delete-plant')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(api.plants, hasLength(1));
    await tester.tap(find.byKey(const Key('delete-plant')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-plant')));
    await tester.pumpAndSettle();
    expect(api.plants, isEmpty);
    expect(find.textContaining('还没有植物'), findsOneWidget);
  });

  testWidgets('列表加载失败显示错误，刷新后显示实际数据', (tester) async {
    final api = FakePlantApi()..failure = '未登录';
    await showHome(tester, api);
    expect(find.text('未登录'), findsOneWidget);
    expect(find.textContaining('还没有植物'), findsNothing);
    api.failure = null;
    await tester.tap(find.byKey(const Key('refresh-plants')));
    await tester.pumpAndSettle();
    expect(find.textContaining('还没有植物'), findsOneWidget);
  });

  testWidgets('保存失败保留用户输入并允许重试', (tester) async {
    final api = FakePlantApi();
    await showHome(tester, api);
    await tester.tap(find.byKey(const Key('add-plant')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('plant-species')), '绿萝');
    api.failure = '暂时无法保存';
    await save(tester);
    expect(find.text('暂时无法保存'), findsOneWidget);
    expect(api.plants, isEmpty);
    expect(find.byType(PlantFormPage), findsOneWidget);
    api.failure = null;
    await save(tester);
    expect(api.plants.values.single.species, '绿萝');
  });
}
