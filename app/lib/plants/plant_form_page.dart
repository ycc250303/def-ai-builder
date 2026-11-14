import 'package:material_ui/material_ui.dart';

import 'plant_api.dart';

/// 新建与编辑共用的植物档案表单。
class PlantFormPage extends StatefulWidget {
  const PlantFormPage({super.key, required this.api, this.plant});

  final PlantApi api;
  final PlantProfile? plant;

  @override
  State<PlantFormPage> createState() => _PlantFormPageState();
}

class _PlantFormPageState extends State<PlantFormPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _species;
  late final TextEditingController _nickname;
  late final TextEditingController _plantingDate;
  late final TextEditingController _careStartDate;
  late final TextEditingController _description;
  String? _growingLocation;
  String? _cultivationMethod;
  String? _error;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final plant = widget.plant;
    _species = TextEditingController(text: plant?.species);
    _nickname = TextEditingController(text: plant?.nickname);
    _plantingDate = TextEditingController(text: plant?.plantingDate);
    _careStartDate = TextEditingController(text: plant?.careStartDate);
    _description = TextEditingController(text: plant?.description);
    _growingLocation = plant?.growingLocation;
    _cultivationMethod = plant?.cultivationMethod;
  }

  @override
  void dispose() {
    for (final controller in [
      _species,
      _nickname,
      _plantingDate,
      _careStartDate,
      _description,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _optional(String text) => text.trim().isEmpty ? null : text.trim();

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final input = PlantInput(
      species: _species.text.trim(),
      nickname: _optional(_nickname.text),
      plantingDate: _optional(_plantingDate.text),
      careStartDate: _optional(_careStartDate.text),
      growingLocation: _growingLocation,
      cultivationMethod: _cultivationMethod,
      description: _optional(_description.text),
    );
    try {
      final existing = widget.plant;
      final saved = existing == null
          ? await widget.api.create(input)
          : await widget.api.update(existing.id, input);
      if (mounted) Navigator.of(context).pop(saved);
    } on PlantException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: controller.text.isEmpty
          ? DateTime.now()
          : DateTime.parse(controller.text),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (selected != null && mounted) {
      controller.text =
          '${selected.year.toString().padLeft(4, '0')}-'
          '${selected.month.toString().padLeft(2, '0')}-'
          '${selected.day.toString().padLeft(2, '0')}';
    }
  }

  Widget _dateField(
    String label,
    String key,
    TextEditingController controller,
  ) {
    return TextFormField(
      key: Key(key),
      controller: controller,
      readOnly: true,
      onTap: _saving ? null : () => _pickDate(controller),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          key: Key('clear-$key'),
          tooltip: '清空日期',
          onPressed: _saving ? null : controller.clear,
          icon: const Icon(Icons.clear),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.plant == null ? '新建植物档案' : '编辑植物档案')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('plant-species'),
                    controller: _species,
                    enabled: !_saving,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      label: Text.rich(
                        TextSpan(
                          text: '品种 ',
                          children: [
                            TextSpan(
                              text: '*',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                        semanticsLabel: '品种，必填',
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '请填写植物品种'
                        : null,
                  ),
                  TextFormField(
                    key: const Key('plant-nickname'),
                    controller: _nickname,
                    enabled: !_saving,
                    maxLength: 100,
                    decoration: const InputDecoration(labelText: '昵称'),
                  ),
                  _dateField('种植日期', 'planting-date', _plantingDate),
                  const SizedBox(height: 16),
                  _dateField('开始养护日期', 'care-start-date', _careStartDate),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const Key('growing-location'),
                    initialValue: _growingLocation ?? '',
                    decoration: const InputDecoration(labelText: '培养地'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('未填写')),
                      DropdownMenuItem(value: 'INDOOR', child: Text('室内')),
                      DropdownMenuItem(value: 'OUTDOOR', child: Text('室外')),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            _growingLocation = value == '' ? null : value;
                          },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const Key('cultivation-method'),
                    initialValue: _cultivationMethod ?? '',
                    decoration: const InputDecoration(labelText: '培养方式'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('未填写')),
                      DropdownMenuItem(value: 'SOIL', child: Text('土培')),
                      DropdownMenuItem(value: 'WATER', child: Text('水培')),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            _cultivationMethod = value == '' ? null : value;
                          },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('plant-description'),
                    controller: _description,
                    enabled: !_saving,
                    maxLength: 1000,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: '简要描述'),
                  ),
                  if (_error != null)
                    Text(_error!, key: const Key('plant-error')),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('save-plant'),
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? '正在保存' : '保存档案'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
