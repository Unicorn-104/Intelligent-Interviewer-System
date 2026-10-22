import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../features/auth/domain/auth_session.dart';
import '../features/ai/presentation/ai_chat_screen.dart';
import '../features/messages/data/message_api.dart';
import '../features/messages/domain/app_message.dart';
import '../theme/app_theme.dart';
import '../widgets/draggable_ai_assistant.dart';
import 'hr_chat_screen.dart';
import 'message_detail_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    required this.session,
    required this.onUnreadChanged,
    this.refreshVersion = 0,
    this.messageApi,
  });

  final AuthSession session;
  final ValueChanged<int> onUnreadChanged;
  final int refreshVersion;
  final MessageApi? messageApi;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with WidgetsBindingObserver {
  late final ApiClient _client;
  late final MessageApi _api;
  List<AppMessage>? _messages;
  String? _error;
  bool _openingAssistant = false;
  bool _markingAllRead = false;
  bool _loading = false, _openingMessage = false;
  int _mutationEpoch = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _api = widget.messageApi ?? MessageApi(_client);
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
    _load();
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _load(silent: true),
    );
  }

  @override
  void didUpdateWidget(covariant MessagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _load(silent: true);
    } else {
      _refreshTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _client.close();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_loading || _markingAllRead || _openingMessage) return;
    _loading = true;
    final epoch = _mutationEpoch;
    if (!silent) setState(() => _error = null);
    try {
      final messages = await _api.fetchMessages(widget.session.token);
      if (!mounted || epoch != _mutationEpoch) return;
      setState(() {
        _messages = messages;
        _error = null;
      });
      _notifyUnread(messages);
    } on ApiException catch (error) {
      if (mounted &&
          epoch == _mutationEpoch &&
          (!silent || _messages == null)) {
        setState(() => _error = error.message);
      }
    } finally {
      _loading = false;
    }
  }

  void _notifyUnread(List<AppMessage> messages) {
    widget.onUnreadChanged(
      messages.fold(0, (total, message) => total + message.unreadCount),
    );
  }

  Future<void> _markAllRead() async {
    final messages = _messages;
    if (messages == null || _markingAllRead || _openingMessage) return;
    _mutationEpoch++;
    setState(() => _markingAllRead = true);
    try {
      await _api.markAllRead(widget.session.token);
      if (!mounted) return;
      final updated = messages
          .map((message) => message.copyWith(unreadCount: 0))
          .toList();
      setState(() => _messages = updated);
      _notifyUnread(updated);
      _showSnackBar(
        messages.any((message) => message.unreadCount > 0)
            ? '已将全部消息标记为已读'
            : '当前没有未读消息',
      );
    } on ApiException catch (error) {
      if (mounted) _showSnackBar(error.message);
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
    }
  }

  Future<void> _openMessage(AppMessage message) async {
    if (_openingMessage || _markingAllRead) return;
    _openingMessage = true;
    _mutationEpoch++;
    try {
      await _openMessageDetails(message);
    } finally {
      _openingMessage = false;
      if (mounted) await _load();
    }
  }

  Future<void> _openMessageDetails(AppMessage message) async {
    if (message.unreadCount > 0) {
      try {
        await _api.markRead(widget.session.token, message);
        if (!mounted) return;
        final updated = _messages!
            .map(
              (item) =>
                  item.category == message.category &&
                      item.sourceId == message.sourceId
                  ? item.copyWith(unreadCount: 0)
                  : item,
            )
            .toList();
        setState(() => _messages = updated);
        _notifyUnread(updated);
      } on ApiException catch (error) {
        if (mounted) _showSnackBar(error.message);
        return;
      }
    }
    if (!mounted) return;
    if (message.category == AppMessageCategory.hr) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              HrChatScreen(session: widget.session, conversation: message),
        ),
      );
      if (mounted) await _load();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MessageDetailScreen(message: message, session: widget.session),
      ),
    );
    if (mounted) await _load();
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openAssistant() async {
    if (_openingAssistant) return;
    _openingAssistant = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: AppColors.ink.withValues(alpha: 0.3),
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.97,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: AiChatScreen(
              session: widget.session,
              overlay: true,
              restoreLastConversation: true,
            ),
          ),
        ),
      );
    } finally {
      _openingAssistant = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DraggableAiAssistant(
        onPressed: _openAssistant,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: AppColors.canvas,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '消息中心',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'HR、系统通知与企业动态统一管理',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _markingAllRead ? null : _markAllRead,
                        icon: _markingAllRead
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.done, size: 17),
                        label: const Text('全部已读'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildMessageContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent() {
    if (_error != null) {
      return _MessageState(
        icon: Icons.wifi_off_rounded,
        title: '消息加载失败',
        message: _error!,
        action: '重新加载',
        onAction: _load,
      );
    }
    final messages = _messages;
    if (messages == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (messages.isEmpty) {
      return _MessageState(
        icon: Icons.chat_bubble_outline,
        title: '暂无消息',
        message: 'HR 沟通、系统通知和关注企业动态会显示在这里。',
        action: '刷新',
        onAction: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              children: [
                for (var index = 0; index < messages.length; index++)
                  _MessageRow(
                    item: messages[index],
                    showDivider: index < messages.length - 1,
                    onTap: () => _openMessage(messages[index]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.item,
    required this.showDivider,
    required this.onTap,
  });

  final AppMessage item;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(item.category);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 78),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: AppColors.hairline))
              : null,
        ),
        child: Row(
          children: [
            _MessageAvatar(item: item, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.body,
                            fontSize: 14,
                            fontWeight: item.unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (item.badge != null) ...[
                        const SizedBox(width: 6),
                        _MessageBadge(label: item.badge!, color: color),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatListTime(item.occurredAt),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  if (item.unreadCount > 0)
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 19,
                        minHeight: 19,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.red,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Text(
                        '${item.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.hairline,
                        shape: BoxShape.circle,
                      ),
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

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({required this.item, required this.color});

  final AppMessage item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = item.avatarUrl;
    return Container(
      width: 44,
      height: 44,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: avatarUrl == null
          ? Icon(_categoryIcon(item.category), color: color, size: 22)
          : Image.network(
              _resolveUrl(avatarUrl),
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(_categoryIcon(item.category), color: color, size: 22),
            ),
    );
  }
}

class _MessageBadge extends StatelessWidget {
  const _MessageBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (action != null) ...[
              const SizedBox(height: 10),
              TextButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

Color _categoryColor(AppMessageCategory category) {
  return switch (category) {
    AppMessageCategory.hr => AppColors.interactive,
    AppMessageCategory.system => AppColors.purple,
    AppMessageCategory.company => AppColors.green,
  };
}

IconData _categoryIcon(AppMessageCategory category) {
  return switch (category) {
    AppMessageCategory.hr => Icons.person_outline,
    AppMessageCategory.system => Icons.notifications_none,
    AppMessageCategory.company => Icons.business_outlined,
  };
}

String _resolveUrl(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  return '${AppConfig.apiBaseUrl}${path.startsWith('/') ? path : '/$path'}';
}

String _formatListTime(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final messageDay = DateTime(date.year, date.month, date.day);
  final difference = today.difference(messageDay).inDays;
  if (difference == 0) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
  if (difference == 1) return '昨天';
  if (difference > 1 && difference < 7) {
    return const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][date.weekday - 1];
  }
  return '${date.month}月${date.day}日';
}
