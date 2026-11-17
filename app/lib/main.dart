import 'package:ditredi/ditredi.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final model = await loadCubeModel();
  runApp(MyApp(model: model));
}

/// 启动时加载模型和材质，资源缺失或解析失败时立即暴露错误。
Future<Mesh3D> loadCubeModel() async {
  final parser = ObjParser();
  final source = await rootBundle.loadString('assets/models/cube.obj');
  final materialSource = await rootBundle.loadString('assets/models/cube.mtl');
  final materials = await parser.parseMtlLib(materialSource);
  if (materials == null || materials.isEmpty) {
    throw const FormatException('正方体材质文件必须包含面颜色');
  }
  final parsedFaces = await parser.parse(
    source,
    materialLib: {'cube.mtl': materials},
  );
  // 渲染表面由具有面积的三角形组成。
  final faces = parsedFaces.where((face) {
    final triangle = face.triangle;
    final firstEdge = triangle.point1 - triangle.point0;
    final secondEdge = triangle.point2 - triangle.point0;
    return firstEdge.cross(secondEdge).length2 > 0;
  }).toList();
  if (faces.isEmpty || faces.any((face) => face.color == null)) {
    throw const FormatException('正方体模型必须包含有效表面和材质');
  }
  return Mesh3D(faces);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.model});

  final Mesh3D model;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '正方体查看器',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4263EB)),
        scaffoldBackgroundColor: const Color(0xFFF3F5FA),
      ),
      home: CubeViewerPage(model: model),
    );
  }
}

class CubeViewerPage extends StatefulWidget {
  const CubeViewerPage({super.key, required this.model});

  final Mesh3D model;

  @override
  State<CubeViewerPage> createState() => _CubeViewerPageState();
}

class _CubeViewerPageState extends State<CubeViewerPage> {
  final _controller = DiTreDiController(
    rotationX: -25,
    rotationY: 35,
    ambientLightStrength: 0.65,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('正方体查看器'),
        actions: [
          IconButton(
            tooltip: '重置视角',
            onPressed: () => _controller.update(rotationX: -25, rotationY: 35),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Semantics(
                    label: '三维正方体，拖拽可以旋转观察',
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: GestureDetector(
                        key: const ValueKey('cube-viewport'),
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) {
                          // 两个旋转方向均允许完整转动，角度归一化后连续拖拽。
                          _controller.update(
                            rotationX:
                                (_controller.rotationX -
                                    details.delta.dy * 0.5) %
                                360,
                            rotationY:
                                (_controller.rotationY -
                                    details.delta.dx * 0.5) %
                                360,
                          );
                        },
                        child: DiTreDi(
                          figures: [widget.model],
                          controller: _controller,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Text(
                '按住并拖拽，360° 观察正方体\n支持鼠标拖拽和手指滑动',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
