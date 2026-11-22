import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'data/app_store.dart';
import 'l10n/app_localizations.dart';
import 'ui/common.dart';
import 'ui/home_page.dart';
import 'ui/garden_scene.dart';
import 'ui/mine_pages.dart';
import 'ui/social_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SceneLayout.shared;
  final store = await AppStore.load(PreferencesStorage());
  await store.advance(DateTime.now());
  runApp(PlantMateApp(store: store));
}

class PlantMateApp extends StatelessWidget {
  const PlantMateApp({super.key, required this.store, this.runClock = true});
  final AppStore store;
  final bool runClock;
  @override
  Widget build(BuildContext context) => AppScope(
    store: store,
    child: ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Plant Mate',
        locale: store.data.language == 'system'
            ? null
            : Locale(store.data.language),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const [Locale('zh'), Locale('en')],
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: paper,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff648b58),
            primary: const Color(0xff486c43),
            surface: paper,
            onSurface: ink,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: paper,
            foregroundColor: ink,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: ink, height: 1.45),
            bodySmall: TextStyle(color: muted, height: 1.5),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: leaf,
              foregroundColor: ink,
              elevation: 0,
              minimumSize: const Size(48, 46),
              side: const BorderSide(color: ink, width: 1.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: ink,
              side: const BorderSide(color: ink),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
            contentPadding: const EdgeInsets.all(14),
          ),
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: ink,
          ),
          dividerColor: const Color(0xffd8dfd4),
        ),
        home: MainShell(runClock: runClock),
      ),
    ),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.runClock});
  final bool runClock;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int index = 0;
  bool fullGarden = false;
  Timer? clock;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.runClock) {
      clock = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) {
          unawaited(AppScope.of(context).advance(DateTime.now()));
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.runClock) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(AppScope.of(context).advance(DateTime.now()));
    }
  }

  @override
  void dispose() {
    clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: IndexedStack(
            index: index,
            children: [
              TickerMode(
                enabled: index == 0,
                child: HomePage(
                  fullGarden: fullGarden,
                  onFullGarden: (value) => setState(() => fullGarden = value),
                ),
              ),
              TickerMode(enabled: index == 1, child: const SocialPage()),
              TickerMode(enabled: index == 2, child: const MinePage()),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ink, width: 1.6)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                children: [
                  for (final (i, label, icon) in [
                    (0, context.l.garden, Icons.local_florist_outlined),
                    (1, context.l.social, Icons.people_outline),
                    (2, context.l.me, Icons.person_outline),
                  ])
                    Expanded(
                      child: Semantics(
                        selected: index == i,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Material(
                            color: index == i ? leaf : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(3),
                              side: BorderSide(
                                color: index == i ? ink : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: InkWell(
                              key: ValueKey('nav-$i'),
                              onTap: () => setState(() => index = i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      icon,
                                      size: 20,
                                      color: index == i ? ink : muted,
                                    ),
                                    const SizedBox(width: 7),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: index == i ? ink : muted,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
