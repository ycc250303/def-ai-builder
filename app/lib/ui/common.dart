import 'package:material_ui/material_ui.dart';

import '../data/app_store.dart';
import '../data/models.dart';
import '../l10n/app_localizations.dart';

const ink = Color(0xff183135);
const paper = Color(0xfffdfdfd);
const leaf = Color(0xffd9f3ce);
const rose = Color(0xfff5b5cb);
const butter = Color(0xfff2db89);
const aqua = Color(0xffb5e4ea);
const lavender = Color(0xffece7fb);
const muted = Color(0xff697169);

class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({super.key, required AppStore store, required super.child})
    : super(notifier: store);
  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

Future<T?> openPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
void message(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: const Color(0xffaab5ac), width: 1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = leaf});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: ink),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.scroll = true,
  });
  final String title;
  final Widget child;
  final List<Widget> actions;
  final bool scroll;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: scroll
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: child,
                )
              : child,
        ),
      ),
    ),
  );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Container(width: 5, height: 16, color: leaf),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class StatBar extends StatelessWidget {
  const StatBar(this.label, this.value, this.color, this.icon, {super.key});
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text(
            '${value.round()}',
            style: const TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ),
      const SizedBox(height: 5),
      PixelProgress(value: value / 100, color: color),
    ],
  );
}

class PixelProgress extends StatelessWidget {
  const PixelProgress({
    super.key,
    required this.value,
    this.color = rose,
    this.height = 12,
  });
  final double value, height;
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
    value: '${(value.clamp(0, 1) * 100).round()}%',
    child: Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ink, width: 1.6),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0, 1),
        child: ColoredBox(color: color),
      ),
    ),
  );
}

class EmptyMessage extends StatelessWidget {
  const EmptyMessage(
    this.title,
    this.description, {
    super.key,
    this.icon = Icons.eco_outlined,
  });
  final String title, description;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 16),
    child: Center(
      child: Column(
        children: [
          Icon(icon, size: 46, color: const Color(0xff789970)),
          const SizedBox(height: 15),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, height: 1.7),
          ),
        ],
      ),
    ),
  );
}

class PixelSprite extends StatelessWidget {
  const PixelSprite(
    this.asset, {
    super.key,
    this.size = 80,
    this.fit = BoxFit.contain,
  });
  final String asset;
  final double size;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/plant_mate/${asset == 'tuantuan' ? 'characters' : 'pets'}/$asset.png',
    width: size,
    height: size,
    fit: fit,
    filterQuality: FilterQuality.none,
  );
}

class Avatar extends StatelessWidget {
  const Avatar(
    this.name,
    this.color, {
    super.key,
    this.size = 40,
    this.asset = 'eggie',
  });
  final String name, asset;
  final int color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Color(color),
      borderRadius: BorderRadius.circular(12),
    ),
    child: PixelSprite(asset, size: size),
  );
}

extension LocalizedContext on BuildContext {
  AppLocalizations get l => AppLocalizations.of(this)!;
  bool get english => Localizations.localeOf(this).languageCode == 'en';
}

String formLabel(BuildContext c, int stage) =>
    [c.l.initial, c.l.second, c.l.mature][stage];
String actionLabel(BuildContext c, PlantAction? a) => a == null
    ? c.l.idle
    : [c.l.feed, c.l.cleanAction, c.l.play, c.l.explore, c.l.sleep][a.index];
String modeLabel(BuildContext c, VisitMode m) => [
  c.l.public,
  c.l.request,
  c.l.closed,
  c.l.allowFollowing,
  c.l.allowMutual,
  c.l.allowFollowers,
][m.index];
String modeDescription(BuildContext c, VisitMode m) => [
  c.l.publicNote,
  c.l.requestNote,
  c.l.closedNote,
  c.l.followingNote,
  c.l.mutualNote,
  c.l.followersNote,
][m.index];
Future<bool> confirmDelete(BuildContext c) => showDialog<bool>(
  context: c,
  builder: (c) => AlertDialog(
    title: Text(c.l.confirmDelete),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c, false),
        child: Text(c.l.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(c, true),
        child: Text(c.l.delete),
      ),
    ],
  ),
).then((v) => v == true);
String eventBody(BuildContext c, DiaryEvent e) =>
    c.english && e.bodyEn.isNotEmpty ? e.bodyEn : e.body;
String dateLabel(DateTime t) =>
    '${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
String elapsed(DateTime start) {
  final seconds = DateTime.now().difference(start).inSeconds.clamp(0, 999999);
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}
