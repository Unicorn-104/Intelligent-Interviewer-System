import 'dart:async';

import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../features/messages/data/chat_attachment_picker.dart';
import '../features/messages/presentation/chat_attachment_view.dart';
import '../features/profile/data/profile_api.dart';
import '../features/profile/presentation/profile_avatar.dart';
import '../features/auth/domain/auth_session.dart';
import '../features/messages/data/message_api.dart';
import '../features/messages/domain/app_message.dart';
import '../features/messages/presentation/reschedule_message_card.dart';
import '../features/messages/presentation/interview_invitation_card.dart';
import '../features/interviews/presentation/conference_screen.dart';
import '../features/messages/presentation/shared_job_card_view.dart';
import '../features/messages/presentation/shared_job_detail_screen.dart';
import '../features/jobs/data/job_api.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_composer.dart';

class HrChatScreen extends StatefulWidget {
  const HrChatScreen({
    super.key,
    required this.session,
    required this.conversation,
    this.messageApi,
    this.sharedJobApi,
    this.profileApi,
    this.pollInterval = const Duration(seconds: 8),
  });

  final AuthSession session;
  final AppMessage conversation;
  final MessageApi? messageApi;
  final JobApi? sharedJobApi;
  final ProfileApi? profileApi;
  final Duration pollInterval;

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
  bool _acknowledging = false;
  int _lastAcknowledged = 0;
  String? _avatar, _attachmentError, _attachmentPhase;
  ChatPickedAttachment? _pendingAttachment;
  ChatUploadedAttachment? _uploadedAttachment;
  bool _attachmentUncertain = false, _attachmentSent = false;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _api = widget.messageApi ?? MessageApi(_client);
    _avatar = widget.session.avatar;
    _loadProfile();
    _scrollController.addListener(_acknowledgeVisible);
    WidgetsBinding.instance.addObserver(this);
    _load();
    if (widget.pollInterval > Duration.zero) {
      _timer = Timer.periodic(widget.pollInterval, (_) {
        if (_active && !_sending && ModalRoute.of(context)?.isCurrent == true) {
          _load(silent: true);
        }
      });
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await (widget.profileApi ?? ProfileApi(_client))
          .fetchProfile(widget.session.token);
      if (mounted) setState(() => _avatar = profile.avatar);
    } catch (_) {
      // 资料暂时不可用时沿用登录态头像，聊天仍可使用。
    }
  }

  Future<void> _chooseAttachment(bool image, {bool camera = false}) async {
    if (_sending || _pendingAttachment != null) return;
    setState(() => _sending = true);
    try {
      final picked = camera
          ? await _api.pickCameraAttachment()
          : await _api.pickAttachment(image: image);
      if (!mounted || picked == null) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(image ? '发送图片' : '发送文件'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image)
                Image.memory(
                  picked.bytes,
                  height: 150,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Text('图片预览不可用'),
                ),
              Text(picked.name),
              Text('${(picked.bytes.length / 1024).toStringAsFixed(1)} KB'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认发送'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      setState(() {
        _pendingAttachment = picked;
        _uploadedAttachment = null;
        _attachmentSent = false;
        _attachmentUncertain = false;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException ? error.message : '附件选择失败，请重新选择',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    if (mounted && _pendingAttachment != null) await _sendAttachment();
  }

  Future<void> _sendAttachment() async {
    final picked = _pendingAttachment;
    if (picked == null || _sending || _attachmentUncertain || _attachmentSent) {
      return;
    }
    var attempted = false;
    setState(() {
      _sending = true;
      _attachmentError = null;
      _attachmentPhase = '正在上传附件…';
    });
    try {
      final uploaded =
          _uploadedAttachment ??
          await _api.uploadAttachment(widget.session.token, picked);
      if (!mounted) return;
      _uploadedAttachment = uploaded;
      setState(() => _attachmentPhase = '正在发送附件…');
      attempted = true;
      await _api.sendAttachment(
        widget.session.token,
        widget.conversation.sourceId,
        uploaded,
      );
      if (!mounted) return;
      _attachmentSent = true;
      await _load(scrollToEnd: true);
      if (!mounted) return;
      if (_error == null) {
        setState(_clearAttachment);
      } else {
        setState(() => _attachmentError = '附件已发送，聊天记录暂未刷新，请刷新查看');
      }
    } catch (error) {
      if (!mounted) return;
      final known = error is ApiException && error.code != null;
      setState(() {
        _attachmentUncertain = attempted && !known;
        _attachmentError = _attachmentUncertain
            ? '发送结果待确认，请刷新聊天记录核对，避免重复发送'
            : error is ApiException
            ? error.message
            : '附件上传失败，请重试';
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _attachmentPhase = null;
        });
      }
    }
  }

  void _clearAttachment() {
    _pendingAttachment = null;
    _uploadedAttachment = null;
    _attachmentError = null;
    _attachmentUncertain = false;
    _attachmentSent = false;
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
    final follow =
        _messages == null ||
        !_scrollController.hasClients ||
        _scrollController.position.maxScrollExtent - _scrollController.offset <
            80;
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
      if (scrollToEnd || follow) {
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
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _acknowledgeVisible(),
      );
    } on ApiException catch (error) {
      if (mounted && (!silent || _messages == null)) {
        setState(() => _error = error.message);
      }
    } finally {
      _loadingMessages = false;
    }
  }

  Future<void> _acknowledgeVisible() async {
    final messages = _messages;
    if (!mounted ||
        !_active ||
        _acknowledging ||
        messages == null ||
        ModalRoute.of(context)?.isCurrent != true ||
        !_scrollController.hasClients ||
        _scrollController.position.maxScrollExtent - _scrollController.offset >
            40 ||
        !messages.any((row) => row.deliveryStatus != null)) {
      return;
    }
    final last = messages.fold<int>(
      0,
      (id, row) => row.messageId > id ? row.messageId : id,
    );
    if (last <= _lastAcknowledged) return;
    _acknowledging = true;
    try {
      if (await _api.acknowledgeRead(
        widget.session.token,
        widget.conversation.sourceId,
        last,
      )) {
        _lastAcknowledged = last;
      }
    } catch (_) {
      // 下次刷新只重试幂等已读确认，消息不会重新发送。
    } finally {
      _acknowledging = false;
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
          if (_pendingAttachment != null)
            Material(
              color: AppColors.primarySoft,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pendingAttachment!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_sending) ...[
                      Text(_attachmentPhase ?? '正在处理附件…'),
                      const LinearProgressIndicator(),
                    ] else ...[
                      Text(_attachmentError ?? ''),
                      Wrap(
                        children: [
                          if (!_attachmentUncertain && !_attachmentSent)
                            TextButton(
                              onPressed: _sendAttachment,
                              child: const Text('重试发送'),
                            ),
                          TextButton(
                            onPressed: () => _load(scrollToEnd: true),
                            child: const Text('刷新记录'),
                          ),
                          TextButton(
                            onPressed: () => setState(_clearAttachment),
                            child: Text(
                              _attachmentUncertain || _attachmentSent
                                  ? '关闭提示'
                                  : '取消附件',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ChatComposer(
            controller: _textController,
            busy: _sending,
            onSend: _send,
            onCamera: _pendingAttachment == null
                ? () => _chooseAttachment(true, camera: true)
                : null,
            moreTooltip: '发送图片或文件',
            actions: _pendingAttachment != null
                ? []
                : [
                    ChatComposerAction(
                      '发送图片',
                      Icons.image_outlined,
                      () => _chooseAttachment(true),
                    ),
                    ChatComposerAction(
                      '发送文件',
                      Icons.attach_file,
                      () => _chooseAttachment(false),
                    ),
                  ],
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
        itemBuilder: (context, index) => _ChatBubble(
          message: messages[index],
          session: widget.session,
          sharedJobApi: widget.sharedJobApi,
          api: _api,
          ownAvatar: _avatar,
          peerAvatar: widget.conversation.avatarUrl,
          peerName: widget.conversation.title,
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.session,
    this.sharedJobApi,
    required this.api,
    required this.ownAvatar,
    required this.peerAvatar,
    required this.peerName,
  });
  final JobApi? sharedJobApi;
  final MessageApi api;
  final String? ownAvatar, peerAvatar;
  final String peerName;

  final AuthSession session;

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
          ProfileAvatar(
            avatar: peerAvatar,
            name: peerName,
            radius: 18,
            backgroundColor: AppColors.primarySoft,
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
                padding: message.type == 2
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: message.type == 2
                    ? null
                    : BoxDecoration(
                        color: message.mine
                            ? const Color(0xFF95EC69)
                            : AppColors.canvas,
                        borderRadius: message.type == 2
                            ? BorderRadius.circular(12)
                            : BorderRadius.only(
                                topLeft: const Radius.circular(12),
                                topRight: const Radius.circular(12),
                                bottomLeft: Radius.circular(
                                  message.mine ? 12 : 3,
                                ),
                                bottomRight: Radius.circular(
                                  message.mine ? 3 : 12,
                                ),
                              ),
                        border: message.mine || message.type == 2
                            ? null
                            : Border.all(color: AppColors.hairline),
                      ),
                child: message.type == 2 || message.type == 3
                    ? ChatAttachmentView(message: message, api: api)
                    : message.interviewInvitation != null
                    ? InterviewInvitationCard(
                        invitation: message.interviewInvitation!,
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => ConferenceScreen(
                              session: session,
                              roomToken: message.interviewInvitation!.token,
                            ),
                          ),
                        ),
                      )
                    : message.jobCard != null
                    ? SharedJobCardView(
                        card: message.jobCard!,
                        candidate: true,
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => SharedJobDetailScreen(
                              positionId: message.jobCard!.positionId,
                              api: sharedJobApi,
                              session: session,
                            ),
                          ),
                        ),
                      )
                    : message.type == 6
                    ? const Text('岗位卡片暂不可用，请联系招聘者重新发送')
                    : message.reschedule == null
                    ? Text(
                        message.content,
                        style: TextStyle(
                          color: AppColors.body,
                          fontSize: 16,
                          height: 1.55,
                        ),
                      )
                    : RescheduleMessageCard(
                        data: message.reschedule!,
                        mine: false,
                      ),
              ),
              if (message.type != 2) ...[
                const SizedBox(height: 4),
                Text(
                  '${_formatChatTime(message.createdAt)}${message.mine && ['read', 'delivered'].contains(message.deliveryStatus) ? (message.deliveryStatus == 'read' ? ' · 已读' : ' · 送达') : ''}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ],
            ],
          ),
        ),
        if (message.mine) ...[
          const SizedBox(width: 9),
          ProfileAvatar(
            avatar: ownAvatar,
            name: session.nickName,
            radius: 18,
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
          ),
        ],
      ],
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
