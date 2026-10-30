import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../../core/formatters/backend_date.dart';
import '../../auth/domain/auth_session.dart';
import '../domain/interview_schedule.dart';
import 'conference_controller.dart';

// Match E-App's conference palette; keep the dark surface local to the room.
const _bg = Color(0xFF0B0D12);
const _panel = Color(0xFF151922);
const _line = Color(0x1FFFFFFF);
const _text = Color(0xFFF2F5FA);
const _muted = Color(0xFF94A0B3);
const _green = Color(0xFF34C759);
const _orange = Color(0xFFFF9F0A);
const _red = Color(0xFFFF453A);
const _blue = Color(0xFF2B63D9);

class ConferenceRoomView extends StatefulWidget {
  const ConferenceRoomView({
    super.key,
    required this.controller,
    required this.session,
    required this.onLeave,
    required this.onFinish,
  });

  final ConferenceController controller;
  final AuthSession session;
  final VoidCallback onLeave, onFinish;

  @override
  State<ConferenceRoomView> createState() => _ConferenceRoomViewState();
}

class _ConferenceRoomViewState extends State<ConferenceRoomView> {
  String _answerDraft = '';
  BuildContext? _sheetContext;
  ConferenceController get c => widget.controller;
  bool get _waiting => c.phase == ConferencePhase.waiting;
  List<lk.RemoteParticipant> get _remotes =>
      c.media.room?.remoteParticipants.values.toList() ?? [];
  String get _selfName => widget.session.nickName.isNotEmpty
      ? widget.session.nickName
      : widget.session.userName;

  @override
  void initState() {
    super.initState();
    c.addListener(_phaseChanged);
  }

  void _phaseChanged() {
    if (c.phase != ConferencePhase.meeting &&
        c.phase != ConferencePhase.waiting &&
        _sheetContext != null) {
      if (ModalRoute.of(_sheetContext!)?.isCurrent == true) {
        Navigator.of(_sheetContext!).pop();
      }
      _sheetContext = null;
    }
  }

  @override
  void dispose() {
    c.removeListener(_phaseChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _bg,
    ),
    child: Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: _blue,
          surface: _panel,
          onSurface: _text,
          error: _red,
        ),
        textTheme: Theme.of(
          context,
        ).textTheme.apply(bodyColor: _text, displayColor: _text),
        iconTheme: const IconThemeData(color: _text),
        dividerColor: _line,
      ),
      child: Builder(
        builder: (context) => Material(
          color: _bg,
          child: SafeArea(
            child: ListenableBuilder(
              listenable: c,
              builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) {
                  final compactHeight = constraints.maxHeight < 460;
                  final children = <Widget>[
                    _topBar(),
                    if (c.error != null || c.notice != null)
                      _connectionNotice(),
                    if (compactHeight)
                      SizedBox(height: 360, child: _stage())
                    else
                      Expanded(child: _stage()),
                    if (!_waiting && c.mode != 4) _questionBar(),
                    _controls(),
                  ];
                  return compactHeight
                      ? SingleChildScrollView(child: Column(children: children))
                      : Column(children: children);
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 12, 6),
    child: Row(
      children: [
        IconButton(
          onPressed: c.busy ? null : widget.onLeave,
          tooltip: '离开会议',
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${c.context['positionTitle'] ?? '视频面试'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${c.context['companyName'] ?? '企业'} · ${interviewModeLabel(c.mode)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _badge(
          _waiting
              ? '等候中'
              : _clock(conferenceInt(c.progress['elapsedSeconds'])),
          icon: _waiting ? Icons.hourglass_top_rounded : Icons.timer_outlined,
        ),
        if (!_waiting)
          TextButton(
            onPressed: c.busy ? null : widget.onFinish,
            child: const Text('结束', style: TextStyle(color: _red)),
          ),
      ],
    ),
  );

  Widget _connectionNotice() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    child: Semantics(
      liveRegion: true,
      child: InkWell(
        onTap: () => _sheet(
          '连接提示',
          (_) => [
            Text(c.error ?? c.notice ?? ''),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _waiting ? c.poll : c.reconnect,
              icon: const Icon(Icons.refresh),
              label: Text(_waiting ? '刷新状态' : '重新连接音视频'),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: _orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.error ?? c.notice ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _orange, fontSize: 12),
                ),
              ),
              const Icon(Icons.chevron_right, color: _orange),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _stage() => Padding(
    padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
    child: Stack(
      children: [
        Positioned.fill(
          child: _waiting || _remotes.isEmpty
              ? _waitingSurface()
              : _remoteGrid(),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: _badge(
            _waiting
                ? '等候室'
                : c.media.connected
                ? '已连接'
                : c.connecting
                ? '连接中'
                : '连接已断开',
            icon: _waiting ? Icons.schedule : Icons.circle,
            color: _waiting || !c.media.connected ? _orange : _green,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: SizedBox(
            key: const ValueKey('conference-self-preview'),
            width: 96,
            height: 130,
            child: _ParticipantSurface(
              name: '我',
              track: c.media.cameraOn ? c.media.camera : null,
              micEnabled: c.media.microphoneOn,
              compact: true,
              mirror: true,
              placeholder: _waiting ? '设备已暂停' : '摄像头已关闭',
            ),
          ),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: _badge(interviewModeLabel(c.mode)),
        ),
      ],
    ),
  );

  Widget _waitingSurface() {
    final name = c.mode == 1
        ? 'AI 面试官'
        : '${c.context['interviewerName'] ?? '面试官'}';
    final title = _waiting
        ? c.readiness.selfReady
              ? '你已就绪，等待面试开始'
              : '已进入等候室'
        : c.media.connected
        ? c.mode == 1
              ? 'AI 面试进行中'
              : '等待面试官加入会议…'
        : c.connecting
        ? '正在连接音视频…'
        : '音视频未连接';
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 150, 24, 56),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 206).clamp(
                0,
                double.infinity,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: _blue,
                  child: Text(
                    name.characters.firstOrNull ?? '面',
                    style: const TextStyle(color: _text, fontSize: 30),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _text, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  _waiting
                      ? c.readiness.hint
                      : !c.media.connected
                      ? '请检查网络或设备权限，然后点击重新连接。'
                      : c.mode == 1
                      ? '请根据题目作答，AI 评估仅供招聘参考。'
                      : '对方加入后，画面将在这里显示。',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                if (_waiting) ...[
                  const SizedBox(height: 20),
                  _readyRow(
                    '我（求职者）',
                    c.readiness.selfLabel,
                    c.readiness.selfReady,
                  ),
                  const SizedBox(height: 8),
                  _readyRow(
                    '面试官',
                    c.readiness.peerLabel,
                    c.readiness.peerReady,
                  ),
                  TextButton.icon(
                    onPressed: c.poll,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('刷新等候状态'),
                  ),
                  if (c.waitingUpdatedAt != null)
                    Text(
                      '最近同步 ${TimeOfDay.fromDateTime(c.waitingUpdatedAt!).format(context)}',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                ] else if (!c.media.connected)
                  TextButton.icon(
                    onPressed: c.connecting || c.busy ? null : c.reconnect,
                    icon: const Icon(Icons.refresh),
                    label: Text(c.connecting ? '正在连接…' : '重新连接音视频'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _readyRow(String name, String label, bool ready) => Row(
    children: [
      Icon(
        ready ? Icons.check_circle_outline : Icons.schedule,
        size: 16,
        color: ready ? _green : _muted,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(name, style: const TextStyle(color: _muted, fontSize: 12)),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          label,
          textAlign: TextAlign.end,
          style: TextStyle(color: ready ? _green : _muted, fontSize: 12),
        ),
      ),
    ],
  );

  Widget _remoteGrid() {
    final tiles = <Widget>[];
    for (final person in _remotes) {
      final videos = person.videoTrackPublications.where(
        (p) => p.track != null && !p.muted,
      );
      final name = _participantName(person);
      if (videos.isEmpty) {
        tiles.add(
          _ParticipantSurface(
            name: name,
            micEnabled: person.isMicrophoneEnabled(),
            speaking: person.isSpeaking,
          ),
        );
      } else {
        for (final video in videos) {
          tiles.add(
            _ParticipantSurface(
              name: video.source == lk.TrackSource.screenShareVideo
                  ? '$name · 屏幕共享'
                  : name,
              track: video.track,
              screenShare: video.source == lk.TrackSource.screenShareVideo,
              micEnabled: person.isMicrophoneEnabled(),
              speaking: person.isSpeaking,
            ),
          );
        }
      }
    }
    return Padding(
      padding: EdgeInsets.only(top: tiles.length == 1 ? 42 : 146),
      child: tiles.length == 1
          ? tiles.single
          : GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: .78,
              children: tiles,
            ),
    );
  }

  String _participantName(lk.RemoteParticipant person) {
    if (person.name.isNotEmpty) return person.name;
    final id = RegExp(r'^u(\d+)$').firstMatch(person.identity)?.group(1);
    for (final interviewer
        in (c.context['interviewers'] as List? ?? []).whereType<Map>()) {
      if ('${interviewer['userId']}' == id) {
        return '${interviewer['userName'] ?? '面试官'}';
      }
    }
    if (id != null &&
        (id == '${c.context['interviewerId']}' ||
            id == '${c.context['primaryInterviewerId']}')) {
      return '${c.context['interviewerName'] ?? '面试官'}';
    }
    return '参会者';
  }

  String _participantRole(lk.RemoteParticipant person) {
    final id = RegExp(r'^u(\d+)$').firstMatch(person.identity)?.group(1);
    if (id == null) return '参会者';
    if (id == '${c.context['primaryInterviewerId']}') return '主面试官';
    final assigned = (c.context['interviewers'] as List? ?? [])
        .whereType<Map>();
    if (id == '${c.context['interviewerId']}' ||
        assigned.any((person) => '${person['userId']}' == id)) {
      return '面试官';
    }
    return '参会者';
  }

  Widget _questionBar() {
    final question = c.progress['question'];
    final takeover = conferenceInt(c.progress['takeover']) == 1;
    return Material(
      color: _panel,
      child: ListTile(
        leading: const Icon(Icons.auto_awesome_outlined, color: _blue),
        title: Text(
          takeover
              ? '面试官正在主导提问'
              : 'AI 面试 · 第 ${c.progress['currentQuestionNo'] ?? '—'} / ${c.progress['totalQuestionNo'] ?? '—'} 题',
          style: const TextStyle(color: _text, fontSize: 13),
        ),
        subtitle: Text(
          question is Map ? '${question['topic'] ?? '等待面试题目'}' : '等待面试官提问',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        trailing: const Icon(Icons.keyboard_arrow_up, color: _muted),
        onTap: _showAnswer,
      ),
    );
  }

  Widget _controls() => Container(
    padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
    decoration: const BoxDecoration(
      color: _panel,
      border: Border(top: BorderSide(color: _line)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth < 350 ||
                MediaQuery.textScalerOf(context).scale(12) > 16
            ? 3
            : 6;
        final enabled = !_waiting && c.media.connected && !c.busy;
        final actions = <Widget>[
          _ControlButton(
            key: const ValueKey('conference-toggle-mic'),
            icon: c.media.microphoneOn
                ? Icons.mic_rounded
                : Icons.mic_off_rounded,
            label: c.media.microphoneOn ? '静音' : '解除静音',
            off: !c.media.microphoneOn,
            onTap: enabled ? () => c.toggleMedia(camera: false) : null,
          ),
          _ControlButton(
            key: const ValueKey('conference-toggle-camera'),
            icon: c.media.cameraOn
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            label: c.media.cameraOn ? '关闭视频' : '开启视频',
            off: !c.media.cameraOn,
            onTap: enabled ? () => c.toggleMedia(camera: true) : null,
          ),
          _ControlButton(
            key: const ValueKey('conference-flip-camera'),
            icon: Icons.cameraswitch_rounded,
            label: '翻转',
            onTap: enabled && c.media.cameraOn ? c.flipCamera : null,
          ),
          _ControlButton(
            key: const ValueKey('conference-members'),
            icon: Icons.people_alt_rounded,
            label: '成员',
            onTap: _showMembers,
          ),
          _ControlButton(
            key: const ValueKey('conference-more'),
            icon: Icons.more_horiz_rounded,
            label: '更多',
            onTap: _showMore,
          ),
          _ControlButton(
            key: const ValueKey('conference-end'),
            icon: Icons.call_end_rounded,
            label: _waiting ? '离开' : '结束',
            danger: true,
            onTap: c.busy
                ? null
                : _waiting
                ? widget.onLeave
                : widget.onFinish,
          ),
        ];
        return Wrap(
          runSpacing: 12,
          children: [
            for (final action in actions)
              SizedBox(width: constraints.maxWidth / columns, child: action),
          ],
        );
      },
    ),
  );

  void _sheet(String title, List<Widget> Function(BuildContext) content) {
    BuildContext? openedContext;
    final theme = Theme.of(context).copyWith(
      colorScheme: const ColorScheme.dark(
        primary: _blue,
        surface: _panel,
        onSurface: _text,
      ),
      textTheme: Theme.of(
        context,
      ).textTheme.apply(bodyColor: _text, displayColor: _text),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: _bg,
        hintStyle: TextStyle(color: _muted),
        border: OutlineInputBorder(borderSide: BorderSide(color: _line)),
      ),
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        openedContext = sheetContext;
        _sheetContext = sheetContext;
        return Theme(
          data: theme,
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) => SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .78,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: _line,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  color: _text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              tooltip: '关闭面板',
                              icon: const Icon(Icons.close, color: _muted),
                            ),
                          ],
                        ),
                        ...content(sheetContext),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted && _sheetContext == openedContext) _sheetContext = null;
    });
  }

  void _showMembers() => _sheet(
    '会议成员',
    (_) => [
      _member(
        '我 · $_selfName',
        '候选人',
        _waiting
            ? c.readiness.selfLabel
            : c.media.connected
            ? '已加入'
            : '未连接',
        c.media.microphoneOn,
      ),
      if (_waiting)
        _member(
          '${c.context['interviewerName'] ?? '面试官'}',
          '面试官',
          c.readiness.peerLabel,
          false,
        )
      else ...[
        for (final person in _remotes)
          _member(
            _participantName(person),
            _participantRole(person),
            '已加入',
            person.isMicrophoneEnabled(),
          ),
        if (_remotes.isEmpty && c.mode != 1)
          _member(
            '${c.context['interviewerName'] ?? '面试官'}',
            '面试官',
            '未加入',
            false,
          ),
      ],
    ],
  );

  Widget _member(String name, String role, String state, bool mic) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: _blue,
      child: Text(
        name.characters.firstOrNull ?? '?',
        style: const TextStyle(color: _text),
      ),
    ),
    title: Text(name, style: const TextStyle(color: _text)),
    subtitle: Text(
      '$role · $state',
      style: const TextStyle(color: _muted, fontSize: 12),
    ),
    trailing: Icon(
      mic ? Icons.mic_none : Icons.mic_off_outlined,
      color: mic ? _green : _muted,
      size: 20,
    ),
  );

  void _showMore() => _sheet(
    '会议信息',
    (sheetContext) => [
      _info('应聘岗位', '${c.context['positionTitle'] ?? '岗位面试'}'),
      _info('企业', '${c.context['companyName'] ?? '企业'}'),
      _info('候选人', _selfName),
      _info('面试模式', interviewModeLabel(c.mode)),
      _info(
        '开始时间',
        displayBackendDate(c.context['appointmentStartAt']?.toString()),
      ),
      _info(
        '结束时间',
        displayBackendDate(c.context['appointmentEndAt']?.toString()),
      ),
      _info('场次号', '#${c.id ?? '—'}'),
      const Divider(color: _line),
      if (!_waiting && c.mode != 4) ...[
        ListTile(
          leading: const Icon(Icons.subtitles_outlined, color: _text),
          title: const Text('实时字幕', style: TextStyle(color: _text)),
          onTap: () {
            Navigator.pop(sheetContext);
            _showCaptions();
          },
        ),
        ListTile(
          leading: const Icon(Icons.edit_note, color: _text),
          title: const Text('文字作答', style: TextStyle(color: _text)),
          onTap: () {
            Navigator.pop(sheetContext);
            _showAnswer();
          },
        ),
      ],
      ListTile(
        leading: const Icon(Icons.refresh, color: _text),
        title: Text(
          _waiting ? '刷新等候状态' : '重新连接音视频',
          style: const TextStyle(color: _text),
        ),
        onTap: c.connecting || c.busy
            ? null
            : () {
                Navigator.pop(sheetContext);
                _waiting ? c.poll() : c.reconnect();
              },
      ),
      ListTile(
        leading: const Icon(Icons.logout_rounded, color: _text),
        title: const Text('离开会议', style: TextStyle(color: _text)),
        subtitle: const Text(
          '不结束面试，稍后可再次进入',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        onTap: c.busy
            ? null
            : () {
                Navigator.pop(sheetContext);
                widget.onLeave();
              },
      ),
      if (!_waiting)
        ListTile(
          leading: const Icon(Icons.call_end_rounded, color: _red),
          title: const Text('结束面试', style: TextStyle(color: _red)),
          subtitle: const Text(
            '结束后无法继续本场面试',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          onTap: c.busy
              ? null
              : () {
                  Navigator.pop(sheetContext);
                  widget.onFinish();
                },
        ),
    ],
  );

  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: _text, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  void _showCaptions() => _sheet(
    '实时字幕',
    (_) => [
      if (c.asr.notice != null)
        Text(c.asr.notice!, style: const TextStyle(color: _orange)),
      if (c.captions.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Text(
            '暂无字幕',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
        ),
      for (final caption in c.captions.reversed.take(12).toList().reversed)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '${switch (conferenceInt(caption['role'])) {
              1 => 'AI',
              2 => '面试官',
              3 => '我',
              _ => '发言',
            }}：${caption['content'] ?? ''}',
            style: const TextStyle(color: _text),
          ),
        ),
    ],
  );

  void _showAnswer() => _sheet(
    '文字作答',
    (_) => [
      _AnswerPanel(
        controller: c,
        initialDraft: _answerDraft,
        onDraftChanged: (value) {
          if (mounted) _answerDraft = value;
        },
      ),
    ],
  );
}

// The modal owns its input controller so it survives the room's exit transition.
class _AnswerPanel extends StatefulWidget {
  const _AnswerPanel({
    required this.controller,
    required this.initialDraft,
    required this.onDraftChanged,
  });
  final ConferenceController controller;
  final String initialDraft;
  final ValueChanged<String> onDraftChanged;
  @override
  State<_AnswerPanel> createState() => _AnswerPanelState();
}

class _AnswerPanelState extends State<_AnswerPanel> {
  late final _answer = TextEditingController(text: widget.initialDraft);
  ConferenceController get c => widget.controller;
  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _clearDraft() {
    _answer.clear();
    widget.onDraftChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final question = c.progress['question'];
    final takeover = conferenceInt(c.progress['takeover']) == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          takeover ? '面试官正在主导提问，请听取面试官指引' : 'AI 面试 · 评估结果仅供招聘参考',
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Text(
          question is Map ? '${question['topic'] ?? '等待面试题目'}' : '等待面试官提问',
          style: const TextStyle(color: _text, fontSize: 16),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('conference-answer-input'),
          controller: _answer,
          onChanged: widget.onDraftChanged,
          minLines: 3,
          maxLines: 6,
          maxLength: 6000,
          style: const TextStyle(color: _text),
          enabled:
              !c.busy &&
              !c.answerUncertain &&
              !takeover &&
              c.phase == ConferencePhase.meeting,
          decoration: const InputDecoration(hintText: '也可以在这里输入本题回答'),
        ),
        if (c.error != null)
          Text(c.error!, style: const TextStyle(color: _orange)),
        const SizedBox(height: 12),
        if (c.answerUncertain)
          OutlinedButton(
            onPressed: c.busy
                ? null
                : () async {
                    await c.confirmAnswerState();
                    if (!c.answerUncertain && mounted) _clearDraft();
                  },
            child: const Text('刷新并核对作答进度'),
          )
        else
          FilledButton(
            onPressed:
                c.busy ||
                    question is! Map ||
                    takeover ||
                    c.phase != ConferencePhase.meeting
                ? null
                : () async {
                    if (await c.answer(_answer.text) && mounted) _clearDraft();
                  },
            child: Text(c.busy ? '正在提交…' : '提交本题回答'),
          ),
      ],
    );
  }
}

Widget _badge(String text, {IconData? icon, Color color = _text}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
  decoration: BoxDecoration(
    color: Colors.black.withValues(alpha: .45),
    borderRadius: BorderRadius.circular(999),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
      ],
      Text(text, style: TextStyle(color: color, fontSize: 11)),
    ],
  ),
);

class _ParticipantSurface extends StatelessWidget {
  const _ParticipantSurface({
    required this.name,
    this.track,
    this.micEnabled = false,
    this.speaking = false,
    this.compact = false,
    this.mirror = false,
    this.screenShare = false,
    this.placeholder,
  });
  final String name;
  final lk.VideoTrack? track;
  final bool micEnabled, speaking, compact, mirror, screenShare;
  final String? placeholder;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(compact ? 10 : 16),
    child: Container(
      decoration: BoxDecoration(
        color: _panel,
        border: speaking
            ? Border.all(color: _green, width: 2)
            : Border.all(color: _line),
        borderRadius: BorderRadius.circular(compact ? 10 : 16),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (track != null)
            lk.VideoTrackRenderer(
              track!,
              fit: screenShare
                  ? lk.VideoViewFit.contain
                  : lk.VideoViewFit.cover,
              mirrorMode: mirror
                  ? lk.VideoViewMirrorMode.auto
                  : lk.VideoViewMirrorMode.off,
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: compact ? 22 : 40,
                      backgroundColor: _blue,
                      child: Text(
                        name.characters.firstOrNull ?? '?',
                        style: TextStyle(
                          color: _text,
                          fontSize: compact ? 18 : 30,
                        ),
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 14),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _text, fontSize: 17),
                      ),
                    ],
                    if (placeholder != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        placeholder!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: .7),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _text,
                        fontSize: compact ? 11 : 14,
                      ),
                    ),
                  ),
                  if (!micEnabled)
                    Icon(
                      Icons.mic_off_rounded,
                      size: compact ? 13 : 16,
                      color: _red,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.off = false,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool off, danger;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    child: Opacity(
      opacity: onTap == null ? .4 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: danger
                        ? _red
                        : Colors.white.withValues(alpha: off ? .14 : .06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: _text, size: 22),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: danger ? _red : _muted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

String _clock(int seconds) {
  final value = seconds < 0 ? 0 : seconds;
  final mm = ((value % 3600) ~/ 60).toString().padLeft(2, '0');
  final ss = (value % 60).toString().padLeft(2, '0');
  return value >= 3600 ? '${value ~/ 3600}:$mm:$ss' : '$mm:$ss';
}
