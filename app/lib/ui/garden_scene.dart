import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';

class SceneLayout {
  SceneLayout(this.ground, this.items);
  final List<Map<String, dynamic>> ground;
  final List<SceneItem> items;
  static SceneLayout? cached;
  static final Future<SceneLayout> shared = _load();
  static Future<SceneLayout> _load() async {
    final j = jsonDecode(
      await rootBundle.loadString('assets/plant_mate/map/layout.json'),
    ) as Map<String, dynamic>;
    final layout = SceneLayout(
      (j['ground'] as List).cast<Map<String, dynamic>>(),
      (j['layers'] as List)
          .map(
            (e) => SceneItem(
              id: e['id'] as String,
              asset: e['asset'] as String,
              x: (e['left'] as num).toDouble(),
              y: (e['top'] as num).toDouble(),
              width: (e['width'] as num).toDouble(),
              height: (e['height'] as num).toDouble(),
            ),
          )
          .toList(),
    );
    cached = layout;
    return layout;
  }

  List<SceneItem> merged(List<SceneItem> overrides) {
    final map = {
      for (final i in items) i.id: SceneItem.fromJson(i.toJson()),
      for (final i in overrides) i.id: SceneItem.fromJson(i.toJson()),
    };
    return map.values.toList();
  }
}

/// 动画仅改变画面，业务数值由行为规则独立结算。
class GardenScene extends StatefulWidget {
  const GardenScene({
    super.key,
    required this.garden,
    this.action,
    this.animate = true,
    this.interactive = false,
    this.editing = false,
    this.items,
    this.onMove,
    this.onSelect,
    this.highlight,
    this.onObjectTap,
    this.captureKey,
  });
  final PublicGarden garden;
  final PlantAction? action;
  final bool animate, interactive, editing;
  final List<SceneItem>? items;
  final void Function(String, double, double)? onMove;
  final ValueChanged<String>? onSelect;
  final String? highlight;
  final void Function(String)? onObjectTap;
  final GlobalKey? captureKey;
  @override
  State<GardenScene> createState() => _GardenSceneState();
}

class _GardenSceneState extends State<GardenScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 15),
  );
  final transform = TransformationController();
  Size? viewport;
  @override
  void initState() {
    super.initState();
    if (widget.animate) animation.repeat();
  }

  @override
  void didUpdateWidget(GardenScene old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate) {
      widget.animate ? animation.repeat() : animation.stop();
    }
    if (old.garden.id != widget.garden.id) viewport = null;
  }

  @override
  void dispose() {
    animation.dispose();
    transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SceneLayout>(
    future: SceneLayout.shared,
    initialData: SceneLayout.cached,
    builder: (context, snap) {
      if (snap.hasError) {
        Error.throwWithStackTrace(snap.error!, snap.stackTrace!);
      }
      if (!snap.hasData) return const ColoredBox(color: Color(0xff348e8e));
      final layout = snap.data!;
      final items = widget.items ?? layout.merged(widget.garden.items);
      return LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          if (viewport != size) {
            viewport = size;
            final scale = size.width / 390;
            transform.value = Matrix4.identity()
              ..translateByDouble(
                size.width / 2 - 337 * scale,
                size.height / 2 - 585 * scale,
                0,
                1,
              )
              ..scaleByDouble(scale, scale, 1, 1);
          }
          return RepaintBoundary(
            key: widget.captureKey,
            child: ClipRect(
              child: InteractiveViewer(
                transformationController: transform,
                constrained: false,
                alignment: Alignment.topLeft,
                minScale: .35,
                maxScale: 3,
                boundaryMargin: const EdgeInsets.all(500),
                panEnabled: widget.interactive && !widget.editing,
                scaleEnabled: widget.interactive && !widget.editing,
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    final phase = animation.value;
                    final wave = math.sin(phase * math.pi * 2);
                    final action = widget.action;
                    final petOffset = action == PlantAction.play
                        ? math.sin(phase * math.pi * 2) * 100
                        : 0.0;
                    final form = widget.garden.formId;
                    final petSize = form == 'eggie'
                        ? const Size(107, 144)
                        : const Size(126, 140);
                    Widget image(String asset, double w, double h) =>
                        Image.asset(
                          'assets/plant_mate/$asset',
                          width: w,
                          height: h,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.none,
                          excludeFromSemantics: true,
                        );
                    return SizedBox(
                      width: 675,
                      height: 1292,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Positioned.fill(
                            child: ColoredBox(color: Color(0xff348e8e)),
                          ),
                          for (final ground in layout.ground)
                            Positioned(
                              left: (ground['left'] as num).toDouble(),
                              top: (ground['top'] as num).toDouble(),
                              width: (ground['width'] as num).toDouble(),
                              height: (ground['height'] as num).toDouble(),
                              child: ColoredBox(
                                color: ground['water'] == true
                                    ? const Color(0xffa0d4d4)
                                    : const Color(0xff98c0ad),
                              ),
                            ),
                          for (final item in items.where((i) => i.visible))
                            Positioned(
                              left:
                                  item.x +
                                  (item.id.contains('ufo') && !widget.editing
                                      ? wave * 20
                                      : 0),
                              top: item.y,
                              width: item.width,
                              height: item.height,
                              child: Listener(
                                key: ValueKey('scene-item-${item.id}'),
                                behavior: HitTestBehavior.opaque,
                                onPointerMove: widget.editing
                                    ? (e) => widget.onMove?.call(
                                        item.id,
                                        e.delta.dx /
                                            transform.value.getMaxScaleOnAxis(),
                                        e.delta.dy /
                                            transform.value.getMaxScaleOnAxis(),
                                      )
                                    : null,
                                child: GestureDetector(
                                  onTap: widget.editing
                                      ? () => widget.onSelect?.call(item.id)
                                      : null,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: item.id == widget.highlight
                                          ? Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                    child: image(
                                      item.asset,
                                      item.width,
                                      item.height,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            left:
                                184 +
                                (action == PlantAction.explore
                                    ? -180 * math.sin(phase * math.pi).abs()
                                    : 0),
                            top:
                                516 +
                                (action == PlantAction.play ? wave * 9 : 0),
                            child: image('characters/tuantuan.png', 154, 159),
                          ),
                          Positioned(
                            left: 397 + petOffset,
                            top:
                                540 +
                                (action == PlantAction.play
                                    ? -wave.abs() * 15
                                    : 0),
                            child: Transform.rotate(
                              angle: action == PlantAction.play
                                  ? wave * (form == 'eggie' ? 2 : .18)
                                  : action == PlantAction.clean
                                  ? wave * .06
                                  : 0,
                              child: Transform.scale(
                                scaleY: action == PlantAction.sleep
                                    ? 1 - wave.abs() * .06
                                    : 1,
                                child: image(
                                  'pets/$form.png',
                                  petSize.width,
                                  petSize.height,
                                ),
                              ),
                            ),
                          ),
                          if (action == PlantAction.feed)
                            Positioned(
                              left: 356,
                              top: 625 - wave.abs() * 10,
                              child: image(
                                'effects/food_fried_egg.png',
                                65,
                                50,
                              ),
                            ),
                          if (action == PlantAction.clean)
                            Positioned(
                              left: 365,
                              top: 520 - wave * 5,
                              child: Opacity(
                                opacity: .75,
                                child: image(
                                  'effects/bubble_cluster.png',
                                  170,
                                  170,
                                ),
                              ),
                            ),
                          if (action == PlantAction.sleep) ...[
                            Positioned(
                              left: 409,
                              top: 590,
                              child: image(
                                'effects/eyemask_original_cutout.png',
                                86,
                                42,
                              ),
                            ),
                            const Positioned(
                              left: 490,
                              top: 520,
                              child: Text(
                                'Zzz',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
