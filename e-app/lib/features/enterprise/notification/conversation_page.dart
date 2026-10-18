import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/skeleton_list.dart';
import 'data/message_data_source.dart';
import 'models/message_view_data.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.session,
    this.source = const MessageDataSource(),
    this.pollInterval = const Duration(seconds: 8),
  });
  final Map<String, dynamic> session;
  final MessageDataSource source;
  final Duration pollInterval;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final _input = TextEditingController(), _scroll = ScrollController();
  List<ConversationMessage> _messages = [];
  List<String> _quick = [];
  int? _id;
  bool _loading = true,
      _fetching = false,
      _sending = false,
      _uncertain = false,
      _active = true,
      _ready = false;
  String? _error, _quickError;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _id = messageId(widget.session['sessionId']);
    _load();
    _loadQuick();
    if (widget.pollInterval > Duration.zero) {
      _timer = Timer.periodic(widget.pollInterval, (_) {
        if (mounted && _active && !_sending && !_uncertain) _load(silent: true);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active && !_sending && !_uncertain) _load(silent: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadQuick() async {
    if (_id == null) return;
    try {
      final rows = await widget.source.loadQuickReplies();
      if (mounted) {
        setState(() {
          _quick = rows;
          _quickError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _quickError = '快捷回复暂不可用');
    }
  }

  void _bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  });
  Future<void> _load({bool silent = false}) async {
    if (_fetching || (_sending && silent)) return;
    if (_id == null) {
      setState(() {
        _loading = false;
        _error = '会话信息无效，请返回消息中心刷新';
      });
      return;
    }
    final follow =
        !_scroll.hasClients ||
        _scroll.position.maxScrollExtent - _scroll.offset < 100;
    setState(() => _fetching = true);
    try {
      final rows = await widget.source.loadMessages(_id!);
      if (!mounted) return;
      // 读取成功后才标记已读，失败不伪造空消息。
      await widget.source.readSession(_id!);
      if (!mounted) return;
      setState(() {
        _messages = rows;
        _error = _uncertain ? '请核对聊天记录后再继续编辑，避免重复发送' : null;
        _ready = true;
      });
      if (follow) _bottom();
    } catch (error) {
      if (mounted) setState(() => _error = messageError(error));
    } finally {
      _fetching = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (_sending ||
        _fetching ||
        _uncertain ||
        !_ready ||
        _id == null ||
        text.isEmpty) {
      return;
    }
    if (text.length > 1000) {
      setState(() => _error = '消息内容不能超过1000个字符');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.source.send(_id!, text);
      if (!mounted) return;
      _input.clear();
      await _load();
      _bottom();
    } catch (error) {
      if (!mounted) return;
      final known = error is ApiException && error.code != null;
      setState(() {
        _uncertain = !known;
        _error = known ? messageError(error) : '发送结果待核对，请刷新记录后确认，避免重复发送';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _fill(String text) {
    _input.text = text;
    _input.selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        messageText(
          widget.session['peerName'],
          messageText(widget.session['name'], '聊天'),
        ),
      ),
      actions: [
        IconButton(
          key: const Key('chat-refresh'),
          tooltip: '刷新聊天记录',
          onPressed: _fetching || _sending ? null : () => _load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              color: AppColors.warningSoft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                    ),
                  ),
                  if (_uncertain)
                    TextButton(
                      key: const Key('chat-verify-result'),
                      onPressed: _fetching || _sending
                          ? null
                          : () async {
                              await _load();
                              if (!mounted) return;
                              // 核对服务器记录后由用户明确恢复编辑，不自动重发。
                              if (_ready) {
                                setState(() => _error = '请核对上方记录，确认上一条消息是否已送达');
                              }
                            },
                      child: const Text('刷新并核对记录'),
                    ),
                  if (_uncertain)
                    TextButton(
                      key: const Key('chat-resume-edit'),
                      onPressed: () => setState(() {
                        _uncertain = false;
                        _error = null;
                      }),
                      child: const Text('已核对记录，继续编辑'),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const SkeletonList(rows: 4)
                : RefreshIndicator(
                    onRefresh: () => _load(),
                    child: ListView(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_messages.isEmpty && _ready)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Text(
                              '暂无聊天记录',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                        if (_messages.isEmpty && !_ready)
                          TextButton(
                            onPressed: () => _load(),
                            child: const Text('重试加载聊天记录'),
                          ),
                        for (final item in _messages) _bubble(item),
                      ],
                    ),
                  ),
          ),
          if (_quick.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _quick.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) => ActionChip(
                  label: Text(
                    _quick[index],
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: _sending || _uncertain
                      ? null
                      : () => setState(() => _fill(_quick[index])),
                ),
              ),
            ),
          if (_quickError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _quickError!,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('chat-input'),
                    controller: _input,
                    enabled: !_sending && !_uncertain,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    inputFormatters: [LengthLimitingTextInputFormatter(1000)],
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: '输入消息…',
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.canvas,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('chat-send'),
                  onPressed: _sending || _fetching || _uncertain || !_ready
                      ? null
                      : _send,
                  child: Text(_sending ? '发送中' : '发送'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _bubble(ConversationMessage item) => Padding(
    key: ValueKey('chat-message-${item.id}'),
    padding: const EdgeInsets.only(bottom: 12),
    child: Align(
      alignment: item.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: item.mine ? AppColors.interactive : AppColors.canvas,
          borderRadius: BorderRadius.circular(8),
          border: item.mine ? null : Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              item.display,
              style: TextStyle(
                color: item.mine ? AppColors.canvas : AppColors.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${messageDate(item.time)} ${messageClock(item.time)}',
              style: TextStyle(
                color: item.mine
                    ? AppColors.canvas.withValues(alpha: .72)
                    : AppColors.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
