import 'dart:ui' show PointerDeviceKind;

import 'package:ditredi/ditredi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plant/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('正方体资源包含八个顶点、十二个三角面和六种面颜色', () async {
    final model = await loadCubeModel();

    expect(model.faces, hasLength(12));
    expect(model.faces.map((face) => face.color).toSet(), hasLength(6));
    final vertices = model.toPoints().map((point) => point.position).toSet();
    expect(vertices, hasLength(8));
    for (final vertex in vertices) {
      expect(vertex.x.abs(), 1);
      expect(vertex.y.abs(), 1);
      expect(vertex.z.abs(), 1);
    }
  });

  for (final device in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('${device.name} 拖拽支持两个方向完整旋转并重置视角', (tester) async {
      final model = await tester.runAsync(loadCubeModel);
      await tester.pumpWidget(MyApp(model: model!));

      expect(find.text('正方体查看器'), findsOneWidget);
      final scene = tester.widget<DiTreDi>(find.byType(DiTreDi));
      expect(scene.figures.single, same(model));
      final controller = scene.controller;
      final viewport = find.byKey(const ValueKey('cube-viewport'));
      final start = tester.getCenter(viewport);

      // 从相同位置累计拖拽，验证越过完整一周后仍可继续旋转。
      for (var index = 0; index < 8; index++) {
        final gesture = await tester.startGesture(start, kind: device);
        await gesture.moveBy(const Offset(20, 20));
        final rotationX = controller.rotationX;
        final rotationY = controller.rotationY;
        await gesture.moveBy(const Offset(100, 100));
        await gesture.up();
        await tester.pump();

        expect(controller.rotationX, closeTo((rotationX - 50) % 360, 0.001));
        expect(controller.rotationY, closeTo((rotationY - 50) % 360, 0.001));
        expect(controller.rotationX.isFinite, isTrue);
        expect(controller.rotationY.isFinite, isTrue);
        expect(tester.takeException(), isNull);
      }

      await tester.tap(find.byTooltip('重置视角'));
      await tester.pump();
      expect(controller.rotationX, -25);
      expect(controller.rotationY, 35);
      expect(tester.takeException(), isNull);
    });
  }
}
