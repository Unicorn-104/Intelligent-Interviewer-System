import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../api/interview_room_api.dart' as room;
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/skeleton_list.dart';
import '../conference/conference_room_page.dart';
import '../conference/interview_modes.dart';
import '../jobs/job_detail_page.dart';
import '../talent/talent_detail_page.dart';
import '../talent/talent_discovery_profile.dart';
import '../talent/data/talent_discovery_data_source.dart';
import '../talent/models/talent_detail_view_data.dart';
import 'data/message_data_source.dart';
import 'models/chat_context.dart';
import 'models/exam_invitation.dart';
import 'models/message_view_data.dart';
import 'widgets/chat_composer.dart';
import 'widgets/chat_job_card.dart';
import 'widgets/message_avatar.dart';
import 'widgets/reschedule_chat_card.dart';
import 'widgets/chat_message_time.dart';
import 'widgets/share_job_sheet.dart';
import 'widgets/shared_job_card_view.dart';
import '../schedule/data/reschedule_review_data_source.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.session,
    this.source = const MessageDataSource(),
    this.pollInterval = const Duration(seconds: 8),
    this.rescheduleSource,
    this.joinInterviewInvite = room.joinRoomToken,
    this.conferenceRoomBuilder = _buildConferenceRoom,
  });
  final Map<String, dynamic> session;
  final MessageDataSource source;
  final Duration pollInterval;
  final RescheduleReviewDataSource? rescheduleSource;

  /// 按邀请链接中的 token 换回精确场次（可注入以隔离网络，测试用）。
  final Future<Map<String, dynamic>> Function(String token) joinInterviewInvite;

  /// 「进入面试」打开的会议室页面（可注入以隔离音视频/网络，测试用）。
  final Widget Function(Map<String, dynamic> session) conferenceRoomBuilder;

  static Widget _buildConferenceRoom(Map<String, dynamic> session) =>
      ConferenceRoomPage(session: session);
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final _input = TextEditingController(), _scroll = ScrollController();
  late final RescheduleReviewDataSource _reschedules =
      widget.rescheduleSource ??
      RescheduleReviewDataSource(client: widget.source.client);
  List<ConversationMessage> _messages = [];
  List<ChatQuickReply> _quick = [];
  int? _id;
  int? get _peerId => messageId(widget.session['peerId']);
  bool get _fromDiscovery => widget.session['fromTalentDiscovery'] == true;
  ChatContext? _chatContext;
  ChatJob? _selectedJob;
  bool _contextLoading = true, _openingCandidate = false;
  String? _contextError;
  String _recruiterName = '招聘者';
  String? _recruiterAvatarUrl;
  String get _peerName => messageText(
    widget.session['peerName'],
    messageText(widget.session['name'], '求职者'),
  );
  bool _loading = true,
      _fetching = false,
      _sending = false,
      _uncertain = false,
      _active = true,
      _ready = false;
  String? _error, _quickError;
  bool _quickLoading = false,
      _composerExpanded = false,
      _choosingAttachment = false;
  Timer? _timer;
  int _lastAcknowledged = 0;
  bool _acknowledging = false;
  bool _entering = false;
  static const _ownBubble = Color(0xFF95EC69);
  static const _bubbleText = Color(0xFF161616);
  static const _chatAvatarSize = 36.0;
  static const _chatAvatarSlot = 45.0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_acknowledgeVisible);
    _id = messageId(widget.session['sessionId']);
    _load();
    _loadQuick();
    _loadContext();
    _loadRecruiterProfile();
    if (widget.pollInterval > Duration.zero) {
      _timer = Timer.periodic(widget.pollInterval, (_) {
        if (mounted &&
            _active &&
            !_sending &&
            !_uncertain &&
            ModalRoute.of(context)?.isCurrent == true) {
          _load(silent: true);
        }
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

  Future<void> _loadRecruiterProfile() async {
    try {
      final profile = await widget.source.loadRecruiterProfile();
      if (!mounted) return;
      setState(() {
        _recruiterName = profile.name;
        _recruiterAvatarUrl = widget.source.avatarUrl(profile.avatar);
      });
    } catch (_) {
      // Profile failure must not interrupt chatting; keep the text avatar.
    }
  }

  Future<void> _loadContext() async {
    if (_fromDiscovery) {
      setState(() {
        _contextLoading = false;
        _contextError = null;
        _chatContext = ChatContext();
        _selectedJob = null;
      });
      return;
    }
    setState(() {
      _contextLoading = true;
      _contextError = null;
    });
    try {
      final data = await widget.source.loadChatContext(widget.session);
      if (!mounted) return;
      setState(() {
        _chatContext = data;
        _selectedJob = data.jobs.length == 1 ? data.jobs.single : null;
      });
    } catch (error) {
      if (mounted) setState(() => _contextError = messageError(error));
    } finally {
      if (mounted) setState(() => _contextLoading = false);
    }
  }

  Future<void> _selectJob() async {
    final jobs = _chatContext?.jobs ?? const <ChatJob>[];
    if (jobs.isEmpty) return;
    final selected = await showModalBottomSheet<ChatJob>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .6,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '选择应聘岗位',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '仅切换本页查看的岗位，不更改应聘记录',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: jobs.length,
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  return ListTile(
                    key: ValueKey('chat-job-option-${job.id}'),
                    title: Text(job.title),
                    subtitle: Text(job.salary),
                    trailing: _selectedJob?.id == job.id
                        ? const Icon(Icons.check, color: AppColors.interactive)
                        : null,
                    onTap: () => Navigator.pop(context, job),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (mounted && selected != null) setState(() => _selectedJob = selected);
  }

  Future<void> _openCandidate() async {
    if (_openingCandidate) return;
    _openingCandidate = true;
    try {
      await _showCandidate();
    } finally {
      _openingCandidate = false;
    }
  }

  Future<void> _showCandidate() async {
    if (_fromDiscovery && _peerId != null) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (profileContext) => TalentDiscoveryProfilePage(
            userId: _peerId!,
            source: TalentDiscoveryDataSource(client: widget.source.client),
            onContact: (_) async {
              if (profileContext.mounted) Navigator.of(profileContext).pop();
            },
          ),
        ),
      );
      return;
    }

    if (_contextLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 1500),
          content: Text('正在读取求职者资料，请稍候'),
        ),
      );
      return;
    }
    if (_contextError != null) {
      await _loadContext();
      if (!mounted || _contextError != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(milliseconds: 1500),
              content: Text(_contextError!),
            ),
          );
        }
        return;
      }
    }
    var talent = _selectedJob?.talent ?? _chatContext?.talent;
    if (talent == null && (_chatContext?.jobs.length ?? 0) > 1) {
      await _selectJob();
      if (!mounted) return;
      talent = _selectedJob?.talent;
      if (talent == null) return;
    }
    if (talent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 1500),
          content: Text('当前企业暂无该求职者的关联资料，请稍后刷新重试'),
        ),
      );
      return;
    }
    final job = _selectedJob;
    // null 检查后固化为非空 final 变量，便于在路由闭包内保持类型提升
    final Map<String, dynamic> resolvedTalent = talent;
    // 候选人行已含 applicationId（来自岗位候选人查询），取出用于投递级快照读取；无法解析时保持 null
    final applicationId = talentId(resolvedTalent['applicationId']);
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TalentDetailPage(
          talent: resolvedTalent,
          jobContext: job == null
              ? null
              : TalentJobContext(
                  positionId: job.id,
                  title: job.title,
                  currentStage: messageText(job.talent['currentStage'], ''),
                  applicationId: applicationId,
                ),
          source: widget.source.candidateDetailsSource,
        ),
      ),
    );
  }

  Widget _peerAvatar(String key, {double size = 36}) => Semantics(
    button: true,
    label: '查看$_peerName的求职者资料',
    child: Tooltip(
      message: '查看求职者资料',
      child: InkWell(
        key: ValueKey(key),
        onTap: _openCandidate,
        borderRadius: BorderRadius.circular(24),
        child: MessageAvatar(
          size: size,
          name: _peerName,
          url: widget.source.avatarUrl(
            messageText(widget.session['peerAvatar'], ''),
          ),
        ),
      ),
    ),
  );

  Future<void> _loadQuick() async {
    if (_id == null && _peerId == null) return;
    if (mounted) setState(() => _quickLoading = true);
    try {
      final rows = await widget.source.loadQuickReplies();
      if (mounted) {
        setState(() {
          _quick = rows;
          _quickError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _quickError = '常用语暂不可用');
    } finally {
      if (mounted) setState(() => _quickLoading = false);
    }
  }

  void _bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  });
  Future<void> _load({bool silent = false}) async {
    if (_fetching || (_sending && silent)) return;
    if (_id == null && _peerId == null) {
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
      if (_id == null) {
        final existing = await widget.source.findPeerSession(_peerId!);
        if (!mounted) return;
        _id = existing;
      }
      if (_id == null) {
        // 没有历史会话也可编辑首条消息，不创建虚假会话或占位聊天记录。
        setState(() {
          _messages = [];
          _ready = true;
          _error = _uncertain ? '未查到会话，请确认上一条消息是否送达后再继续编辑' : null;
        });
        return;
      }
      final rows = await widget.source.loadMessages(_id!);
      if (!mounted) return;
      await widget.source.readSession(_id!);
      if (!mounted) return;
      setState(() {
        _messages = rows;
        _error = _uncertain ? '请核对聊天记录后再继续编辑，避免重复发送' : null;
        _ready = true;
      });
      if (follow) _bottom();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _acknowledgeVisible(),
      );
    } catch (error) {
      if (mounted) setState(() => _error = messageError(error));
    } finally {
      _fetching = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async => _sendText(_input.text.trim(), clearDraft: true);

  Future<void> _sendText(String text, {bool clearDraft = false}) async {
    if (_sending ||
        _fetching ||
        _uncertain ||
        !_ready ||
        (_id == null && _peerId == null) ||
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
      if (_id == null) {
        final id = await widget.source.startPeerConversation(_peerId!, text);
        if (!mounted) return;
        _id = id;
      } else {
        await widget.source.send(_id!, text);
      }
      if (!mounted) return;
      if (clearDraft) _input.clear();
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

  Future<void> _sendJob() async {
    if (_sending ||
        _fetching ||
        _uncertain ||
        !_ready ||
        _peerId == null ||
        _choosingAttachment) {
      return;
    }
    setState(() => _choosingAttachment = true);
    try {
      final positionId = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: .85,
          child: ShareJobSheet(source: widget.source),
        ),
      );
      if (!mounted || positionId == null) return;
      final random = Random.secure();
      final requestId = List.generate(
        12,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      setState(() {
        _sending = true;
        _error = null;
      });
      try {
        final session = await widget.source.sendJobCard(
          sessionId: _id,
          peerId: _peerId!,
          positionId: positionId,
          requestId: requestId,
        );
        if (!mounted) return;
        _id = session;
        await _load();
        _bottom();
      } catch (error) {
        if (!mounted) return;
        final known = error is ApiException && error.code != null;
        setState(() {
          _uncertain = !known;
          _error = known ? messageError(error) : '岗位卡片发送结果待核对，请刷新聊天记录，勿重复发送';
        });
      } finally {
        if (mounted) setState(() => _sending = false);
      }
    } finally {
      if (mounted) setState(() => _choosingAttachment = false);
    }
  }

  Future<void> _saveQuickReply(ChatQuickReply? reply, String text) async {
    try {
      await widget.source.saveQuickReply(reply: reply, content: text);
    } finally {
      if (mounted) await _loadQuick();
    }
  }

  Future<void> _sendAttachment(bool image) async {
    if (_sending || _fetching || _uncertain || !_ready) return;
    if (_id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 1500),
          content: Text('请先发送一条文字消息，再发送图片或文件'),
        ),
      );
      return;
    }
    var messageAttempted = false;
    setState(() {
      _sending = true;
      _choosingAttachment = true;
      _error = null;
    });
    try {
      final picked = await widget.source.pickAttachment(image: image);
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
              if (image) ...[
                Image.memory(
                  picked.bytes,
                  height: 150,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Text('图片预览不可用'),
                ),
                const SizedBox(height: 8),
              ],
              Text(picked.name),
              Text(
                '${(picked.bytes.length / 1024).toStringAsFixed(1)} KB',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              const Text(
                '确认后上传并发送给当前求职者。请勿发送密码、证件等敏感资料。',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const Key('chat-confirm-attachment'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认发送'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      setState(() => _choosingAttachment = false);
      final uploaded = await widget.source.uploadAttachment(picked);
      if (!mounted) return;
      messageAttempted = true;
      await widget.source.sendAttachment(_id!, uploaded);
      if (!mounted) return;
      await _load();
      _bottom();
    } catch (error) {
      if (!mounted) return;
      final known = error is ApiException && error.code != null;
      setState(() {
        // Upload and picker errors cannot have sent a chat message.
        _uncertain = messageAttempted && !known;
        _error = _uncertain ? '附件发送结果待核对，请刷新记录后确认，避免重复发送' : messageError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _choosingAttachment = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFEDEDED),
    appBar: AppBar(
      toolbarHeight: MediaQuery.textScalerOf(context)
          .scale(40)
          .clamp(56.0, 112.0)
          .toDouble(),
      title: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: _peerAvatar('chat-peer-profile', size: 40),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _peerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17),
                ),
                const Text(
                  '求职者 · 点击头像查看资料',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
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
      child: LayoutBuilder(
        builder: (_, constraints) {
          final compact =
              constraints.maxHeight < 400 ||
              MediaQuery.viewInsetsOf(context).bottom > 0;
          return Column(
            children: [
              if (!_fromDiscovery)
                ChatJobCard(
                  compact: compact || _composerExpanded,
                  loading: _contextLoading,
                  job: _selectedJob,
                  error: _contextError,
                  jobCount: _chatContext?.jobs.length ?? 0,
                  onRetry: _loadContext,
                  onSelect: _selectJob,
                  onOpen: () {
                    final job = _selectedJob;
                    if (job != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => JobDetailPage(
                            job: job.job,
                            source: widget.source.jobDetailsSource,
                          ),
                        ),
                      );
                    }
                  },
                ),
              if (_error != null)
                Container(
                  width: double.infinity,
                  color: AppColors.warningSoft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                                    setState(
                                      () => _error = '请核对上方记录，确认上一条消息是否已送达',
                                    );
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
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 40,
                                ),
                                child: Text(
                                  _fromDiscovery && _id == null
                                      ? '发送第一条消息，开始与$_peerName沟通'
                                      : '暂无聊天记录',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              ),
                            if (_messages.isEmpty && !_ready)
                              TextButton(
                                onPressed: () => _load(),
                                child: const Text('重试加载聊天记录'),
                              ),
                            ..._messageTimeline(),
                          ],
                        ),
                      ),
              ),
              ChatComposer(
                controller: _input,
                disabled: _sending || _uncertain || !_ready,
                canSend: !_sending && !_fetching && !_uncertain && _ready,
                sending: _sending && !_choosingAttachment,
                quickReplies: _quick,
                quickLoading: _quickLoading,
                quickError: _quickError,
                maxPanelHeight: constraints.maxHeight * .4,
                maxInputLines: constraints.maxHeight < 360 ? 1 : 3,
                onSend: _send,
                onSendQuick: _sendText,
                onReloadQuick: _loadQuick,
                onSaveQuick: _saveQuickReply,
                onAttachment: _sendAttachment,
                onSendJob: _sendJob,
                onPanelChanged: (expanded) {
                  if (_composerExpanded != expanded) {
                    setState(() => _composerExpanded = expanded);
                  }
                },
              ),
            ],
          );
        },
      ),
    ),
  );
  Widget _messageContent(ConversationMessage item) {
    const color = _bubbleText;
    if (item.type == 2) {
      final url = widget.source.attachmentUrl(item.attachment);
      if (url != null) {
        return GestureDetector(
          key: ValueKey('chat-image-${item.id}'),
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      tooltip: '关闭图片',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Flexible(
                    child: InteractiveViewer(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('图片暂不可用'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              url,
              height: 150,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  Text('图片暂不可用', style: TextStyle(color: color)),
            ),
          ),
        );
      }
    }
    final card = item.jobCard;
    if (card != null) {
      return SharedJobCardView(card: card);
    }
    final exam = item.examInvitation;
    if (exam != null) {
      return _examInvitationCard(item.id, exam, mine: item.mine);
    }
    final reschedule = item.reschedule;
    if (reschedule != null) {
      return RescheduleChatCard(
        key: ValueKey('reschedule-chat-card-${item.id}'),
        data: reschedule,
        peerUserId: _peerId,
        canReview: !item.mine && reschedule['status'] == 'pending',
        source: _reschedules,
        onChanged: () => _load(silent: true),
      );
    }
    if (item.type == 3) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_outlined, color: color, size: 28),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              item.content.isEmpty ? '文件附件' : item.content,
              key: ValueKey('chat-file-${item.id}'),
              style: TextStyle(color: color),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    final invite = _interviewInviteLink(item.content);
    if (invite != null) {
      if (item.mine) {
        return _recruiterInterviewInvite(item.id, invite.text, invite.url);
      }
      return Container(
        key: ValueKey('chat-interview-card-${item.id}'),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.primarySoft.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.video_camera_front_outlined,
                  color: AppColors.interactive,
                  size: 18,
                ),
                SizedBox(width: 6),
                Text(
                  '面试邀请',
                  style: TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              invite.text,
              style: const TextStyle(color: color, fontSize: 15, height: 1.45),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: ValueKey('chat-enter-interview-${item.id}'),
              onPressed: _entering ? null : () => _enterInterview(invite.url),
              icon: const Icon(Icons.videocam_outlined, size: 20),
              label: const Text('进入面试'),
            ),
          ],
        ),
      );
    }
    return Text(
      item.display,
      style: const TextStyle(color: color, fontSize: 16, height: 1.55),
    );
  }

  Widget _examInvitationCard(
    int messageId,
    ExamInvitation exam, {
    required bool mine,
  }) {
    return Container(
      key: ValueKey('chat-exam-card-$messageId'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: AppColors.interactive,
                  size: 23,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '笔试邀请',
                  style: TextStyle(
                    color: AppColors.brand,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            exam.paperName,
            style: const TextStyle(
              color: AppColors.brand,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            exam.detail,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.bodySoft,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '考试场次 #${exam.scheduleId}',
              style: const TextStyle(
                color: AppColors.interactive,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 10),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              Icon(
                mine ? Icons.check_circle_outline : Icons.login_outlined,
                color: mine ? AppColors.green : AppColors.interactive,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  mine ? '已发送 · 求职者可点击进入考试' : '查看安排 · 进入考试',
                  style: TextStyle(
                    color: mine ? AppColors.bodySoft : AppColors.interactive,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recruiterInterviewInvite(int messageId, String text, String url) {
    final detail = _inviteDetail(text);
    return Semantics(
      button: true,
      label: '进入面试',
      child: InkWell(
        key: ValueKey('chat-enter-interview-$messageId'),
        onTap: _entering ? null : () => _enterInterview(url),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.video_camera_front_outlined,
                    color: AppColors.interactive,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '面试邀请',
                    style: TextStyle(
                      color: AppColors.brand,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              detail.title,
              style: const TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (detail.subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                detail.subtitle,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.bodySoft,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 10),
              child: Divider(height: 1),
            ),
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _entering ? '正在进入…' : '查看安排 · 进入面试',
                      style: const TextStyle(
                        color: AppColors.interactive,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (_entering)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.interactive,
                      size: 20,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  static ({String title, String subtitle}) _inviteDetail(String text) {
    final clean = text.trim();
    final tag = RegExp(r'^【面试邀请[^】]*】').firstMatch(clean);
    final body = (tag == null ? clean : clean.substring(tag.end)).trim();
    final tagText = tag?.group(0);
    final tagDetail = tagText == null
        ? ''
        : cleanInterviewTitle(
            tagText
                .substring(1, tagText.length - 1)
                .replaceFirst('面试邀请·', '')
                .trim(),
          );
    final normalized = body
        .replaceFirst(RegExp(r'视频面试[，,。]?请点击链接进入[:：]?\s*$'), '')
        .trim();
    if (normalized.isEmpty) {
      return (
        title: tagDetail.isEmpty ? '视频面试' : tagDetail,
        subtitle: '请确认面试安排后进入会议',
      );
    }
    final parts = normalized.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (
        title: tagDetail.isEmpty
            ? parts.take(parts.length - 1).join(' ')
            : tagDetail,
        subtitle: tagDetail.isEmpty ? parts.last : normalized,
      );
    }
    return (
      title: tagDetail.isEmpty ? normalized : tagDetail,
      subtitle: tagDetail.isEmpty ? '视频面试' : normalized,
    );
  }

  /// 面试邀请消息的会议链接（与 PC 端消息解析一致）；同时返回去除链接后的正文。
  static ({String text, String url})? _interviewInviteLink(String content) {
    final match = RegExp(
      r'https?://[^\s]*conference-join[^\s]*|/conference-join\?[^\s]+',
    ).firstMatch(content);
    if (match == null) return null;
    final url = match.group(0)!;
    final text = content
        .replaceFirst(url, '')
        .trim()
        .replaceFirst(RegExp(r'[：:\s]+$'), '');
    return (text: text, url: url);
  }

  static String? _conferenceToken(String url) {
    final token = Uri.tryParse(url)?.queryParameters['token']?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  /// 「进入面试」：只按当前邀请消息里的 token 解析场次，避免企业有多场
  /// 未结束面试时进到其他候选人的房间。
  Future<void> _enterInterview(String inviteUrl) async {
    if (_entering) return;
    final token = _conferenceToken(inviteUrl);
    if (token == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(compactErrorSnackBar('邀请链接无效'));
      return;
    }
    setState(() => _entering = true);
    try {
      final Map<String, dynamic> session;
      try {
        session = await widget.joinInterviewInvite(token);
      } catch (error) {
        if (!mounted) return;
        final text = error is ApiException ? error.message : '$error';
        final message = text.contains('已结束')
            ? '本场面试已结束'
            : text.contains('登录')
            ? '登录已过期，请重新登录'
            : '进入面试失败，请重试';
        ScaffoldMessenger.of(context)
            .showSnackBar(compactErrorSnackBar(message));
        return;
      }
      if (messageId(session['sessionId']) == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(compactErrorSnackBar('本场面试已结束'));
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => widget.conferenceRoomBuilder(session),
        ),
      );
    } finally {
      if (mounted) setState(() => _entering = false);
    }
  }

  Future<void> _acknowledgeVisible() async {
    if (!mounted ||
        !_active ||
        _acknowledging ||
        _id == null ||
        ModalRoute.of(context)?.isCurrent != true ||
        !_scroll.hasClients ||
        _scroll.position.maxScrollExtent - _scroll.offset > 40 ||
        !_messages.any((row) => row.deliveryStatus != null)) {
      return;
    }
    final last = _messages.fold<int>(0, (id, row) => row.id > id ? row.id : id);
    if (last <= _lastAcknowledged) return;
    _acknowledging = true;
    try {
      if (await widget.source.acknowledgeRead(_id!, last)) {
        _lastAcknowledged = last;
      }
    } catch (_) {
      // 幂等游标在下次刷新重试；确认失败不能改变发送方的已读显示。
    } finally {
      _acknowledging = false;
    }
  }

  Future<void> _messageDetails(ConversationMessage item) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '消息时间',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SelectableText(
              item.time == null ? '时间未知' : fullChatTimestamp(item.time!),
            ),
            if (item.mine && item.deliveryStatus != null) ...[
              const SizedBox(height: 12),
              Text(
                item.deliveryStatus == 'read'
                    ? '已读：对方已打开聊天并显示这批消息'
                    : '送达：消息已保存到对方会话，暂未收到已读回执',
              ),
            ],
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: item.display));
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('复制消息'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _messageTimeline() {
    return _messages.map(_bubble).toList();
  }

  String _chatMetaTime(DateTime? value) {
    if (value == null) return '时间未提供';
    final wall = value.toUtc().add(const Duration(hours: 8));
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final clock =
        '${wall.hour.toString().padLeft(2, '0')}:${wall.minute.toString().padLeft(2, '0')}';
    final sameDay =
        wall.year == now.year && wall.month == now.month && wall.day == now.day;
    return sameDay ? clock : '${wall.month}月${wall.day}日 $clock';
  }

  Widget _bubble(ConversationMessage item) => Padding(
    key: ValueKey('chat-message-${item.id}'),
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _chatAvatarSlot,
          child: item.mine
              ? null
              : Align(
                  alignment: Alignment.topLeft,
                  child: _peerAvatar('chat-peer-avatar-${item.id}'),
                ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final recruiterInvite =
                  item.mine && _interviewInviteLink(item.content) != null;
              final richContent =
                  item.jobCard != null ||
                  item.examInvitation != null ||
                  item.reschedule != null ||
                  (item.type == 2 &&
                      widget.source.attachmentUrl(item.attachment) != null);
              // 双方始终使用同一正文区域；尖角和回执不参与正文宽度计算。
              final maxBodyWidth = constraints.maxWidth;
              double? bodyWidth;
              if (item.type == 1 || item.type == 4) {
                final painter = TextPainter(
                  text: TextSpan(
                    text: item.display,
                    style: DefaultTextStyle.of(context).style
                        .merge(const TextStyle(fontSize: 16, height: 1.55)),
                  ),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: maxBodyWidth - 24);
                // 仅极短单行消息收窄，完整句子与多行消息共用双方矩形边界。
                bodyWidth =
                    painter.computeLineMetrics().length > 1 ||
                        item.display.characters.length > 6
                    ? maxBodyWidth
                    : (painter.maxIntrinsicWidth.ceilToDouble() + 32).clamp(
                        24,
                        maxBodyWidth,
                      );
                painter.dispose();
              }
              return Padding(
                padding: EdgeInsets.zero,
                child: Align(
                  alignment: item.mine ? Alignment.topRight : Alignment.topLeft,
                  child: Column(
                    crossAxisAlignment: item.mine
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            key: ValueKey('chat-bubble-${item.id}'),
                            width: bodyWidth,
                            constraints: BoxConstraints(maxWidth: maxBodyWidth),
                            padding: richContent
                                ? EdgeInsets.zero
                                : const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                            decoration: richContent
                                ? null
                                : BoxDecoration(
                                    color: recruiterInvite
                                        ? Colors.white
                                        : item.mine
                                        ? _ownBubble
                                        : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(12),
                                      topRight: const Radius.circular(12),
                                      bottomLeft: Radius.circular(
                                        item.mine ? 12 : 3,
                                      ),
                                      bottomRight: Radius.circular(
                                        item.mine ? 3 : 12,
                                      ),
                                    ),
                                    border: item.mine && !recruiterInvite
                                        ? null
                                        : Border.all(color: AppColors.hairline),
                                  ),
                            child: GestureDetector(
                              onLongPress: () => _messageDetails(item),
                              child: _messageContent(item),
                            ),
                          ),
                          // 仅标识尖角布局位置；填色和描边由气泡的完整轮廓统一绘制。
                        ],
                      ),
                      if (item.time != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 4,
                            left: 6,
                            right: 6,
                          ),
                          child: Tooltip(
                            message: fullChatTimestamp(item.time!),
                            child: Text(
                              '${_chatMetaTime(item.time)}${item.mine && ['read', 'delivered'].contains(item.deliveryStatus) ? ' · ${item.deliveryStatus == 'read' ? '已读' : '送达'}' : ''}',
                              key: ValueKey('chat-receipt-${item.id}'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontSize: 10),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(
          width: _chatAvatarSlot,
          child: item.mine
              ? Align(
                  alignment: Alignment.topRight,
                  child: Semantics(
                    label: '招聘者$_recruiterName的头像',
                    image: true,
                    child: MessageAvatar(
                      key: ValueKey('chat-recruiter-avatar-${item.id}'),
                      name: _recruiterName,
                      url: _recruiterAvatarUrl,
                      size: _chatAvatarSize,
                    ),
                  ),
                )
              : null,
        ),
      ],
    ),
  );
}
