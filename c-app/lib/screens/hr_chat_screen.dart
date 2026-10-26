import 'dart:async';

import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../features/auth/domain/auth_session.dart';
import '../features/messages/data/message_api.dart';
import '../features/messages/domain/app_message.dart';
import '../features/messages/presentation/reschedule_message_card.dart';
import '../theme/app_theme.dart';

class HrChatScreen extends StatefulWidget {
  const HrChatScreen({
    super.key,
    required this.session,
    required this.conversation,
  });

  final AuthSession session;
  final AppMessage conversation;

  @override
  State<HrChatScreen> createState() => _HrChatScreenState();
}

class _HrChatScreenState extends State<HrChatScreen>
    with WidgetsBindingObserver {
  late final ApiClient _client;
  late final MessageApi _api;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage>? _messages;
  String? _error;
  bool _sending = false, _loadingMessages = false, _active = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _api = MessageApi(_client);
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_active && !_sending) _load(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active && !_sending) _load(silent: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _scrollController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _load({bool scrollToEnd = false, bool silent = false}) async {
    if (_loadingMessages) return;
    _loadingMessages = true;
    if (!silent) setState(() => _error = null);
    try {
      final messages = await _api.fetchHrChat(
        widget.session.token,
        widget.conversation.sourceId,
      );
      if (!mounted) return;
      setState(() {
        _messages = messages.reversed.toList();
        _error = null;
      });
      if (scrollToEnd) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } on ApiException catch (error) {
      if (mounted && (!silent || _messages == null)) {
        setState(() => _error = error.message);
      }
    } finally {
      _loadingMessages = false;
    }
  }

  Future<void> _send() async {
    final content = _textController.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _api.sendHrChat(
        widget.session.token,
        widget.conversation.sourceId,
        content,
      );
      _textController.clear();
      await _load(scrollToEnd: true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: '刷新聊天',
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.conversation.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const Text(
              '招聘沟通',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _ChatComposer(
            controller: _textController,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.muted,
              size: 42,
            ),
            const SizedBox(height: 10),
            Text(_error!, style: Theme.of(context).textTheme.bodySmall),
            TextButton(onPressed: _load, child: const Text('重新加载')),
          ],
        ),
      );
    }
    final messages = _messages;
    if (messages == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (messages.isEmpty) {
      return const Center(
        child: Text('还没有消息，发一句问候吧', style: TextStyle(color: AppColors.muted)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
        itemCount: messages.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _ChatBubble(message: messages[index]),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: message.mine
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!message.mine) ...[
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primarySoft,
            child: Icon(
              Icons.person_outline,
              color: AppColors.interactive,
              size: 20,
            ),
          ),
          const SizedBox(width: 9),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: message.mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: message.mine
                      ? AppColors.interactive
                      : AppColors.canvas,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: Radius.circular(message.mine ? 12 : 3),
                    bottomRight: Radius.circular(message.mine ? 3 : 12),
                  ),
                  border: message.mine
                      ? null
                      : Border.all(color: AppColors.hairline),
                ),
                child: message.reschedule == null
                    ? Text(
                        message.content,
                        style: TextStyle(
                          color: message.mine ? Colors.white : AppColors.body,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      )
                    : RescheduleMessageCard(
                        data: message.reschedule!,
                        mine: message.mine,
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatChatTime(message.createdAt),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
        if (message.mine) ...[
          const SizedBox(width: 9),
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.brand,
            child: Icon(Icons.person, color: Colors.white, size: 19),
          ),
        ],
      ],
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: AppColors.canvas,
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: '输入消息…',
                  counterText: '',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 46,
              height: 46,
              child: FilledButton(
                onPressed: sending ? null : onSend,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                child: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatChatTime(DateTime date) {
  final now = DateTime.now();
  final sameDay =
      now.year == date.year && now.month == date.month && now.day == date.day;
  final time =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  return sameDay ? time : '${date.month}月${date.day}日 $time';
}
