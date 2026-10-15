import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/skeleton_list.dart';
import 'mock_notification.dart';

/// 模块六：反馈与通知 - IM 消息中心页（P5）。
///
/// 依据《业务功能分析》UC-16 及全流程通用沟通能力：
/// HR 与候选人/面试官的即时通讯，支持会话列表、聊天气泡与快捷回复。
/// 数据来源：本地 Mock 数据（mock_notification.dart），
/// TODO: P7阶段替换为真实接口（lib/api/message_api.dart 的
/// listImSessions / listImMessages / sendImMessage / listQuickReplies）。
class MessageCenterPage extends StatefulWidget {
  const MessageCenterPage({super.key});

  @override
  State<MessageCenterPage> createState() => _MessageCenterPageState();
}

class _MessageCenterPageState extends State<MessageCenterPage> {
  List<Map<String, dynamic>>? _sessions;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 模拟加载会话列表。
  /// TODO: P7阶段替换为真实接口（message_api.listImSessions）。
  Future<void> _load() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _sessions = List.of(mockImSessions);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(title: const Text('消息中心')),
        body: _loading
            ? const SkeletonList(rows: 5)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: _sessions?.length ?? 0,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final session = _sessions![index];
                    return _SessionTile(
                      session: session,
                      onOpen: () async {
                        // 进入会话页（模拟），返回后刷新未读数
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(session: session),
                          ),
                        );
                        _load();
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onOpen});

  final Map<String, dynamic> session;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final unread = session['unread'] as int;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  '${session['name']}'.substring(0, 1),
                  style: const TextStyle(
                    color: AppColors.interactive,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${session['name']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${session['role']}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${session['lastMessage']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${session['time']}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  if (unread > 0)
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 聊天页：聊天气泡 + 快捷回复 + 输入框（模拟发送与自动回复）。
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.session});

  final Map<String, dynamic> session;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<Map<String, dynamic>> _messages = List.of(mockImMessages);

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 模拟发送消息（含自动回复）。
  /// TODO: P7阶段替换为真实接口（message_api.sendImMessage）。
  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({
        'id': 900 + _messages.length,
        'from': 'me',
        'text': text,
        'time': '刚刚',
      });
      _input.clear();
    });
    _scrollToBottom();
    // 模拟对方自动回复
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _messages.add({
        'id': 901 + _messages.length,
        'from': 'them',
        'text': '收到，谢谢！我稍后确认（模拟自动回复）',
        'time': '刚刚',
      });
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.session['name']}（${widget.session['role']}）'),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (_, index) =>
                    _ChatBubble(message: _messages[index]),
              ),
            ),
            // 快捷回复（复用 /system/im/quick-replies 占位）
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: mockQuickReplies.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) => Material(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _send(mockQuickReplies[index]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        mockQuickReplies[index],
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.interactive,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 输入区
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: '输入消息…'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _send,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(52, 46),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Icon(Icons.send, size: 18),
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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final mine = message['from'] == 'me';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: mine ? AppColors.interactive : AppColors.canvas,
            borderRadius: BorderRadius.circular(8),
            border: mine ? null : Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                '${message['text']}',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: mine ? Colors.white : AppColors.body,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${message['time']}',
                style: TextStyle(
                  fontSize: 10,
                  color: mine
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
