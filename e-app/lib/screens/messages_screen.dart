import 'package:flutter/material.dart';

import '../features/enterprise/enterprise_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/page_states.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.repository});
  final EnterpriseRepository repository;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>>? _sessions;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final rows = await widget.repository.conversations();
      if (mounted) setState(() => _sessions = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(children: [Expanded(child: Text('消息中心', style: Theme.of(context).textTheme.titleLarge)), IconButton(onPressed: _load, tooltip: '刷新', icon: const Icon(Icons.refresh))]),
          ),
          Expanded(child: _body()),
        ],
      );

  Widget _body() {
    if (_sessions == null && _error == null) return const PageLoading();
    if (_error != null) return PageMessage(icon: Icons.cloud_off_outlined, title: '消息加载失败', message: _error!, onAction: _load);
    if (_sessions!.isEmpty) return PageMessage(icon: Icons.forum_outlined, title: '暂无会话', message: '候选人发起沟通后，会话会显示在这里', onAction: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: _sessions!.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final session = _sessions![index];
          final unread = int.tryParse('${session['unread'] ?? 0}') ?? 0;
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              leading: const CircleAvatar(backgroundColor: AppColors.primarySoft, child: Icon(Icons.person_outline, color: AppColors.interactive)),
              title: Text('${session['peerName'] ?? '候选人'}'),
              subtitle: Text('${session['lastMessage'] ?? '暂无消息'}', maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: unread > 0
                  ? Badge(label: Text(unread > 99 ? '99+' : '$unread'), child: const Icon(Icons.chevron_right))
                  : const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(repository: widget.repository, session: session)));
                _load();
              },
            ),
          );
        },
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.repository, required this.session});
  final EnterpriseRepository repository;
  final Map<String, dynamic> session;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  List<Map<String, dynamic>>? _messages;
  String? _error;
  bool _sending = false;
  Object get _id => widget.session['sessionId']!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.repository.messages(_id);
      await widget.repository.markConversationRead(_id);
      if (mounted) setState(() { _messages = rows; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.repository.sendMessage(sessionId: _id, content: text);
      _input.clear();
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('${widget.session['peerName'] ?? '候选人'}')),
        body: SafeArea(
          child: Column(children: [
            Expanded(child: _chatBody()),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(children: [
                Expanded(child: TextField(controller: _input, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: '输入消息'))),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _sending ? null : _send, tooltip: '发送', icon: const Icon(Icons.send)),
              ]),
            ),
          ]),
        ),
      );

  Widget _chatBody() {
    if (_messages == null && _error == null) return const PageLoading();
    if (_error != null) return PageMessage(icon: Icons.cloud_off_outlined, title: '消息加载失败', message: _error!, onAction: _load);
    if (_messages!.isEmpty) return const PageMessage(icon: Icons.chat_bubble_outline, title: '开始沟通', message: '发送第一条消息');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _messages!.length,
      itemBuilder: (_, index) {
        final message = _messages![index];
        final mine = message['isMine'] == true;
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: mine ? AppColors.interactive : Colors.white, borderRadius: BorderRadius.circular(8), border: mine ? null : Border.all(color: AppColors.hairline)),
            child: Text('${message['content'] ?? ''}', style: TextStyle(color: mine ? Colors.white : AppColors.body)),
          ),
        );
      },
    );
  }
}
