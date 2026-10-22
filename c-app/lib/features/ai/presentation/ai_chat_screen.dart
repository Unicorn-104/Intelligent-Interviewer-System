import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../auth/domain/auth_session.dart';
import '../../applications/data/application_api.dart';
import '../../applications/domain/job_application.dart';
import '../../resume/data/resume_api.dart';
import '../../resume/domain/app_resume.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/job_card.dart';
import '../data/ai_api.dart';
import '../data/ai_conversation_store.dart';
import '../domain/ai_models.dart';
import 'ai_chat_controller.dart';
import 'ai_markdown_content.dart';
import 'ai_sessions_panel.dart';
import 'ai_application_picker.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({
    super.key,
    required this.session,
    this.conversation,
    this.api,
    this.resumeApi,
    this.applicationApi,
    this.embedded = false,
    this.overlay = false,
    this.restoreLastConversation = false,
  });
  final AuthSession session;
  final AiSession? conversation;
  final AiApi? api;
  final ResumeApi? resumeApi;
  final ApplicationApi? applicationApi;
  final bool embedded;
  final bool overlay;
  final bool restoreLastConversation;
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _client = ApiClient();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late AiChatController _chat;
  late final AiApi _api = widget.api ?? AiApi(_client);
  late final AiConversationStore? _conversationStore =
      widget.restoreLastConversation
      ? AiConversationStore(userId: widget.session.userId)
      : null;
  int? _resumeId;
  String? _resumeName;
  JobApplication? _application;
  String _action = 'chat';
  bool _choosingResume = false;
  bool _choosingApplication = false;
  bool _scrollScheduled = false;
  int _suggestionSet = 0;
  static const _suggestions = [
    ['帮我制定一周学习计划', '分析我的简历有哪些优势', '帮我润色一段文字'],
    ['给我解释一个技术概念', '根据简历找合适的岗位', '陪我练习面试自我介绍'],
  ];

  @override
  void initState() {
    super.initState();
    _open(widget.conversation, restoreLast: widget.restoreLastConversation);
  }

  void _open(AiSession? conversation, {bool restoreLast = false}) {
    _chat = AiChatController(
      _api,
      widget.session.token,
      conversation?.id,
      conversationStore: _conversationStore,
      restoreLastConversation: restoreLast,
    );
    _chat.addListener(_followLatest);
    _chat.load();
  }

  void _followLatest() {
    if (_scrollScheduled || !mounted) return;
    if (_scroll.hasClients && _scroll.position.extentAfter > 150) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _switchConversation(AiSession? conversation) {
    _chat.dispose();
    _input.clear();
    setState(() {
      _resumeId = null;
      _resumeName = null;
      _application = null;
      _action = 'chat';
      _open(conversation);
    });
  }

  Future<void> _history() async {
    final conversation = await showModalBottomSheet<AiSession>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.72,
          child: AiSessionsPanel(
            session: widget.session,
            api: _api,
            selectedId: _chat.sessionId,
            onSelected: (value) => Navigator.pop(sheetContext, value),
            onDeleted: (id) {
              if (id == _chat.sessionId) {
                Navigator.pop(
                  sheetContext,
                  const AiSession(AiSessionsPanel.draftId, '新对话'),
                );
              }
            },
          ),
        ),
      ),
    );
    if (!mounted || conversation == null) return;
    if (conversation.id == AiSessionsPanel.draftId ||
        conversation.id == _chat.sessionId) {
      return;
    }
    _switchConversation(conversation);
  }

  Future<bool> _chooseResume() async {
    if (_chat.busy ||
        _chat.loading ||
        _chat.awaitingConversation ||
        _choosingResume ||
        _choosingApplication) {
      return false;
    }
    setState(() => _choosingResume = true);
    try {
      final resumes = await (widget.resumeApi ?? ResumeApi(_client)).list(
        widget.session.token,
      );
      if (!mounted) return false;
      if (resumes.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂无简历，可先自由聊天，或到简历页创建简历')));
        return false;
      }
      final selected = await showModalBottomSheet<AppResume>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(
                  title: Text('选择本次使用的简历'),
                  subtitle: Text('仅在简历相关功能需要时使用'),
                ),
                for (final resume in resumes)
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(resume.resumeName),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: resume.resumeId == null
                        ? null
                        : () => Navigator.pop(sheetContext, resume),
                  ),
              ],
            ),
          ),
        ),
      );
      if (!mounted || selected == null) return false;
      setState(() {
        _resumeId = selected.resumeId;
        _resumeName = selected.resumeName;
        _application = null;
      });
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('简历加载失败，可稍后重试；自由聊天不受影响')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _choosingResume = false);
    }
  }

  Future<bool> _chooseApplication() async {
    if (_chat.busy ||
        _chat.loading ||
        _chat.awaitingConversation ||
        _choosingResume ||
        _choosingApplication) {
      return false;
    }
    setState(() => _choosingApplication = true);
    try {
      final selected = await showModalBottomSheet<JobApplication>(
        context: context,
        isScrollControlled: true,
        builder: (_) => AiApplicationPicker(
          api: widget.applicationApi ?? ApplicationApi(_client),
          token: widget.session.token,
        ),
      );
      if (!mounted || selected == null) return false;
      setState(() {
        _application = selected;
        _resumeId = selected.resumeId;
        _resumeName = selected.resumeName ?? '该岗位投递简历';
      });
      return true;
    } finally {
      if (mounted) setState(() => _choosingApplication = false);
    }
  }

  Future<bool> _ensureSelection(String action) async {
    if (action == 'interview_preparation' && _application == null) {
      return _chooseApplication();
    }
    if ((action == 'job_recommendation' || action == 'resume_analysis') &&
        _resumeId == null) {
      return _chooseResume();
    }
    return true;
  }

  Future<void> _shortcut(String label) async {
    if (_chat.busy || _chat.loading || _chat.awaitingConversation) return;
    final action = switch (label) {
      '岗位推荐' => 'job_recommendation',
      '简历分析' => 'resume_analysis',
      '面试准备' => 'interview_preparation',
      _ => 'writing_polish',
    };
    if (!await _ensureSelection(action)) return;
    if (!mounted) return;
    setState(() => _action = action);
    _input.text = switch (label) {
      '岗位推荐' => '根据我选定的简历推荐合适的岗位，并说明匹配点和差距',
      '简历分析' => '分析我选定简历的优势和不足，给出具体修改建议',
      '面试准备' => '根据我选择的已投递岗位和该次投递使用的简历，分析面试重点并制定准备计划',
      _ => '帮我润色下面这段文字：',
    };
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
  }

  Future<void> _send() async {
    final content = _input.text;
    if (content.trim().isEmpty || _choosingResume || _choosingApplication) {
      return;
    }
    if (!await _ensureSelection(_action) || !mounted) return;
    if (await _chat.send(
          content,
          _resumeId,
          action: _action,
          applicationId: _action == 'interview_preparation' || _action == 'chat'
              ? _application?.id
              : null,
        ) &&
        mounted &&
        _input.text == content) {
      _input.clear();
      setState(() => _action = 'chat');
    }
  }

  @override
  void dispose() {
    _chat.dispose();
    _client.close();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _chat,
    builder: (context, _) => Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primarySoft,
              AppColors.background,
              AppColors.canvas,
            ],
            stops: [0, 0.4, 1],
          ),
        ),
        child: SafeArea(
          top: !widget.embedded,
          bottom: !widget.embedded,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text(
                      'AI 助手',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        if (widget.overlay)
                          IconButton(
                            tooltip: '关闭 AI 助手',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          )
                        else if (!widget.embedded)
                          IconButton(
                            tooltip: '返回',
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.arrow_back),
                          )
                        else
                          const Icon(
                            Icons.auto_awesome,
                            color: AppColors.purple,
                            size: 20,
                          ),
                        const Spacer(),
                        IconButton(
                          tooltip: '新对话',
                          onPressed:
                              _chat.busy ||
                                  _chat.loading ||
                                  _choosingResume ||
                                  _choosingApplication
                              ? null
                              : () => _switchConversation(null),
                          icon: const Icon(Icons.add_comment_outlined),
                        ),
                        IconButton(
                          tooltip: '历史会话',
                          onPressed:
                              _chat.busy ||
                                  _chat.loading ||
                                  _choosingResume ||
                                  _choosingApplication
                              ? null
                              : _history,
                          icon: const Icon(Icons.history),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _chat.loading && _chat.messages.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        children: [
                          if (_chat.hasOlder)
                            TextButton(
                              onPressed: _chat.loading
                                  ? null
                                  : () => _chat.load(older: true),
                              child: const Text('查看更早消息'),
                            ),
                          if (_chat.messages.isEmpty && !_chat.sending) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.canvas,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.smart_toy_outlined,
                                    color: AppColors.purple,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: _bubble(
                                    AiMessage(
                                      role: 'assistant',
                                      content:
                                          '你好，我是你的 AI 助手。\n可以随时和我聊聊，也可以让我帮你分析简历、寻找岗位或准备面试。',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            '你可以对我说',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () => setState(
                                            () => _suggestionSet =
                                                1 - _suggestionSet,
                                          ),
                                          icon: const Icon(
                                            Icons.refresh,
                                            size: 16,
                                          ),
                                          label: const Text('换一换'),
                                        ),
                                      ],
                                    ),
                                    for (final text
                                        in _suggestions[_suggestionSet])
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: AppSpacing.sm,
                                        ),
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.all(
                                              AppSpacing.md,
                                            ),
                                            alignment: Alignment.centerLeft,
                                          ),
                                          onPressed: _chat.busy
                                              ? null
                                              : () {
                                                  setState(
                                                    () => _action = 'chat',
                                                  );
                                                  _input.text = text;
                                                },
                                          child: Row(
                                            children: [
                                              Expanded(child: Text(text)),
                                              const Icon(
                                                Icons.chevron_right,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          for (final message in _chat.messages)
                            _bubble(message),
                          if (_chat.runId != null) ...[
                            if (_chat.draft.isNotEmpty)
                              _bubble(
                                AiMessage(
                                  role: 'assistant',
                                  content: _chat.draft,
                                  cards: _chat.cards,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      _chat.status,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              if (_chat.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _chat.error!,
                          style: const TextStyle(color: AppColors.red),
                        ),
                      ),
                      TextButton(
                        onPressed: _chat.loading || _chat.sending
                            ? null
                            : _chat.runId != null
                            ? _chat.reconnect
                            : _chat.canRetry
                            ? () => _chat.retry()
                            : _chat.load,
                        child: Text(
                          _chat.runId != null
                              ? '重新连接'
                              : _chat.canRetry
                              ? '重新生成'
                              : '刷新',
                        ),
                      ),
                    ],
                  ),
                ),
              if (_resumeId != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 16,
                        color: AppColors.interactive,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _resumeName ?? '已选择简历',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: '取消简历上下文',
                        onPressed: _chat.busy
                            ? null
                            : () => setState(() {
                                _resumeId = null;
                                _resumeName = null;
                                _application = null;
                              }),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                ),
              if (_application != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.work_outline,
                        size: 16,
                        color: AppColors.interactive,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '${_application!.jobTitle} · ${_application!.companyName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: '取消岗位上下文',
                        onPressed: _chat.busy
                            ? null
                            : () => setState(() => _application = null),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                height: AppSpacing.minTouch + AppSpacing.sm,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  children: [
                    for (final label in [
                      '选择简历',
                      '选择岗位',
                      '岗位推荐',
                      '简历分析',
                      '面试准备',
                      '写作润色',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ActionChip(
                          label: Text(label),
                          onPressed:
                              _chat.busy ||
                                  _chat.loading ||
                                  _chat.awaitingConversation ||
                                  _choosingResume ||
                                  _choosingApplication
                              ? null
                              : label == '选择简历'
                              ? _chooseResume
                              : label == '选择岗位'
                              ? _chooseApplication
                              : () => _shortcut(label),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                color: AppColors.canvas,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 4000,
                            enabled:
                                !_chat.busy &&
                                !_chat.loading &&
                                !_chat.awaitingConversation &&
                                !_choosingResume &&
                                !_choosingApplication,
                            decoration: const InputDecoration(
                              hintText: '想聊什么，直接输入…',
                              counterText: '',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        if (_chat.runId != null)
                          IconButton(
                            tooltip: '停止生成',
                            onPressed: _chat.stopping ? null : _chat.stop,
                            icon: const Icon(Icons.stop_circle_outlined),
                          )
                        else
                          IconButton.filled(
                            tooltip: '发送',
                            onPressed:
                                _chat.busy ||
                                    _chat.loading ||
                                    _chat.awaitingConversation ||
                                    _choosingResume ||
                                    _choosingApplication
                                ? null
                                : _send,
                            icon: const Icon(Icons.arrow_upward),
                          ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        '内容由 AI 生成，请注意核实',
                        style: TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
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

  Widget _bubble(AiMessage message) {
    final user = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: user
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            user ? '你' : 'AI 助手',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: user ? AppColors.primarySoft : AppColors.canvas,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.hairline),
            ),
            child: user
                ? SelectableText(message.content)
                : AiMarkdownContent(content: message.content),
          ),
          if (user && ['FAILED', 'CANCELLED'].contains(message.runStatus))
            Text(
              message.runStatus == 'CANCELLED' ? '本次回答已停止' : '本次回答未完成',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          for (final job in message.cards)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: JobCard(job: job, session: widget.session),
            ),
        ],
      ),
    );
  }
}
