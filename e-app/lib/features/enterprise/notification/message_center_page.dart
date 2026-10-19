import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/skeleton_list.dart';
import 'data/message_data_source.dart';
import 'models/message_view_data.dart';
import 'system_notifications_page.dart';
import 'conversation_page.dart';
import 'widgets/message_avatar.dart';

// 保留旧聊天页导入入口，运行时仅使用真实接口。
export 'conversation_page.dart' show ChatPage;

class MessageCenterPage extends StatefulWidget {
  const MessageCenterPage({super.key, this.source = const MessageDataSource()});
  final MessageDataSource source;
  @override
  State<MessageCenterPage> createState() => _MessageCenterPageState();
}

class _MessageCenterPageState extends State<MessageCenterPage> {
  List<MessageSession> _sessions = [];
  NotificationSlice? _notifications;
  bool _loading = true, _action = false;
  int _tab = 0, _request = 0;
  String? _sessionsError, _notificationsError;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_action) return;
    final request = ++_request;
    setState(() => _loading = true);
    await Future.wait([
      () async {
        try {
          final rows = await widget.source.loadSessions();
          if (mounted && request == _request) {
            setState(() {
              _sessions = rows;
              _sessionsError = null;
            });
          }
        } catch (error) {
          if (mounted && request == _request) {
            setState(() => _sessionsError = messageError(error));
          }
        }
      }(),
      () async {
        try {
          final rows = await widget.source.loadNotifications();
          if (mounted && request == _request) {
            setState(() {
              _notifications = rows;
              _notificationsError = null;
            });
          }
        } catch (error) {
          if (mounted && request == _request) {
            setState(() => _notificationsError = messageError(error));
          }
        }
      }(),
    ]);
    if (mounted && request == _request) setState(() => _loading = false);
  }

  Future<void> _readAll() async {
    if (_action ||
        _loading ||
        _sessionsError != null ||
        _notificationsError != null) {
      return;
    }
    setState(() => _action = true);
    String? failure;
    try {
      await widget.source.readAllSessions();
      await widget.source.readAllNotifications();
    } catch (error) {
      failure = messageError(error);
    }
    if (!mounted) return;
    setState(() => _action = false);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure ?? '消息已全部标为已读')));
    }
  }

  Future<void> _openSession(MessageSession item) async {
    if (_action) return;
    setState(() => _action = true);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChatPage(session: item.raw, source: widget.source),
        ),
      );
    } finally {
      if (mounted) setState(() => _action = false);
    }
    if (mounted) await _load();
  }

  Future<void> _openSystem() async {
    if (_action) return;
    setState(() => _action = true);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SystemNotificationsPage(source: widget.source),
        ),
      );
    } finally {
      if (mounted) setState(() => _action = false);
    }
    if (mounted) await _load();
  }

  int get _unread =>
      _sessions.fold(0, (sum, item) => sum + item.unread) +
      (_notifications?.unreadCount ?? 0);
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.canvas,
      title: const Text('消息中心'),
      actions: [
        TextButton.icon(
          key: const Key('messages-read-all'),
          onPressed:
              _action ||
                  _loading ||
                  _unread == 0 ||
                  _sessionsError != null ||
                  _notificationsError != null
              ? null
              : _readAll,
          icon: const Icon(Icons.done_all, size: 16),
          label: const Text('全部已读', style: TextStyle(fontSize: 12)),
        ),
      ],
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: AppColors.canvas,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '候选人沟通与系统通知统一管理',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    for (final (index, label) in ['全部', 'AI Agent'].indexed)
                      Expanded(
                        child: TextButton(
                          key: ValueKey('messages-tab-$index'),
                          style: TextButton.styleFrom(
                            backgroundColor: _tab == index
                                ? AppColors.interactive
                                : AppColors.background,
                            foregroundColor: _tab == index
                                ? AppColors.canvas
                                : AppColors.textMuted,
                            minimumSize: const Size(0, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          onPressed: () => setState(() => _tab = index),
                          child: Text(
                            label,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _tab == 1 ? _agentEmpty() : _list()),
      ],
    ),
  );
  Widget _agentEmpty() => const Center(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.smart_toy_outlined,
            color: AppColors.accentPurple,
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            'AI Agent',
            style: TextStyle(
              color: AppColors.brand,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '企业端 AI Agent 会话功能开发中',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    ),
  );
  Widget _list() {
    if (_loading) return const SkeletonList(rows: 5);
    final notifications = _notifications;
    final hasSystem = notifications != null && notifications.items.isNotEmpty;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_sessionsError != null || _notificationsError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _sessionsError != null
                            ? '会话加载失败：$_sessionsError'
                            : '系统通知加载失败：$_notificationsError',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                      TextButton(onPressed: _load, child: const Text('重试加载消息')),
                    ],
                  ),
                ),
              ),
            ),
          if (_sessions.isEmpty &&
              !hasSystem &&
              _sessionsError == null &&
              _notificationsError == null)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Column(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.textMuted,
                    size: 44,
                  ),
                  SizedBox(height: 12),
                  Text(
                    '暂无消息',
                    style: TextStyle(color: AppColors.brand, fontSize: 17),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '新的会话和系统通知将在这里显示',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  if (hasSystem)
                    _row(
                      key: const Key('messages-system'),
                      name: '系统通知',
                      preview: notifications.items.first.title,
                      time: notifications.items.first.time,
                      unread: notifications.unreadCount,
                      system: true,
                      onTap: _openSystem,
                    ),
                  for (final (index, item) in _sessions.indexed) ...[
                    if (index > 0 || hasSystem)
                      const Divider(
                        height: 1,
                        indent: 76,
                        color: AppColors.hairline,
                      ),
                    _row(
                      key: ValueKey('message-session-${item.id}'),
                      name: item.name,
                      preview: item.preview,
                      time: item.time,
                      unread: item.unread,
                      avatar: widget.source.avatarUrl(item.avatar),
                      onTap: () => _openSession(item),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row({
    required Key key,
    required String name,
    required String preview,
    required DateTime? time,
    required int unread,
    required VoidCallback onTap,
    bool system = false,
    String? avatar,
  }) => InkWell(
    key: key,
    onTap: _action ? null : onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          MessageAvatar(name: name, url: avatar, system: system),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.brand,
                    fontSize: 15,
                    fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                messageDate(time),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 10),
              MessageUnreadBadge(count: unread),
            ],
          ),
        ],
      ),
    ),
  );
}
