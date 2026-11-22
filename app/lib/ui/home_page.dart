import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import 'common.dart';
import 'garden_scene.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.fullGarden,
    required this.onFullGarden,
  });
  final bool fullGarden;
  final ValueChanged<bool> onFullGarden;
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context), g = store.data.selected;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton(
                  key: const ValueKey('plant-selector'),
                  onPressed: () => selectPlant(context),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text(
                    '${g.name}  ⌄',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                    ),
                  ),
                ),
                Text(
                  g.archived
                      ? context.l.archived
                      : g.deviceId == null
                      ? context.l.disconnected
                      : context.l.connected,
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l.editGarden,
            onPressed: g.archived
                ? null
                : () => openPage(context, GardenEditorPage(id: g.id)),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
    );
    Widget scene() => Stack(
      fit: StackFit.expand,
      children: [
        GardenScene(
          garden: g.snapshot(),
          action: g.action,
          interactive: fullGarden,
        ),
        Positioned(
          top: 20,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xffcfe3d1),
              border: Border.all(color: const Color(0xff315a52), width: 2),
              boxShadow: const [
                BoxShadow(offset: Offset(3, 3), color: Color(0x44183135)),
              ],
            ),
            child: Text(
              actionLabel(context, g.action),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: Tag(
            'GARDEN · DAY ${DateTime.now().difference(g.createdAt).inDays + 1}',
            color: Colors.white,
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: OutlinedButton(
            key: const ValueKey('open-garden'),
            style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
            onPressed: () => onFullGarden(!fullGarden),
            child: Text(
              fullGarden ? context.l.exitFull : context.l.openFull,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
      ],
    );
    if (fullGarden) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) onFullGarden(false);
        },
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: context.l.backHome,
                  onPressed: () => onFullGarden(false),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    g.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Expanded(child: scene()),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        key: const PageStorageKey('home-scroll'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (g.archived)
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: () =>
                      openPage(context, const _PlantBindingEntry()),
                  child: Text(context.l.emptyPlants),
                ),
              ),
            SizedBox(
              height: (box.maxHeight * .57).clamp(290.0, 510.0),
              child: GestureDetector(
                onTap: () => onFullGarden(true),
                child: scene(),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: ink)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      PixelSprite(g.pet.formId, size: 27),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          g.pet.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      Tag('Lv.${g.pet.level}', color: rose),
                    ],
                  ),
                  const SizedBox(height: 14),
                  StatsGrid(pet: g.pet),
                  const SizedBox(height: 14),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l.xp,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${g.pet.xp % 100} / 100',
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  PixelProgress(value: (g.pet.xp % 100) / 100, height: 9),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(border: Border.all(color: ink)),
                    child: Text(
                      '${context.l.event}  ${g.events.isEmpty ? context.l.noEvent : eventBody(context, g.events.first)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 空植物状态仍可以从已有植物管理入口开始绑定。
class _PlantBindingEntry extends StatelessWidget {
  const _PlantBindingEntry();
  @override
  Widget build(BuildContext context) => PageFrame(
    title: context.l.plants,
    child: Column(
      children: [
        Text(context.l.archiveNote),
        const SizedBox(height: 12),
        for (final g in AppScope.of(context).data.gardens)
          ListTile(
            title: Text(g.name),
            trailing: TextButton(
              onPressed: () async {
                await AppScope.of(context).restorePlant(g.id);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(context.l.restore),
            ),
          ),
      ],
    ),
  );
}

Future<void> selectPlant(BuildContext context) async {
  final store = AppScope.of(context);
  final id = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              c.l.selectPlant,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          for (final g in store.data.activeGardens)
            ListTile(
              leading: PixelSprite(g.pet.formId, size: 40),
              title: Text(g.name),
              subtitle: Text('${g.pet.name} · Lv.${g.pet.level}'),
              trailing: store.data.selectedId == g.id
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(c, g.id),
            ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
  if (id != null) await store.select(id);
}

class StatsGrid extends StatelessWidget {
  const StatsGrid({super.key, required this.pet});
  final Pet pet;
  @override
  Widget build(BuildContext c) => Column(
    children: [
      Row(
        children: [
          Expanded(child: StatBar(c.l.food, pet.satiety, leaf, Icons.grass)),
          const SizedBox(width: 15),
          Expanded(
            child: StatBar(c.l.mood, pet.mood, rose, Icons.favorite_border),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: StatBar(
              c.l.energy,
              pet.energy,
              const Color(0xff39b39d),
              Icons.bolt,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: StatBar(
              c.l.clean,
              pet.cleanliness,
              aqua,
              Icons.water_drop_outlined,
            ),
          ),
        ],
      ),
    ],
  );
}

class GardenEditorPage extends StatefulWidget {
  const GardenEditorPage({super.key, required this.id});
  final String id;
  @override
  State<GardenEditorPage> createState() => _GardenEditorPageState();
}

class _GardenEditorPageState extends State<GardenEditorPage> {
  List<SceneItem>? items;
  String? selected;
  bool saving = false;
  bool browsing = false;
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context), g = store.garden(widget.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l.editGarden),
        actions: [
          TextButton(
            onPressed: saving
                ? null
                : () async {
                    setState(() => saving = true);
                    final layout =
                        items ?? (await SceneLayout.shared).merged(g.items);
                    await store.saveLayout(g.id, layout);
                    if (context.mounted) {
                      Navigator.pop(context);
                      message(context, context.l.layoutSaved);
                    }
                  },
            child: Text(context.l.finishEdit),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('browse-map'),
                      onPressed: browsing
                          ? null
                          : () => setState(() => browsing = true),
                      icon: const Icon(Icons.pan_tool_outlined, size: 16),
                      label: Text(context.l.browseMap),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('adjust-decorations'),
                      onPressed: browsing
                          ? () => setState(() => browsing = false)
                          : null,
                      icon: const Icon(Icons.open_with, size: 16),
                      label: Text(context.l.adjustDecorations),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                browsing ? context.l.browseHint : context.l.moveHint,
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ),
            Expanded(
              child: FutureBuilder<SceneLayout>(
                future: SceneLayout.shared,
                initialData: SceneLayout.cached,
                builder: (c, s) {
                  if (s.hasError) {
                    Error.throwWithStackTrace(s.error!, s.stackTrace!);
                  }
                  if (!s.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  items ??= s.data!.merged(g.items);
                  return GardenScene(
                    garden: g.snapshot(),
                    interactive: true,
                    editing: !browsing,
                    animate: false,
                    items: items,
                    highlight: selected,
                    onMove: (id, dx, dy) => setState(() {
                      selected = id;
                      final i = items!.singleWhere((i) => i.id == id);
                      i.x = (i.x + dx).clamp(0, 675 - i.width);
                      i.y = (i.y + dy).clamp(0, 1292 - i.height);
                    }),
                    onSelect: (id) => editItem(context, id),
                  );
                },
              ),
            ),
            TextButton.icon(
              onPressed: () => restoreItem(context),
              icon: const Icon(Icons.unarchive_outlined),
              label: Text(context.l.restoreDecor),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> editItem(BuildContext context, String id) async {
    setState(() => selected = id);
    final item = items!.singleWhere((i) => i.id == id);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(c.l.putAway),
              leading: const Icon(Icons.inventory_2_outlined),
              onTap: () => Navigator.pop(c, 'hide'),
            ),
            for (final (asset, label) in [
              ('exploration_mushroom', c.l.mushroom),
              ('flower_cluster_01', c.l.flower),
              ('stones_top', c.l.stones),
              ('fence_lower_1', c.l.fence),
            ])
              ListTile(
                leading: Image.asset(
                  'assets/plant_mate/decorations/$asset.png',
                  width: 40,
                  height: 40,
                  filterQuality: FilterQuality.none,
                ),
                title: Text('${c.l.replace} · $label'),
                onTap: () => Navigator.pop(c, asset),
              ),
          ],
        ),
      ),
    );
    if (choice != null && mounted) {
      setState(() {
        if (choice == 'hide') {
          item.visible = false;
        } else {
          item.asset = 'decorations/$choice.png';
        }
      });
    }
  }

  Future<void> restoreItem(BuildContext context) async {
    final hidden = items?.where((i) => !i.visible).toList() ?? [];
    final id = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            if (hidden.isEmpty) ListTile(title: Text(c.l.noHidden)),
            for (final i in hidden)
              ListTile(
                leading: Image.asset(
                  'assets/plant_mate/${i.asset}',
                  width: 40,
                  height: 40,
                  filterQuality: FilterQuality.none,
                ),
                title: Text(c.l.restore),
                onTap: () => Navigator.pop(c, i.id),
              ),
          ],
        ),
      ),
    );
    if (id != null && mounted) {
      setState(() => items!.singleWhere((i) => i.id == id).visible = true);
    }
  }
}
