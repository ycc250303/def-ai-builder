import 'package:material_ui/material_ui.dart';

import 'plant_api.dart';
import 'plant_form_page.dart';
import '../ai/ai_api.dart';
import '../ai/ai_pages.dart';

/// 植物主页，显示完整档案并提供编辑和删除。
class PlantDetailPage extends StatefulWidget {
  const PlantDetailPage({
    super.key,
    required this.id,
    required this.api,
    this.aiApi,
  });

  final int id;
  final PlantApi api;
  final AiApi? aiApi;

  @override
  State<PlantDetailPage> createState() => _PlantDetailPageState();
}

class _PlantDetailPageState extends State<PlantDetailPage> {
  late Future<PlantProfile> _plant;
  var _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _plant = widget.api.get(widget.id);
  }

  Future<void> _edit(PlantProfile plant) async {
    final saved = await Navigator.of(context).push<PlantProfile>(
      MaterialPageRoute(
        builder: (_) => PlantFormPage(api: widget.api, plant: plant),
      ),
    );
    if (saved != null && mounted) {
      setState(() {
        _plant = Future.value(saved);
        _error = null;
      });
    }
  }

  Future<void> _delete(PlantProfile plant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除植物档案'),
        content: Text('确定删除「${plant.nickname}」的植物档案？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm-delete-plant'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.api.delete(plant.id);
      if (mounted) Navigator.of(context).pop();
    } on PlantException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _field(String label, String? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text('$label：${value ?? '未填写'}'),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('植物主页')),
      body: FutureBuilder<PlantProfile>(
        future: _plant,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            if (error is! PlantException) {
              Error.throwWithStackTrace(error!, snapshot.stackTrace!);
            }
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error.message),
                  TextButton(
                    onPressed: () => setState(() {
                      _plant = widget.api.get(widget.id);
                    }),
                    child: const Text('重新加载'),
                  ),
                ],
              ),
            );
          }
          final plant = snapshot.data!;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(Icons.local_florist, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    plant.nickname!,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  _field('品种', plant.species),
                  _field('种植日期', plant.plantingDate),
                  _field('开始养护日期', plant.careStartDate),
                  _field('培养地', switch (plant.growingLocation) {
                    'INDOOR' => '室内',
                    'OUTDOOR' => '室外',
                    null => null,
                    _ => throw StateError('植物档案选项不合法'),
                  }),
                  _field('培养方式', switch (plant.cultivationMethod) {
                    'SOIL' => '土培',
                    'WATER' => '水培',
                    null => null,
                    _ => throw StateError('植物档案选项不合法'),
                  }),
                  _field('简要描述', plant.description),
                  if (_error != null)
                    Text(_error!, key: const Key('plant-error')),
                  const SizedBox(height: 24),
                  if (widget.aiApi != null)
                    FilledButton(
                      key: const Key('ask-plant-assistant'),
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => AiConversationsPage(
                            api: widget.aiApi!,
                            plantId: plant.id,
                          ),
                        ),
                      ),
                      child: const Text('询问养护助手'),
                    ),
                  FilledButton(
                    key: const Key('edit-plant'),
                    onPressed: _deleting ? null : () => _edit(plant),
                    child: const Text('编辑档案'),
                  ),
                  TextButton(
                    key: const Key('delete-plant'),
                    onPressed: _deleting ? null : () => _delete(plant),
                    child: Text(_deleting ? '正在删除' : '删除档案'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
