import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plant/data/device_client.dart';
import 'package:plant/main.dart';
import 'package:plant/ui/garden_scene.dart';
import 'package:plant/ui/home_page.dart';
import 'package:plant/ui/mine_pages.dart';

import 'device_fixture.dart';
import 'test_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await SceneLayout.shared);

  Future<void> step(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
  }

  Future<void> toggle(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('toggle-pet-data'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await step(tester);
  }

  testWidgets('宠物页面切换硬件读数后恢复游戏数据，游戏快照与保存内容保持一致', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = MemoryStorage();
    final store = await seededStore(storage);
    await store.language('zh');
    final original = jsonEncode(store.data.toJson());
    final saved = storage.value;
    final clients = <TestDeviceClient>[];
    DeviceClient createClient() {
      final client = TestDeviceClient((_) async => deviceSnapshot());
      clients.add(client);
      return client;
    }

    await tester.pumpWidget(PlantMateApp(store: store, runClock: false));
    final nav = Navigator.of(tester.element(find.byType(HomePage)));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => PetPage(id: 'g1', createDeviceClient: createClient),
      ),
    );
    await step(tester);
    expect(clients, isEmpty);
    expect(find.text('游戏数据'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PetPage),
        matching: find.byType(StatsGrid),
      ),
      findsOneWidget,
    );
    await toggle(tester);
    expect(find.text('硬件数据'), findsOneWidget);
    expect(find.text('24.6 °C'), findsOneWidget);
    expect(find.text('61.0 %RH'), findsOneWidget);
    expect(find.text('480 lux'), findsOneWidget);
    expect(find.text('开路 / HIGH'), findsOneWidget);
    expect(find.text('触摸电极: ELE0, ELE2'), findsOneWidget);
    expect(find.text('数据来源：硬件设备'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PetPage),
        matching: find.byType(StatsGrid),
      ),
      findsNothing,
    );
    expect(jsonEncode(store.data.toJson()), original);
    expect(storage.value, saved);
    await tester.pump(const Duration(seconds: 1));
    expect(clients.single.reads, 2);
    await tester.enterText(
      find.byKey(const ValueKey('device-address')),
      'http://192.168.4.2:8790',
    );
    await tester.pump();
    expect(clients.single.closed, isTrue);
    expect(find.text('24.6 °C'), findsNothing);
    await toggle(tester);
    expect(find.text('游戏数据'), findsOneWidget);
    expect(clients.single.closed, isTrue);
    final reads = clients.single.reads;
    await tester.pump(const Duration(seconds: 2));
    expect(clients.single.reads, reads);
    expect(jsonEncode(store.data.toJson()), original);
    await toggle(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('device-address')))
          .controller!
          .text,
      'http://192.168.4.2:8790',
    );
    nav.pop();
    await step(tester);
    expect(clients.last.closed, isTrue);
    expect(storage.value, saved);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('英文页面标记电脑模拟来源与传感器空值，非法地址停止连接', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await seededStore(MemoryStorage());
    await store.language('en');
    final data = deviceData(source: 'simulation');
    (data['sensors'] as Map<String, dynamic>)['temperature_c'] = null;
    final client = TestDeviceClient(
      (_) async => DeviceSnapshot.decode(jsonEncode(data)),
    );
    await tester.pumpWidget(PlantMateApp(store: store, runClock: false));
    final nav = Navigator.of(tester.element(find.byType(HomePage)));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => PetPage(id: 'g1', createDeviceClient: () => client),
      ),
    );
    await step(tester);
    await toggle(tester);
    expect(find.text('Source: desktop simulation'), findsOneWidget);
    expect(find.text('Sensor data unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byKey(const ValueKey('device-address')),
      'http://example.com',
    );
    final connect = find.byKey(const ValueKey('connect-device'));
    await tester.ensureVisible(connect);
    await tester.tap(connect);
    await step(tester);
    expect(find.textContaining('Enter a local HTTP address'), findsOneWidget);
    expect(client.closed, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('后台与被覆盖的宠物页面暂停读取，恢复后重新连接', (tester) async {
    final store = await seededStore(MemoryStorage());
    await store.language('zh');
    final clients = <TestDeviceClient>[];
    DeviceClient createClient() {
      final client = TestDeviceClient((_) async => deviceSnapshot());
      clients.add(client);
      return client;
    }

    await tester.pumpWidget(PlantMateApp(store: store, runClock: false));
    final nav = Navigator.of(tester.element(find.byType(HomePage)));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => PetPage(id: 'g1', createDeviceClient: createClient),
      ),
    );
    await step(tester);
    await toggle(tester);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(clients.single.closed, isTrue);
    expect(find.text('数据读取已暂停'), findsOneWidget);
    final reads = clients.single.reads;
    await tester.pump(const Duration(seconds: 3));
    expect(clients.single.reads, reads);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await step(tester);
    expect(clients, hasLength(2));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('其他页面')),
      ),
    );
    await step(tester);
    await tester.pump();
    expect(clients.last.closed, isTrue);
    nav.pop();
    await step(tester);
    expect(clients, hasLength(3));
    expect(find.text('正在接收数据'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('连接错误明确展示并可重新连接，切回游戏忽略迟到响应', (tester) async {
    final store = await seededStore(MemoryStorage());
    await store.language('zh');
    final pending = Completer<DeviceSnapshot>();
    final clients = [
      TestDeviceClient(
        (_) async => throw const DeviceConnectionException('HTTP 503'),
      ),
      TestDeviceClient((_) => pending.future),
    ];
    await tester.pumpWidget(PlantMateApp(store: store, runClock: false));
    final nav = Navigator.of(tester.element(find.byType(HomePage)));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PetPage(id: 'g1', createDeviceClient: () => clients.removeAt(0)),
      ),
    );
    await step(tester);
    await toggle(tester);
    expect(find.textContaining('连接失败'), findsOneWidget);
    expect(find.text('HTTP 503'), findsOneWidget);
    final connect = find.byKey(const ValueKey('connect-device'));
    await tester.ensureVisible(connect);
    await tester.tap(connect);
    await step(tester);
    expect(find.text('正在连接设备…'), findsOneWidget);
    await toggle(tester);
    pending.complete(deviceSnapshot());
    await step(tester);
    expect(find.text('游戏数据'), findsOneWidget);
    expect(find.text('24.6 °C'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
