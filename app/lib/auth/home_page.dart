import 'package:material_ui/material_ui.dart';

import '../plants/plant_api.dart';
import '../plants/plant_detail_page.dart';
import '../plants/plant_form_page.dart';
import 'auth_api.dart';
import '../ai/ai_api.dart';
import '../ai/ai_pages.dart';

/// 登录后的植物列表，提供新建、详情和退出入口。
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.username,
    required this.onLogout,
    required this.plantApi,
    this.aiApi,
  });

  final String username;
  final Future<void> Function() onLogout;
  final PlantApi plantApi;
  final AiApi? aiApi;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<PlantProfile>> _plants;
  var _loggingOut = false;
  String? _logoutError;

  @override
  void initState() {
    super.initState();
    _plants = widget.plantApi.list();
  }

  Future<void> _create() async {
    final saved = await Navigator.of(context).push<PlantProfile>(
      MaterialPageRoute(builder: (_) => PlantFormPage(api: widget.plantApi)),
    );
    if (saved != null && mounted) {
      setState(() {
        _plants = widget.plantApi.list();
      });
    }
  }

  Future<void> _open(PlantProfile plant) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PlantDetailPage(
          id: plant.id,
          api: widget.plantApi,
          aiApi: widget.aiApi,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _plants = widget.plantApi.list();
      });
    }
  }

  Future<void> _logout() async {
    setState(() {
      _loggingOut = true;
      _logoutError = null;
    });
    try {
      await widget.onLogout();
    } on AuthException catch (error) {
      if (mounted) setState(() => _logoutError = error.message);
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的植物'),
        actions: [
          IconButton(
            key: const Key('open-ai-assistant'),
            tooltip: '养护助手',
            onPressed: widget.aiApi == null
                ? null
                : () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => AiConversationsPage(api: widget.aiApi!),
                    ),
                  ),
            icon: const Icon(Icons.chat_outlined),
          ),
          IconButton(
            key: const Key('refresh-plants'),
            tooltip: '刷新植物',
            onPressed: () => setState(() {
              _plants = widget.plantApi.list();
            }),
            icon: const Icon(Icons.refresh),
          ),
          TextButton(
            key: const Key('logout'),
            onPressed: _loggingOut ? null : _logout,
            child: const Text('退出'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-plant'),
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('新建植物'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.username, key: const Key('current-user')),
          ),
          if (_logoutError != null) Text(_logoutError!),
          Expanded(
            child: FutureBuilder<List<PlantProfile>>(
              future: _plants,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  if (error is! PlantException) {
                    Error.throwWithStackTrace(error!, snapshot.stackTrace!);
                  }
                  return Center(child: Text(error.message));
                }
                final plants = snapshot.data!;
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  children: [
                    if (plants.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('还没有植物，点击“新建植物”建立档案'),
                      ),
                    for (final plant in plants)
                      Card(
                        child: ListTile(
                          key: Key('plant-${plant.id}'),
                          leading: const Icon(Icons.local_florist),
                          title: Text(plant.nickname!),
                          subtitle: Text(plant.species),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(plant),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
