import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'ai_api.dart';
import '../plants/plant_api.dart';

/// 会话列表，支持新建、恢复、分页和删除。
class AiConversationsPage extends StatefulWidget {
  const AiConversationsPage({
    super.key,
    required this.api,
    required this.plantApi,
    this.plantId,
  });
  final AiApi api;
  final PlantApi plantApi;
  final int? plantId;
  @override
  State<AiConversationsPage> createState() => _AiConversationsPageState();
}

class _AiConversationsPageState extends State<AiConversationsPage> {
  final _items = <AiConversation>[];
  bool _loading = false;
  bool _more = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.api.list(offset: reset ? 0 : _items.length);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(items);
        _more = items.length == 20;
      });
    } on AiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(AiConversation conversation) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AiChatPage(
          api: widget.api,
          plantApi: widget.plantApi,
          conversation: conversation,
        ),
      ),
    );
    if (mounted) await _load(reset: true);
  }

  Future<void> _create() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    AiConversation? conversation;
    try {
      conversation = await widget.api.create(plantId: widget.plantId);
    } on AiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (conversation != null && mounted) await _open(conversation);
  }

  Future<void> _delete(AiConversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除会话'),
        content: const Text('确定删除该会话及其全部消息？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm-delete-conversation'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.api.delete(conversation.id);
      if (mounted) await _load(reset: true);
    } on AiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('对话'),
      actions: [
        IconButton(
          key: const Key('refresh-conversations'),
          tooltip: '刷新会话',
          onPressed: _loading ? null : () => _load(reset: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('new-conversation'),
      heroTag: 'new-conversation',
      onPressed: _loading ? null : _create,
      icon: const Icon(Icons.add),
      label: const Text('新建会话'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (_error != null) Text(_error!, key: const Key('ai-error')),
        if (!_loading && _items.isEmpty && _error == null)
          const Text('还没有会话，点击“新建会话”开始提问'),
        for (final item in _items)
          Card(
            child: ListTile(
              key: Key('conversation-${item.id}'),
              title: Text(item.title),
              subtitle: Text(item.plantId == null ? '养护问答' : '植物养护问答'),
              onTap: () => _open(item),
              trailing: IconButton(
                tooltip: '删除会话',
                onPressed: _loading ? null : () => _delete(item),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_more && !_loading && _items.isNotEmpty)
          TextButton(onPressed: _load, child: const Text('加载更多会话')),
      ],
    ),
  );
}

/// 从数据库恢复历史，逐步显示本轮生成文本，支持主动取消。
class AiChatPage extends StatefulWidget {
  const AiChatPage({
    super.key,
    required this.api,
    required this.plantApi,
    required this.conversation,
  });
  final AiApi api;
  final PlantApi plantApi;
  final AiConversation conversation;
  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  late AiConversation _conversation;
  bool _choosingPlant = false;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <AiMessage>[];
  bool _loading = false;
  bool _sending = false;
  bool _cancelling = false;
  bool _cancelled = false;
  bool _more = false;
  String? _error;
  String? _turnId;
  String? _requestId;
  String? _requestContent;
  String? _question;
  String _reply = '';
  AiCall? _call;
  Timer? _poll;
  bool get _active => _messages.any((message) => message.active);
  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _call?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool older = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
    });
    try {
      final conversation = older
          ? _conversation
          : await widget.api.get(widget.conversation.id);
      final items = await widget.api.messages(
        widget.conversation.id,
        before: older && _messages.isNotEmpty ? _messages.first.sequence : null,
      );
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        if (older) {
          _messages.insertAll(0, items);
        } else {
          _messages
            ..clear()
            ..addAll(items);
        }
        _more = items.length >= 40;
        if (!_sending) {
          _turnId = null;
          for (final message in _messages) {
            if (message.active) _turnId = message.turnId;
          }
        }
      });
      _poll?.cancel();
      if (_active && !_sending) {
        _poll = Timer(const Duration(seconds: 1), () => _load());
      }
      if (!older) _bottom();
    } on AiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  });

  Future<void> _send() async {
    if (_sending || _active || _loading || _choosingPlant) return;
    final content = _input.text.trim();
    if (content.isEmpty || content.runes.length > 4000) {
      setState(() => _error = '请填写 1 到 4000 字的问题');
      return;
    }
    if (_requestContent != content || _requestId == null) {
      _requestId = newAiRequestId();
      _requestContent = content;
    }
    _poll?.cancel();
    setState(() {
      _sending = true;
      _cancelled = false;
      _error = null;
      _question = content;
      _reply = '';
      _turnId = null;
    });
    final call = widget.api.send(widget.conversation.id, _requestId!, content);
    _call = call;
    try {
      await for (final event in call.events) {
        if (!mounted) return;
        setState(() {
          if (event.name == 'accepted') {
            _turnId = event.data['turnId'] as String;
          }
          if (event.name == 'delta') _reply += event.data['text'] as String;
          if (event.name == 'done') {
            _reply = event.data['content'] as String;
            _input.clear();
            _requestId = null;
          }
          if (event.name == 'error') {
            _error = event.data['detail'] as String;
            _requestId = null;
          }
          if (event.name == 'snapshot') {
            _requestId = null;
            final status = event.data['status'];
            if (status == 'COMPLETED' ||
                status == 'STREAMING' ||
                status == 'ACCEPTED') {
              _input.clear();
            }
          }
        });
        _bottom();
      }
    } on AiException catch (error) {
      if (mounted && !_cancelling && !_cancelled) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _question = null;
          _call = null;
        });
        await _load();
      }
    }
  }

  Future<void> _choosePlant() async {
    if (_sending || _active || _loading || _choosingPlant) return;
    setState(() {
      _choosingPlant = true;
      _error = null;
    });
    try {
      final choice = await showDialog<({int? plantId})>(
        context: context,
        builder: (_) => _PlantSelectionDialog(
          api: widget.plantApi,
          selectedId: _conversation.plantId,
        ),
      );
      if (choice == null || !mounted) return;
      if (choice.plantId == _conversation.plantId &&
          (choice.plantId != null || _conversation.scope == 'GENERAL')) {
        return;
      }
      final saved = await widget.api.selectPlant(
        _conversation.id,
        choice.plantId,
      );
      if (!mounted) return;
      setState(() {
        _conversation = saved;
        _requestId = null;
        _requestContent = null;
      });
    } on AiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _choosingPlant = false);
    }
  }

  String get _plantLabel => _conversation.plantId != null
      ? '当前植物：${_conversation.plantName}'
      : _conversation.scope == 'PLANT'
      ? '指定植物已删除，请重新选择'
      : '通用问答';

  Future<void> _cancel() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    try {
      final turnId = _turnId;
      if (turnId != null) {
        await widget.api.cancel(widget.conversation.id, turnId);
      }
      _cancelled = true;
      _call?.cancel();
      _requestId = null;
      if (!_sending) await _load();
    } on AiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  String _status(String value) => switch (value) {
    'ACCEPTED' || 'STREAMING' => '正在生成',
    'FAILED' => '生成失败',
    'CANCELLED' => '已取消',
    'INTERRUPTED' => '生成中断',
    'COMPLETED' => '已完成',
    _ => throw StateError('未知问答状态'),
  };

  Widget _bubble(String role, String content, {String? status}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          role == 'USER' ? '我' : '养护助手',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        SelectableText(content),
        if (status != null && status != 'COMPLETED') Text(_status(status)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_conversation.title),
      actions: [
        IconButton(
          key: const Key('refresh-ai-messages'),
          tooltip: '刷新消息',
          onPressed: _sending || _loading || _choosingPlant
              ? null
              : () {
                  setState(() => _error = null);
                  _load();
                },
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_more)
                      TextButton(
                        onPressed: _loading ? null : () => _load(older: true),
                        child: const Text('加载更早消息'),
                      ),
                    if (_loading)
                      const Center(child: CircularProgressIndicator()),
                    for (final message in _messages)
                      _bubble(
                        message.role,
                        message.content,
                        status: message.role == 'ASSISTANT'
                            ? message.status
                            : null,
                      ),
                    if (_question != null) ...[
                      _bubble('USER', _question!),
                      _bubble('ASSISTANT', _reply, status: 'STREAMING'),
                    ],
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(_error!, key: const Key('ai-error')),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _plantLabel,
                    key: const Key('selected-ai-plant'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: IconButton(
                        key: const Key('select-ai-plant'),
                        tooltip: '指定植物',
                        onPressed:
                            _sending || _active || _loading || _choosingPlant
                            ? null
                            : _choosePlant,
                        icon: Icon(
                          _conversation.plantId == null
                              ? Icons.local_florist_outlined
                              : Icons.local_florist,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const Key('ai-question'),
                        controller: _input,
                        enabled: !_sending && !_active,
                        maxLength: 4000,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: '向养护助手提问'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_sending || _active)
                      TextButton(
                        key: const Key('cancel-ai-reply'),
                        onPressed: _cancelling ? null : _cancel,
                        child: const Text('停止生成'),
                      )
                    else
                      FilledButton(
                        key: const Key('send-ai-question'),
                        onPressed: _loading || _choosingPlant ? null : _send,
                        child: const Text('发送'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 每次打开时读取当前账号的最新植物列表。
class _PlantSelectionDialog extends StatefulWidget {
  const _PlantSelectionDialog({required this.api, required this.selectedId});
  final PlantApi api;
  final int? selectedId;

  @override
  State<_PlantSelectionDialog> createState() => _PlantSelectionDialogState();
}

class _PlantSelectionDialogState extends State<_PlantSelectionDialog> {
  late Future<List<PlantProfile>> _plants;

  @override
  void initState() {
    super.initState();
    _plants = widget.api.list();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('指定植物'),
    content: SizedBox(
      width: 360,
      height: 360,
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
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(error.message),
                TextButton(
                  onPressed: () {
                    final plants = widget.api.list();
                    setState(() {
                      _plants = plants;
                    });
                  },
                  child: const Text('重新加载植物'),
                ),
              ],
            );
          }
          final plants = snapshot.data!;
          return ListView(
            children: [
              ListTile(
                key: const Key('ai-plant-general'),
                title: const Text('通用问答'),
                subtitle: const Text('清除指定植物'),
                selected: widget.selectedId == null,
                trailing: widget.selectedId == null
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, (plantId: null)),
              ),
              if (plants.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('还没有植物，请先在植物页面创建档案'),
                ),
              for (final plant in plants)
                ListTile(
                  key: Key('ai-plant-${plant.id}'),
                  title: Text(plant.nickname!),
                  subtitle: Text(plant.species),
                  selected: plant.id == widget.selectedId,
                  trailing: plant.id == widget.selectedId
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(context, (plantId: plant.id)),
                ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
    ],
  );
}
