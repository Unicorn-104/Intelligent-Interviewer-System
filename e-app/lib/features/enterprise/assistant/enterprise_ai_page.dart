import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_theme.dart';
import 'enterprise_ai_controller.dart';
import 'enterprise_ai_data_source.dart';
import 'enterprise_ai_markdown.dart';

class EnterpriseAiPage extends StatefulWidget {
  const EnterpriseAiPage({super.key, this.source});
  final EnterpriseAiDataSource? source;
  @override
  State<EnterpriseAiPage> createState() => _EnterpriseAiPageState();
}

class _EnterpriseAiPageState extends State<EnterpriseAiPage>
    with WidgetsBindingObserver {
  late final _chat = EnterpriseAiController(
    widget.source ?? EnterpriseAiDataSource(),
  );
  final _input = TextEditingController(), _scroll = ScrollController();
  bool _nearBottom = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(() {
      if (_scroll.hasClients) {
        _nearBottom = _scroll.position.maxScrollExtent - _scroll.offset < 100;
      }
    });
    _chat.addListener(_changed);
    _chat.initialize();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (_nearBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _chat.pause(state != AppLifecycleState.resumed);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chat.removeListener(_changed);
    _chat.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    _nearBottom = true;
    final accepted = await _chat.send(text);
    if (mounted && accepted && _input.text == text) _input.clear();
  }

  void _newConversation() {
    if (!_chat.busy) {
      _chat.newConversation();
      _input.clear();
      _nearBottom = true;
    }
  }

  Future<void> _history() async {
    if (_chat.busy) return;
    FocusScope.of(context).unfocus();
    final selected = await showModalBottomSheet<EnterpriseAiSession>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .84,
        child: _AiHistory(source: _chat.source, currentId: _chat.session?.id),
      ),
    );
    if (!mounted || selected == null) return;
    _input.clear();
    _nearBottom = true;
    if (selected.id == 0) {
      _newConversation();
    } else {
      await _chat.open(selected);
    }
  }

  Future<void> _verify() async {
    final pending = _chat.pendingText;
    await _chat.verify();
    if (mounted &&
        !_chat.uncertain &&
        _chat.activeRun != null &&
        _input.text.trim() == pending) {
      _input.clear();
    }
  }

  Future<void> _resumeEditing() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认请求状态'),
        content: const Text('请先核对历史记录，确认没有重复问题。恢复只解除输入限制，不会自动发送；再次发送需要你手动操作。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('已核对'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) _chat.resumeEditing();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F8FF),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF5F8FF),
      leading: IconButton(
        key: const Key('enterprise-ai-close'),
        tooltip: '关闭 AI 助手',
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'AI 招聘助手',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
          key: const Key('enterprise-ai-new'),
          tooltip: '开启新对话',
          onPressed: _chat.busy || _chat.loading ? null : _newConversation,
          icon: const Icon(Icons.add_comment_outlined),
        ),
        IconButton(
          key: const Key('enterprise-ai-history'),
          tooltip: '查看历史对话',
          onPressed: _chat.busy || _chat.loading ? null : _history,
          icon: const Icon(Icons.history),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          if (_chat.session != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _chat.session!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ),
          if (_chat.error != null)
            Container(
              key: const Key('enterprise-ai-error'),
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _chat.error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.bodySoft,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (_chat.uncertain) ...[
                        TextButton(
                          key: const Key('enterprise-ai-verify'),
                          onPressed: _chat.sending ? null : _verify,
                          child: const Text('核对请求'),
                        ),
                        TextButton(
                          onPressed: _chat.sending ? null : _resumeEditing,
                          child: const Text('人工确认后恢复编辑'),
                        ),
                      ] else if (_chat.activeRun?.running == true)
                        TextButton(
                          onPressed: _chat.refreshRun,
                          child: const Text('刷新回答'),
                        )
                      else
                        TextButton(
                          onPressed: _chat.session == null
                              ? _chat.initialize
                              : () => _chat.open(_chat.session!),
                          child: const Text('重新加载'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: _chat.loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    children: [
                      if (_chat.before != null)
                        Center(
                          child: TextButton(
                            key: const Key('enterprise-ai-older'),
                            onPressed: _chat.loadingOlder
                                ? null
                                : _chat.loadOlder,
                            child: Text(_chat.loadingOlder ? '加载中…' : '查看更早消息'),
                          ),
                        ),
                      if (_chat.messages.isEmpty) _welcome(),
                      for (final message in _chat.messages) _bubble(message),
                      if (_chat.sending)
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            '正在提交…',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                    ],
                  ),
          ),
          if (_chat.activeRun?.running == true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _chat.activeRun!.progress,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('enterprise-ai-stop'),
                    onPressed: _chat.sending ? null : _chat.stop,
                    child: const Text('停止回答'),
                  ),
                ],
              ),
            ),
          _composer(),
        ],
      ),
    ),
  );
  Widget _welcome() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD4EBFF), Color(0xFF9CD1FF)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.smart_toy_outlined,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          '你好，我是你的 AI 招聘助手',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.brand,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '从招聘计划到沟通灵感，随时和我聊聊。',
          style: TextStyle(color: AppColors.bodySoft),
        ),
        const SizedBox(height: 20),
        for (final prompt in [
          '帮我优化一份岗位JD',
          '为Java后端岗位设计面试题',
          '查看本企业的在招岗位',
          '帮我写一段友好的沟通开场白',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                _input.text = prompt;
                _input.selection = TextSelection.collapsed(
                  offset: prompt.length,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(prompt),
              ),
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          '仅提供建议与草稿；不会自动联系候选人或修改招聘数据。',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ),
  );
  Widget _bubble(EnterpriseAiMessage message) {
    final user = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: user
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            user ? '你' : 'AI 助手',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 5),
          Container(
            key: ValueKey('enterprise-ai-message-${message.id}'),
            constraints: const BoxConstraints(maxWidth: 760),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: user ? const Color(0xFFE7F1FF) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: user
                ? SelectableText(message.content)
                : message.content.isEmpty
                ? Text(
                    message.state == 'R'
                        ? '正在组织回答…'
                        : message.state == 'X'
                        ? '已停止回答'
                        : '本次未生成回答',
                    style: const TextStyle(color: AppColors.muted),
                  )
                : EnterpriseAiMarkdown(content: message.content),
          ),
          if (!user && message.content.isNotEmpty)
            Wrap(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: message.content),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('已复制回答')));
                    }
                  },
                  icon: const Icon(Icons.copy_outlined, size: 14),
                  label: const Text('复制', style: TextStyle(fontSize: 11)),
                ),
                if (message.state == 'F' || message.state == 'X')
                  Text(
                    message.state == 'X' ? '已停止' : '回答未完成',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _composer() => Container(
    color: const Color(0xFFF5F8FF),
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('enterprise-ai-input'),
                controller: _input,
                enabled: !_chat.busy && !_chat.loading,
                minLines: 1,
                maxLines: 5,
                maxLength: 4000,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: '输入问题，聊聊招聘…',
                  counterText: '',
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: AppColors.hairline),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const Key('enterprise-ai-send'),
              tooltip: '发送问题',
              onPressed: _chat.busy || _chat.loading ? null : _send,
              icon: const Icon(Icons.arrow_upward),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'AI 生成内容仅供参考，请核实后使用',
          style: TextStyle(fontSize: 10, color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _AiHistory extends StatefulWidget {
  const _AiHistory({required this.source, required this.currentId});
  final EnterpriseAiDataSource source;
  final int? currentId;
  @override
  State<_AiHistory> createState() => _AiHistoryState();
}

class _AiHistoryState extends State<_AiHistory> {
  final _items = <EnterpriseAiSession>[];
  bool _loading = true, _moreLoading = false;
  String? _error;
  int? _next;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_moreLoading || _next == null)) return;
    setState(() {
      if (more) {
        _moreLoading = true;
      } else {
        _loading = true;
      }
      _error = null;
    });
    try {
      final data = await widget.source.sessions(before: more ? _next : null);
      if (!mounted) return;
      setState(() {
        if (!more) _items.clear();
        final ids = _items.map((row) => row.id).toSet();
        _items.addAll(data.items.where((row) => !ids.contains(row.id)));
        _next = data.next;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = EnterpriseAiDataSource.errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _moreLoading = false;
        });
      }
    }
  }

  Future<void> _delete(EnterpriseAiSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除对话？'),
        content: const Text('删除后无法恢复。正在生成的对话请先停止。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.source.delete(session.id);
      if (mounted) {
        if (session.id == widget.currentId) {
          Navigator.pop(context, const EnterpriseAiSession(0, '新对话'));
        } else {
          setState(() => _items.removeWhere((row) => row.id == session.id));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = EnterpriseAiDataSource.errorMessage(e));
      }
    }
  }

  String _group(DateTime? date) {
    if (date == null) return '更早';
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    if (!date.isBefore(day)) return '今天';
    return date.isAfter(day.subtract(const Duration(days: 7))) ? '最近一周' : '更早';
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                '对话历史',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: '关闭历史',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: AppColors.red)),
                    TextButton(onPressed: _load, child: const Text('重试加载历史')),
                  ],
                  if (_items.isEmpty && _error == null)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('暂无历史对话'),
                    ),
                  for (var index = 0; index < _items.length; index++) ...[
                    if (index == 0 ||
                        _group(_items[index].updatedAt) !=
                            _group(_items[index - 1].updatedAt))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                        child: Text(
                          _group(_items[index].updatedAt),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    Card(
                      color: _items[index].id == widget.currentId
                          ? AppColors.primarySoft
                          : AppColors.background,
                      child: ListTile(
                        key: ValueKey(
                          'enterprise-ai-history-${_items[index].id}',
                        ),
                        title: Text(
                          _items[index].title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(context, _items[index]),
                        trailing: PopupMenuButton<String>(
                          tooltip: '对话操作',
                          onSelected: (_) => _delete(_items[index]),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'delete',
                              enabled: _items[index].activeRunId == null,
                              child: const Text('删除对话'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_next != null)
                    TextButton(
                      onPressed: _moreLoading ? null : () => _load(more: true),
                      child: Text(_moreLoading ? '加载中…' : '加载更多历史'),
                    ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('新对话'),
                    onTap: () => Navigator.pop(
                      context,
                      const EnterpriseAiSession(0, '新对话'),
                    ),
                  ),
                ],
              ),
      ),
    ],
  );
}
