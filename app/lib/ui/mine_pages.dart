import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import 'common.dart';
import 'home_page.dart';
import 'social_pages.dart';

class MinePage extends StatelessWidget {
  const MinePage({super.key});
  @override
  Widget build(BuildContext context) {
    final d = AppScope.of(context).data, g = d.selectedGarden;
    Widget tile(
      String title,
      String subtitle,
      String asset,
      Color bg,
      Widget page,
    ) => Expanded(
      child: PaperCard(
        padding: const EdgeInsets.all(10),
        onTap: () => openPage(context, page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(9),
              ),
              padding: const EdgeInsets.all(12),
              child: PixelSprite(asset, size: 110),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: muted)),
          ],
        ),
      ),
    );
    Widget menu(String label, IconData icon, Widget page) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Icon(icon, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => openPage(context, page),
    );
    return SingleChildScrollView(
      key: const PageStorageKey('mine-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l.me,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.l.settings,
                onPressed: () => openPage(context, const SettingsPage()),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PaperCard(
            onTap: () => openPage(context, const EditProfilePage()),
            child: Row(
              children: [
                Avatar(d.nickname, 0xfffce5ef, size: 60, asset: d.avatar),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.nickname,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        d.bio,
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '@me · ${d.activeGardens.length} ${context.l.plants}',
                        style: const TextStyle(fontSize: 10, color: muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          SectionLabel(
            context.l.myCompanions,
            trailing: TextButton(
              onPressed: g == null ? null : () => selectPlant(context),
              child: Text(
                context.l.switchPlant,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          if (g == null) const PlantBindingPrompt(showManagement: true),
          if (g != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tile(
                  context.l.plants,
                  g.name,
                  'tuantuan',
                  const Color(0xffd5f2da),
                  const PlantsPage(),
                ),
                const SizedBox(width: 10),
                tile(
                  context.l.pet,
                  '${g.pet.name} · Lv.${g.pet.level}',
                  g.pet.formId,
                  const Color(0xfffceaf0),
                  PetPage(id: g.id),
                ),
              ],
            ),
            SectionLabel(context.l.myGrowth),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PaperCard(
                    onTap: () => openPage(context, EvolutionPage(id: g.id)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.auto_awesome_outlined),
                        const SizedBox(height: 10),
                        Text(
                          context.l.evolution,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          context.l.experienced,
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PaperCard(
                    onTap: () => openPage(context, DiaryPage(id: g.id)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.menu_book_outlined),
                        const SizedBox(height: 10),
                        Text(
                          context.l.diary,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          context.l.actions,
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          SectionLabel(context.l.mySpace),
          PaperCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                menu(
                  context.l.saved,
                  Icons.bookmark_border,
                  const SavedPostsPage(),
                ),
                const Divider(height: 1),
                menu(context.l.device, Icons.sensors, const DevicesPage()),
                const Divider(height: 1),
                menu(
                  context.l.privacy,
                  Icons.shield_outlined,
                  const PrivacyPage(),
                ),
                const Divider(height: 1),
                menu(
                  context.l.profile,
                  Icons.edit_outlined,
                  const EditProfilePage(),
                ),
                const Divider(height: 1),
                menu(
                  context.l.settings,
                  Icons.settings_outlined,
                  const SettingsPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlantBindingPrompt extends StatelessWidget {
  const PlantBindingPrompt({super.key, this.showManagement = false});
  final bool showManagement;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(context.l.emptyPlants, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => openPage(context, const AddPlantPage()),
        child: Text(context.l.addPlant),
      ),
      if (showManagement && AppScope.of(context).data.gardens.isNotEmpty) ...[
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => openPage(context, const PlantsPage()),
          child: Text(context.l.plants),
        ),
      ],
    ],
  );
}

class PlantsPage extends StatelessWidget {
  const PlantsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context), d = store.data;
    return PageFrame(
      title: context.l.plants,
      actions: [
        IconButton(
          tooltip: context.l.addPlant,
          onPressed: () => openPage(context, const AddPlantPage()),
          icon: const Icon(Icons.add),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () => openPage(context, const AddPlantPage()),
            icon: const Icon(Icons.add),
            label: Text(context.l.addPlant),
          ),
          const SizedBox(height: 16),
          for (final g in d.activeGardens)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const PixelSprite('tuantuan', size: 48),
                      title: Text(g.name),
                      subtitle: Text('${context.l.pothos} · ${g.pet.name}'),
                      onTap: () => openPage(context, MonitorPage(id: g.id)),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => renamePlant(context, g),
                          child: Text(context.l.edit),
                        ),
                        TextButton(
                          onPressed: () async {
                            await store.select(g.id);
                            if (context.mounted) {
                              openPage(context, PetPage(id: g.id));
                            }
                          },
                          child: Text(context.l.viewPet),
                        ),
                        TextButton(
                          onPressed: () => archive(context, g),
                          child: Text(context.l.archive),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (d.gardens.any((g) => g.archived))
            SectionLabel(context.l.archived),
          for (final g in d.gardens.where((g) => g.archived))
            ListTile(
              title: Text(g.name),
              subtitle: Text('${g.pet.name} · Lv.${g.pet.level}'),
              onTap: () => openPage(context, PetPage(id: g.id)),
              trailing: TextButton(
                onPressed: () => store.restorePlant(g.id),
                child: Text(context.l.restore),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> archive(BuildContext c, Garden g) async {
    final store = AppScope.of(c);
    final yes = await showDialog<bool>(
      context: c,
      builder: (c) => AlertDialog(
        title: Text(c.l.archive),
        content: Text(c.l.archiveNote),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(c.l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(c.l.archive),
          ),
        ],
      ),
    );
    if (yes == true) await store.archivePlant(g.id);
  }

  Future<void> renamePlant(BuildContext c, Garden g) async {
    final controller = TextEditingController(text: g.name);
    final store = AppScope.of(c);
    final name = await showDialog<String>(
      context: c,
      builder: (c) => AlertDialog(
        title: Text(c.l.plantName),
        content: TextField(controller: controller, maxLength: 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(c.l.cancel),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(c, controller.text);
              }
            },
            child: Text(c.l.save),
          ),
        ],
      ),
    );
    if (name != null) await store.renamePlant(g.id, name);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    controller.dispose();
  }
}

class AddPlantPage extends StatefulWidget {
  const AddPlantPage({super.key});
  @override
  State<AddPlantPage> createState() => _AddPlantPageState();
}

class _AddPlantPageState extends State<AddPlantPage> {
  final name = TextEditingController(), pet = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    pet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return PageFrame(
      title: context.l.addPlant,
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: PixelSprite('eggie', size: 140)),
            const SizedBox(height: 16),
            Text(context.l.initialPetNote),
            const SizedBox(height: 20),
            TextFormField(
              controller: name,
              maxLength: 24,
              decoration: InputDecoration(labelText: context.l.plantName),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? context.l.required : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: pet,
              maxLength: 20,
              decoration: InputDecoration(labelText: context.l.petName),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? context.l.required : null,
            ),
            const SizedBox(height: 12),
            Text(context.l.pothos),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setState(() => busy = true);
                      await store.addPlant(name.text, pet.text);
                      if (context.mounted) Navigator.pop(context);
                    },
              child: Text(context.l.addPlant),
            ),
          ],
        ),
      ),
    );
  }
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final name = TextEditingController(), bio = TextEditingController();
  final form = GlobalKey<FormState>();
  bool ready = false, busy = false;
  String avatar = 'eggie';
  @override
  void dispose() {
    name.dispose();
    bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    if (!ready) {
      ready = true;
      name.text = store.data.nickname;
      bio.text = store.data.bio;
      avatar = store.data.avatar;
    }
    return PageFrame(
      title: context.l.profile,
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Avatar(name.text, 0xfffce4ee, size: 80, asset: avatar),
            ),
            SectionLabel(context.l.chooseAvatar),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in [
                  'eggie',
                  'tuantuan',
                  'fixed',
                  ...List.generate(7, (i) => 'mature_${i + 1}'),
                ])
                  InkWell(
                    onTap: () => setState(() => avatar = id),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: avatar == id ? leaf : Colors.white,
                        border: Border.all(
                          color: avatar == id ? ink : Colors.transparent,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: PixelSprite(id, size: 45),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: name,
              maxLength: 24,
              decoration: InputDecoration(labelText: context.l.nickname),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? context.l.required : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: bio,
              maxLength: 150,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(labelText: context.l.bio),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: '@me',
              readOnly: true,
              decoration: InputDecoration(labelText: context.l.account),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setState(() => busy = true);
                      await store.profile(name.text, bio.text, avatar: avatar);
                      if (context.mounted) Navigator.pop(context);
                    },
              child: Text(context.l.save),
            ),
            TextButton(
              onPressed: () => openPage(context, const ProfilePage(id: 'me')),
              child: Text(context.l.publicProfile),
            ),
          ],
        ),
      ),
    );
  }
}

class PetPage extends StatefulWidget {
  const PetPage({super.key, required this.id});
  final String id;
  @override
  State<PetPage> createState() => _PetPageState();
}

class _PetPageState extends State<PetPage> {
  final name = TextEditingController();
  final form = GlobalKey<FormState>();
  bool ready = false, busy = false;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context), g = store.garden(widget.id);
    if (!ready) {
      ready = true;
      name.text = g.pet.name;
    }
    return PageFrame(
      title: context.l.pet,
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 210,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: const Color(0xfffceaf0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: PixelSprite(g.pet.formId, size: 160),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    g.pet.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Tag('Lv.${g.pet.level}'),
              ],
            ),
            Text(
              formLabel(context, g.pet.stage),
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 18),
            StatsGrid(pet: g.pet),
            SectionLabel(context.l.xp),
            Text('${g.pet.xp % 100} / 100 · ${g.pet.xp} XP'),
            const SizedBox(height: 8),
            PixelProgress(value: (g.pet.xp % 100) / 100),
            SectionLabel(context.l.trait),
            Text(context.l.traitNote),
            const SizedBox(height: 18),
            TextFormField(
              controller: name,
              maxLength: 20,
              decoration: InputDecoration(labelText: context.l.petName),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? context.l.required : null,
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setState(() => busy = true);
                      await store.renamePet(g.id, name.text);
                      if (mounted) setState(() => busy = false);
                    },
              child: Text(context.l.save),
            ),
            OutlinedButton(
              onPressed: () => openPage(context, EvolutionPage(id: g.id)),
              child: Text(context.l.evolution),
            ),
            TextButton(
              onPressed: () => openPage(context, DiaryPage(id: g.id)),
              child: Text(context.l.diary),
            ),
          ],
        ),
      ),
    );
  }
}

class EvolutionPage extends StatelessWidget {
  const EvolutionPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).garden(id).pet;
    return PageFrame(
      title: context.l.evolution,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l.evolutionNote),
          SectionLabel(context.l.experienced),
          for (final (index, h) in p.history.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PaperCard(
                child: Row(
                  children: [
                    PixelSprite(h.formId, size: 90),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formLabel(context, index),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Lv.${h.level} · ${dateLabel(h.time)}',
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                          if (h == p.history.last) Tag('Lv.${p.level}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key, required this.id});
  final String id;
  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  int filter = 0;
  @override
  Widget build(BuildContext context) {
    final g = AppScope.of(context).garden(widget.id);
    final events = g.events
        .where(
          (e) =>
              filter == 0 ||
              filter == 1 && ['行为', '探索'].contains(e.kind) ||
              filter == 2 && ['升级', '进化'].contains(e.kind),
        )
        .toList();
    return PageFrame(
      title: context.l.diary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final (i, label) in [
                context.l.all,
                context.l.actions,
                context.l.growth,
              ].indexed)
                ChoiceChip(
                  label: Text(label),
                  selected: filter == i,
                  onSelected: (_) => setState(() => filter = i),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (events.isEmpty) EmptyMessage(context.l.noRecords, context.l.auto),
          for (final e in events)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      dateLabel(e.time),
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      context.english && e.titleEn.isNotEmpty
                          ? e.titleEn
                          : e.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(eventBody(context, e)),
                    const SizedBox(height: 10),
                    Text(
                      '${context.l.reason}: ${context.english && e.reasonEn.isNotEmpty ? e.reasonEn : e.reason}',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                    Text(
                      '${context.l.changes}: ${context.english && e.changesEn.isNotEmpty ? e.changesEn : e.changes}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    TextButton(
                      onPressed: () => openPage(
                        context,
                        PublishPage(
                          initialBody: eventBody(context, e),
                          initialType: e.kind == '探索' ? '探索' : '花园',
                        ),
                      ),
                      child: Text(context.l.shareRecord),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MonitorPage extends StatefulWidget {
  const MonitorPage({super.key, required this.id});
  final String id;
  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  int metric = 0;
  bool week = false;
  int? point;
  @override
  Widget build(BuildContext context) {
    final g = AppScope.of(context).garden(widget.id), now = DateTime.now();
    final labels = [
      context.l.light,
      context.l.soil,
      context.l.temperature,
      context.l.humidity,
    ];
    const units = ['lux', '%', '°C', '%'];
    final readings = g.readings
        .where(
          (r) => week
              ? now.difference(r.time).inHours <= 168
              : r.time.year == now.year &&
                    r.time.month == now.month &&
                    r.time.day == now.day,
        )
        .toList();
    final values = readings.map((r) => r.values[metric]).toList();
    final inspected = readings.isEmpty
        ? null
        : readings[(point ?? readings.length - 1).clamp(
            0,
            readings.length - 1,
          )];
    return PageFrame(
      title: context.l.monitor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            g.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.l.mockSensors,
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (c, box) => Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < 4; i++)
                  SizedBox(
                    width: (box.maxWidth - 10) / 2,
                    child: PaperCard(
                      color: i == metric
                          ? [butter, aqua, rose, leaf][i]
                          : Colors.white,
                      onTap: () => setState(() {
                        metric = i;
                        point = null;
                      }),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labels[i],
                            style: const TextStyle(fontSize: 11, color: muted),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            g.readings.isEmpty
                                ? context.l.noRecords
                                : '${g.latestReading.values[i].toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            children: [
              ChoiceChip(
                label: Text(context.l.today),
                selected: !week,
                onSelected: (_) => setState(() {
                  week = false;
                  point = null;
                }),
              ),
              ChoiceChip(
                label: Text(context.l.sevenDays),
                selected: week,
                onSelected: (_) => setState(() {
                  week = true;
                  point = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${labels[metric]} / ${units[metric]}'),
                const SizedBox(height: 15),
                if (values.isEmpty)
                  Text(context.l.noRecords)
                else
                  LayoutBuilder(
                    builder: (context, box) => GestureDetector(
                      onTapDown: (e) => setState(
                        () => point =
                            (e.localPosition.dx /
                                    box.maxWidth *
                                    (values.length - 1))
                                .round()
                                .clamp(0, values.length - 1),
                      ),
                      child: SizedBox(
                        height: 190,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _ChartPainter(
                            values,
                            [butter, aqua, rose, leaf][metric],
                            point,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (inspected != null)
                  Text(
                    '${dateLabel(inspected.time)} · ${inspected.values[metric].toStringAsFixed(1)} ${units[metric]}',
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => openPage(context, const DevicesPage()),
            child: Text(context.l.device),
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.values, this.color, this.selected);
  final List<double> values;
  final Color color;
  final int? selected;
  @override
  void paint(Canvas c, Size s) {
    final dataMin = values.reduce(math.min), dataMax = values.reduce(math.max);
    final padding = math.max(.5, (dataMax - dataMin) * .1);
    final min = dataMin - padding, max = dataMax + padding, range = max - min;
    const left = 36.0;
    final w = s.width - left - 7, h = s.height - 23;
    for (var i = 0; i < 4; i++) {
      final y = i * h / 3;
      c.drawLine(
        Offset(left, y),
        Offset(s.width, y),
        Paint()
          ..color = const Color(0xffdfe5da)
          ..strokeWidth = 1,
      );
      final t = TextPainter(
        text: TextSpan(
          text: (max - i * range / 3).toStringAsFixed(range < 5 ? 1 : 0),
          style: const TextStyle(color: muted, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(c, Offset(0, y));
    }
    final points = List.generate(
      values.length,
      (i) => Offset(
        left + (values.length == 1 ? w / 2 : i * w / (values.length - 1)),
        h - (values[i] - min) / range * h,
      ),
    );
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(path)
      ..lineTo(points.last.dx, h)
      ..lineTo(points.first.dx, h)
      ..close();
    c.drawPath(fill, Paint()..color = color.withValues(alpha: .35));
    c.drawPath(
      path,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final p =
        points[(selected ?? points.length - 1).clamp(0, points.length - 1)];
    c.drawCircle(p, 4.5, Paint()..color = color);
    c.drawCircle(
      p,
      4.5,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.values != values || old.selected != selected || old.color != color;
}

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return PageFrame(
      title: context.l.device,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l.mockSensors),
          const SizedBox(height: 16),
          for (final g in store.data.activeGardens)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      g.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      g.deviceId ?? context.l.disconnected,
                      style: const TextStyle(color: muted),
                    ),
                    Wrap(
                      spacing: 10,
                      children: [
                        TextButton(
                          onPressed: () =>
                              store.setDevice(g.id, g.deviceId == null),
                          child: Text(
                            g.deviceId == null
                                ? context.l.bindDevice
                                : context.l.unbindDevice,
                          ),
                        ),
                        TextButton(
                          onPressed: g.deviceId == null
                              ? null
                              : () async {
                                  await store.sync(g.id);
                                  if (context.mounted) {
                                    message(context, context.l.synced);
                                  }
                                },
                          child: Text(context.l.sync),
                        ),
                        TextButton(
                          onPressed: () =>
                              openPage(context, MonitorPage(id: g.id)),
                          child: Text(context.l.monitor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          SectionLabel(context.l.calibration),
          Text(context.l.calibrationNote),
        ],
      ),
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return PageFrame(
      title: context.l.privacy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l.privacyNote),
          const SizedBox(height: 16),
          for (final g in store.data.activeGardens)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      g.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    RadioGroup<VisitMode>(
                      groupValue: g.visitMode,
                      onChanged: (v) => store.setVisitMode(g.id, v!),
                      child: Column(
                        children: [
                          for (final mode in VisitMode.values)
                            RadioListTile<VisitMode>(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                modeLabel(context, mode),
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(
                                modeDescription(context, mode),
                                style: const TextStyle(fontSize: 11),
                              ),
                              value: mode,
                            ),
                        ],
                      ),
                    ),
                    if (g.visitMode == VisitMode.request) ...[
                      OutlinedButton(
                        onPressed: () async {
                          await store.simulateIncomingRequest(g.id);
                          if (context.mounted) {
                            openPage(context, const NotificationsPage());
                          }
                        },
                        child: Text(context.l.simulateRequest),
                      ),
                      Text(
                        context.l.approvalDemo,
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                    TextButton(
                      onPressed: () => openPage(
                        context,
                        GardenVisitPage(ownerId: 'me', gardenId: g.id),
                      ),
                      child: Text(context.l.preview),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context), d = store.data;
    return PageFrame(
      title: context.l.settings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(context.l.language),
          RadioGroup<String>(
            groupValue: d.language,
            onChanged: (v) => store.language(v!),
            child: Column(
              children: [
                for (final (code, label) in [
                  ('system', context.l.system),
                  ('zh', context.l.chinese),
                  ('en', context.l.english),
                ])
                  RadioListTile<String>(
                    key: ValueKey('language-$code'),
                    title: Text(label),
                    value: code,
                  ),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l.socialNotifications),
            value: d.notifications,
            onChanged: (v) => store.change((d) => d.notifications = v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(context.l.account),
            subtitle: Text('@me · ${context.l.accountNote}'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline),
            title: Text(context.l.help),
            onTap: () => showDialog<void>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text(c.l.help),
                content: Text(c.l.demoNote),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: Text(c.l.close),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.eco_outlined),
            title: Text(context.l.about),
            subtitle: const Text('Plant Mate · 1.0.0'),
          ),
        ],
      ),
    );
  }
}
