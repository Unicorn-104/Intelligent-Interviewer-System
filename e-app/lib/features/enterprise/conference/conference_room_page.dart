import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../../api/interview_room_api.dart' as room;
import 'conference_room_engine.dart';
import 'interview_modes.dart';

/// 进入面试会议室所需的 PC 端接口（默认实现复用 /system/conference）。
typedef LoadLiveKitToken = Future<Map<String, dynamic>> Function(int sessionId);
typedef FinishConferenceSession = Future<void> Function(
  int sessionId, {
  Map<String, Object?>? payload,
});
typedef JoinConferenceSession = Future<Map<String, dynamic>> Function(
  int sessionId,
);
typedef ConferenceHeartbeat = Future<void> Function(int sessionId);
typedef ConferenceEngineFactory = ConferenceRoomEngine Function();

ConferenceRoomEngine _createConferenceEngine() => LiveKitConferenceEngine();

/// 面试视频会议室（HR 端）。
///
/// 复用 PC 端（enterprise_pc）同一套 /system/conference 接口：
/// - `GET  /system/conference/session/current` 由入口页查询当前场次；
/// - `POST /system/conference/session/{id}/interviewer/join` 登记面试官加入；
/// - `GET  /system/conference/livekit-token/{id}` 换取 LiveKit 入会令牌；
/// - `POST /system/conference/session/{id}/heartbeat` 保活；
/// - `POST /system/conference/session/{id}/finish` 结束时提交。
/// 音视频由 LiveKit 信令/媒体服务器承载，页面布局参考腾讯会议移动端与
/// enterprise_pc 视频会议页（宫格画面 + 底部控制栏 + 成员/会议信息面板）。
class ConferenceRoomPage extends StatefulWidget {
  const ConferenceRoomPage({
    super.key,
    required this.session,
    this.loadToken = room.getLiveKitToken,
    this.finish = room.finishSession,
    this.join = room.joinInterviewerSession,
    this.heartbeat = room.sendSessionHeartbeat,
    this.engineFactory = _createConferenceEngine,
  });

  /// 场次上下文（GET /system/conference/session/current 或 session/{id}）。
  final Map<String, dynamic> session;
  final LoadLiveKitToken loadToken;
  final FinishConferenceSession finish;
  final JoinConferenceSession join;
  final ConferenceHeartbeat heartbeat;
  final ConferenceEngineFactory engineFactory;

  @override
  State<ConferenceRoomPage> createState() => _ConferenceRoomPageState();
}

class _ConferenceRoomPageState extends State<ConferenceRoomPage> {
  late _SessionInfo _info;
  late ConferenceRoomEngine _engine;
  int? _sessionId;
  bool _booting = true;
  String? _fatalError;
  bool _leaving = false;
  bool _ending = false;
  int _seconds = 0;
  Timer? _clock;
  Timer? _heartbeat;
  String? _lastNotice;

  @override
  void initState() {
    super.initState();
    _info = _SessionInfo.from(widget.session);
    _engine = widget.engineFactory();
    _engine.addListener(_onEngineUpdate);
    _bootstrap();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _heartbeat?.cancel();
    _engine.removeListener(_onEngineUpdate);
    _engine.dispose();
    super.dispose();
  }

  int? get _myUserId => _userIdFromIdentity(_engine.state.localIdentity);

  bool get _isPrimarySelf {
    final myUserId = _myUserId;
    final primary = _info.primaryInterviewerId ?? _info.interviewerId;
    return myUserId != null && primary != null && myUserId == primary;
  }

  Future<void> _bootstrap() async {
    final sessionId = _info.sessionId;
    if (sessionId == null) {
      setState(() {
        _booting = false;
        _fatalError = '场次信息不完整，无法进入视频会议';
      });
      return;
    }
    _sessionId = sessionId;
    setState(() {
      _booting = true;
      _fatalError = null;
    });
    try {
      // 面试官加入登记（主面试官自动登记；失败不阻断入会）。
      if (_info.role == 'HR') {
        try {
          await widget.join(sessionId);
        } catch (_) {
          // 登记失败时仍允许进入会议，避免网络抖动阻断面试。
        }
      }
      final token = await widget.loadToken(sessionId);
      final url = _asText(token['url']);
      final jwt = _asText(token['token']);
      if (url.isEmpty || jwt.isEmpty) {
        throw const FormatException('视频会议服务未配置');
      }
      await _engine.connect(
        url: url,
        token: jwt,
        canPublish: _info.role != 'OBSERVER',
      );
    } catch (error) {
      if (!mounted) return;
      try {
        await _engine.disconnect();
      } catch (_) {
        // 清理失败不影响错误展示。
      }
      setState(() {
        _booting = false;
        _fatalError = '进入视频会议失败：${_friendlyError(error)}';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _booting = false);
    _startTimers();
  }

  void _startTimers() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
    final sessionId = _sessionId;
    if (sessionId == null) return;
    void beat() => unawaited(_quietly(() => widget.heartbeat(sessionId)));
    beat();
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) => beat());
  }

  Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // 心跳/结束等幂等调用失败时由下一轮重试。
    }
  }

  void _onEngineUpdate() {
    final notice = _engine.state.mediaNotice;
    if (notice == null || notice == _lastNotice || !mounted) return;
    _lastNotice = notice;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _toast(notice);
    });
  }

  void _retry() {
    _clock?.cancel();
    _heartbeat?.cancel();
    _engine.removeListener(_onEngineUpdate);
    _engine.dispose();
    setState(() {
      _engine = widget.engineFactory();
      _engine.addListener(_onEngineUpdate);
      _seconds = 0;
      _lastNotice = null;
      _fatalError = null;
      _booting = true;
    });
    _bootstrap();
  }

  Future<void> _toggleMic() async {
    if (!_engine.state.canPublish) return;
    try {
      await _engine.setMicrophoneEnabled(!_engine.state.micEnabled);
    } catch (error) {
      _toast('麦克风操作失败：${_friendlyError(error)}');
    }
  }

  Future<void> _toggleCamera() async {
    if (!_engine.state.canPublish) return;
    try {
      await _engine.setCameraEnabled(!_engine.state.cameraEnabled);
    } catch (error) {
      _toast('摄像头操作失败：${_friendlyError(error)}');
    }
  }

  Future<void> _flipCamera() async {
    try {
      await _engine.flipCamera();
    } catch (error) {
      _toast('切换摄像头失败：${_friendlyError(error)}');
    }
  }

  Future<void> _confirmEnd() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('确认结束本次面试？', style: TextStyle(color: _text)),
        content: const Text(
          '结束后将离开会议，剩余题目会被记为未完成，并进入评估报告生成流程。',
          style: TextStyle(color: _muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消', style: TextStyle(color: _muted)),
          ),
          TextButton(
            key: const ValueKey('conference-confirm-end'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认结束', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _leave(endSession: true);
  }

  void _showLeaveSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHandle(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: _text),
              title: const Text('离开会议', style: TextStyle(color: _text)),
              subtitle: const Text(
                '不结束面试，稍后可再次进入',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _leave(endSession: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.call_end_rounded, color: _red),
              title: const Text('结束面试', style: TextStyle(color: _red)),
              subtitle: const Text(
                '结束并退出，剩余题目记为未完成',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _leave(endSession: true);
              },
            ),
            ListTile(
              title: const Text(
                '取消',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted),
              ),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _leave({required bool endSession}) async {
    if (_leaving) return;
    _leaving = true;
    _clock?.cancel();
    _heartbeat?.cancel();
    final sessionId = _sessionId;
    if (endSession && sessionId != null) {
      unawaited(_finishQuietly(sessionId));
    }
    try {
      await _engine.disconnect();
    } catch (_) {
      // 断开失败仍需允许退出页面。
    }
    if (!mounted) return;
    setState(() => _ending = true);
    Navigator.of(context).pop();
  }

  Future<void> _finishQuietly(int sessionId) async {
    try {
      await widget.finish(sessionId, payload: const {'endReason': 'normal'});
    } catch (_) {
      // 与 PC 端一致：结束接口不阻塞退出会议。
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) return _shell(_loadingView());
    if (_fatalError != null) return _shell(_errorView(_fatalError!));
    return ListenableBuilder(
      listenable: _engine,
      builder: (context, _) {
        final state = _engine.state;
        if (state.stage == ConferenceRoomStage.failed && !_leaving) {
          return _shell(_errorView(state.error ?? '会议连接已断开'));
        }
        return _shell(_roomView(state));
      },
    );
  }

  Widget _shell(Widget child) => Scaffold(backgroundColor: _bg, body: child);

  Widget _loadingView() => const SafeArea(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _blue),
          SizedBox(height: 16),
          Text('正在进入视频会议…', style: TextStyle(color: _muted)),
        ],
      ),
    ),
  );

  Widget _errorView(String message) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined, size: 56, color: _muted),
            const SizedBox(height: 16),
            const Text(
              '无法进入视频会议',
              style: TextStyle(
                color: _text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, height: 1.6),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _text,
                    side: const BorderSide(color: _line),
                  ),
                  child: const Text('返回'),
                ),
                if (_info.sessionId != null) ...[
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _retry,
                    style: FilledButton.styleFrom(backgroundColor: _blue),
                    child: const Text('重试'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _roomView(ConferenceRoomState state) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_leaving) _showLeaveSheet();
    },
    child: SafeArea(
      child: Column(
        children: [
          _buildTopBar(state),
          Expanded(child: _buildStage(state)),
          _buildControls(state),
        ],
      ),
    ),
  );

  Widget _buildTopBar(ConferenceRoomState state) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 12, 6),
    child: Row(
      children: [
        IconButton(
          onPressed: _showLeaveSheet,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _text),
          tooltip: '离开会议',
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _info.positionTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_info.candidateName} · ${interviewModeLabel(_info.mode)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _line,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, size: 13, color: _muted),
              const SizedBox(width: 4),
              Text(
                _clockText(_seconds),
                style: const TextStyle(
                  color: _text,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _ending ? null : _confirmEnd,
          child: const Text('结束', style: TextStyle(color: _red)),
        ),
      ],
    ),
  );

  Widget _buildStage(ConferenceRoomState state) => Stack(
    children: [
      Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: state.remotes.isEmpty
              ? _waitingView(state)
              : _participantGrid(state),
        ),
      ),
      Positioned(top: 10, left: 10, child: _statusChip(state)),
      Positioned(top: 10, right: 10, child: _selfPreview(state)),
      Positioned(
        left: 14,
        bottom: 14,
        child: _badge(interviewModeLabel(_info.mode)),
      ),
    ],
  );

  Widget _waitingView(ConferenceRoomState state) {
    final initial = _initial(_info.candidateName);
    final statusText = switch (state.stage) {
      ConferenceRoomStage.connecting => '正在连接会议服务…',
      ConferenceRoomStage.reconnecting => '网络波动，正在重连…',
      ConferenceRoomStage.connected => '已进入会议室，等待候选人加入…',
      ConferenceRoomStage.failed => '会议连接已断开',
      ConferenceRoomStage.closed => '已离开会议',
    };
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: _blue,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _info.candidateName,
              style: const TextStyle(
                color: _text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              statusText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
            if (state.stage == ConferenceRoomStage.connecting ||
                state.stage == ConferenceRoomStage.reconnecting) ...[
              const SizedBox(height: 18),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _blue),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _participantGrid(ConferenceRoomState state) {
    final remotes = state.remotes;
    if (remotes.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 42),
        child: _remoteTile(remotes.first),
      );
    }
    final columns = remotes.length <= 4 ? 2 : 3;
    return GridView.builder(
      padding: const EdgeInsets.only(top: 42),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      itemCount: remotes.length,
      itemBuilder: (context, index) =>
          _remoteTile(remotes[index], compact: true),
    );
  }

  Widget _remoteTile(
    ConferenceRemoteParticipant participant, {
    bool compact = false,
  }) {
    final userId = _userIdFromIdentity(participant.identity);
    final name = _nameForUserId(userId);
    return _ParticipantSurface(
      name: name,
      role: _roleForUserId(userId),
      initial: _initial(name),
      video: participant.videoTrack,
      micEnabled: participant.micEnabled,
      speaking: participant.speaking,
      compact: compact,
    );
  }

  Widget _selfPreview(ConferenceRoomState state) {
    if (!state.canPublish) return _badge('旁听中');
    final selfName = _info.interviewerName.isEmpty
        ? '我'
        : _info.interviewerName;
    return SizedBox(
      width: 96,
      height: 130,
      child: Stack(
        children: [
          Positioned.fill(
            child: _ParticipantSurface(
              name: '我',
              initial: _initial(selfName),
              video: state.cameraEnabled ? state.localVideoTrack : null,
              micEnabled: state.micEnabled,
              compact: true,
              mirror: true,
              placeholderText: state.cameraEnabled ? '连接摄像头…' : '摄像头已关闭',
            ),
          ),
          Positioned(top: 4, left: 4, child: _miniTag('我 · $selfName')),
        ],
      ),
    );
  }

  Widget _buildControls(ConferenceRoomState state) => Container(
    padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
    decoration: const BoxDecoration(
      color: _panel,
      border: Border(top: BorderSide(color: _line)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        if (state.canPublish) ...[
          _ControlButton(
            key: const ValueKey('conference-toggle-mic'),
            icon: state.micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
            label: state.micEnabled ? '静音' : '解除静音',
            off: !state.micEnabled,
            onTap: _toggleMic,
          ),
          _ControlButton(
            key: const ValueKey('conference-toggle-camera'),
            icon: state.cameraEnabled
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            label: state.cameraEnabled ? '关闭视频' : '开启视频',
            off: !state.cameraEnabled,
            onTap: _toggleCamera,
          ),
          _ControlButton(
            key: const ValueKey('conference-flip-camera'),
            icon: Icons.cameraswitch_rounded,
            label: '翻转',
            onTap: _flipCamera,
          ),
        ],
        _ControlButton(
          key: const ValueKey('conference-members'),
          icon: Icons.people_alt_rounded,
          label: '成员',
          onTap: () => _showMembers(state),
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
          label: '结束',
          danger: true,
          onTap: _confirmEnd,
        ),
      ],
    ),
  );

  void _showMembers(ConferenceRoomState state) {
    final candidateRemote = _remoteFor(state, _info.candidateUserId);
    final myUserId = _myUserId;
    final selfName = _info.interviewerName.isEmpty
        ? _nameForUserId(myUserId)
        : _info.interviewerName;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHeader(title: '会议成员（${state.remotes.length + 1}）'),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _MemberRow(
                      name: '我 · $selfName',
                      role: _isPrimarySelf ? '主面试官' : '面试官',
                      micEnabled: state.micEnabled,
                      present: true,
                    ),
                    _MemberRow(
                      name: _info.candidateName,
                      role: '候选人',
                      micEnabled: candidateRemote?.micEnabled ?? false,
                      present: candidateRemote != null,
                    ),
                    for (final interviewer in _info.interviewers)
                      if (interviewer.userId != myUserId)
                        _MemberRow(
                          name: interviewer.name,
                          role: interviewer.isPrimary ? '主面试官' : '面试官',
                          micEnabled:
                              _remoteFor(
                                state,
                                interviewer.userId,
                              )?.micEnabled ??
                              false,
                          present:
                              _remoteFor(state, interviewer.userId) != null,
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMore() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHeader(title: '会议信息'),
            _InfoRow(label: '应聘岗位', value: _info.positionTitle),
            if (_info.companyName.isNotEmpty)
              _InfoRow(label: '企业', value: _info.companyName),
            _InfoRow(label: '候选人', value: _info.candidateName),
            _InfoRow(label: '面试模式', value: interviewModeLabel(_info.mode)),
            if (_info.startAt.isNotEmpty)
              _InfoRow(
                label: '面试时间',
                value: _info.endAt.isEmpty
                    ? _info.startAt
                    : '${_info.startAt} - ${_info.endAt}',
              ),
            _InfoRow(label: '场次号', value: '#${_info.sessionId ?? '—'}'),
            const Divider(color: _line, height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: _text),
              title: const Text('离开会议', style: TextStyle(color: _text)),
              subtitle: const Text(
                '不结束面试，稍后可再次进入',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _leave(endSession: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.call_end_rounded, color: _red),
              title: const Text('结束面试', style: TextStyle(color: _red)),
              subtitle: const Text(
                '结束并退出，剩余题目记为未完成',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _leave(endSession: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  ConferenceRemoteParticipant? _remoteFor(
    ConferenceRoomState state,
    int? userId,
  ) {
    if (userId == null) return null;
    for (final participant in state.remotes) {
      if (_userIdFromIdentity(participant.identity) == userId) {
        return participant;
      }
    }
    return null;
  }

  String _nameForUserId(int? userId) {
    if (userId == null) return '参会者';
    if (userId == _info.candidateUserId) return _info.candidateName;
    for (final interviewer in _info.interviewers) {
      if (interviewer.userId == userId) return interviewer.name;
    }
    return '参会者';
  }

  String? _roleForUserId(int? userId) {
    if (userId == null) return null;
    if (userId == _info.candidateUserId) return '候选人';
    for (final interviewer in _info.interviewers) {
      if (interviewer.userId == userId) {
        return interviewer.isPrimary ? '主面试官' : '面试官';
      }
    }
    return null;
  }

  Widget _statusChip(ConferenceRoomState state) {
    final (label, color) = switch (state.stage) {
      ConferenceRoomStage.connecting => ('连接中', _orange),
      ConferenceRoomStage.connected => ('已连接', _green),
      ConferenceRoomStage.reconnecting => ('重连中', _orange),
      ConferenceRoomStage.failed => ('已断开', _red),
      ConferenceRoomStage.closed => ('已离开', _muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: _text, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(text, style: const TextStyle(color: _text, fontSize: 11)),
  );

  Widget _miniTag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.white, fontSize: 9),
    ),
  );
}

/// 宫格/单人画面：有视频轨时渲染视频，否则展示头像占位。
class _ParticipantSurface extends StatelessWidget {
  const _ParticipantSurface({
    required this.name,
    required this.initial,
    this.role,
    this.video,
    this.micEnabled = true,
    this.speaking = false,
    this.compact = false,
    this.mirror = false,
    this.placeholderText,
  });

  final String name;
  final String initial;
  final String? role;
  final lk.VideoTrack? video;
  final bool micEnabled;
  final bool speaking;
  final bool compact;
  final bool mirror;
  final String? placeholderText;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 10 : 16),
      child: Container(
        color: _panel,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video != null)
              lk.VideoTrackRenderer(
                video!,
                fit: lk.VideoViewFit.cover,
                mirrorMode: mirror
                    ? lk.VideoViewMirrorMode.mirror
                    : lk.VideoViewMirrorMode.auto,
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: compact ? 24 : 42,
                      backgroundColor: _blue,
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 18 : 30,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 14),
                      Text(
                        name,
                        style: const TextStyle(
                          color: _text,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (placeholderText != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        placeholderText!,
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(10, compact ? 14 : 22, 10, 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xB3000000)],
                  ),
                ),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 11 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (role != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          role!,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 8 : 10,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
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
            if (speaking)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(compact ? 10 : 16),
                      border: Border.all(color: _green, width: 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
  final bool off;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final background = danger
        ? _red
        : off
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.06);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _text, size: 22),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: danger ? _red : _muted, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 4,
    margin: const EdgeInsets.only(top: 10, bottom: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
    child: Text(
      title,
      style: const TextStyle(
        color: _text,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.name,
    required this.role,
    required this.present,
    required this.micEnabled,
  });

  final String name;
  final String role;
  final bool present;
  final bool micEnabled;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(
      backgroundColor: _blue,
      child: Text(
        _initial(name),
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
    ),
    title: Text(name, style: const TextStyle(color: _text)),
    subtitle: Text(
      '$role · ${present ? '已加入' : '未加入'}',
      style: const TextStyle(color: _muted, fontSize: 12),
    ),
    trailing: present
        ? Icon(
            micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
            color: micEnabled ? _green : _red,
            size: 20,
          )
        : const Text('未加入', style: TextStyle(color: _muted, fontSize: 12)),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(color: _muted, fontSize: 12),
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
}

class _SessionInfo {
  const _SessionInfo({
    required this.sessionId,
    required this.candidateUserId,
    required this.candidateName,
    required this.positionTitle,
    required this.companyName,
    required this.interviewerName,
    required this.interviewerId,
    required this.primaryInterviewerId,
    required this.mode,
    required this.role,
    required this.startAt,
    required this.endAt,
    required this.interviewers,
  });

  factory _SessionInfo.from(Map<String, dynamic> json) {
    final interviewers = <_InterviewerInfo>[];
    final rawInterviewers = json['interviewers'];
    if (rawInterviewers is List) {
      for (final item in rawInterviewers) {
        if (item is! Map) continue;
        final userId = _asInt(item['userId']);
        if (userId == null) continue;
        interviewers.add(
          _InterviewerInfo(
            userId: userId,
            name: _asText(item['userName'], '面试官'),
            isPrimary: _asInt(item['isPrimary']) == 1,
          ),
        );
      }
    }
    return _SessionInfo(
      sessionId: _asInt(json['sessionId']),
      candidateUserId: _asInt(json['candidateUserId']),
      candidateName: _asText(json['candidateName'], '候选人'),
      positionTitle: _asText(json['positionTitle'], '视频面试'),
      companyName: _asText(json['companyName']),
      interviewerName: _asText(json['interviewerName']),
      interviewerId: _asInt(json['interviewerId']),
      primaryInterviewerId: _asInt(json['primaryInterviewerId']),
      mode: _asInt(json['mode']),
      role: _asText(json['role'], 'HR'),
      startAt: _asText(json['appointmentStartAt']),
      endAt: _asText(json['appointmentEndAt']),
      interviewers: List<_InterviewerInfo>.unmodifiable(interviewers),
    );
  }

  final int? sessionId;
  final int? candidateUserId;
  final String candidateName;
  final String positionTitle;
  final String companyName;
  final String interviewerName;
  final int? interviewerId;
  final int? primaryInterviewerId;
  final int? mode;

  /// 本人在场次中的角色：CANDIDATE / HR / OBSERVER。
  final String role;
  final String startAt;
  final String endAt;
  final List<_InterviewerInfo> interviewers;
}

class _InterviewerInfo {
  const _InterviewerInfo({
    required this.userId,
    required this.name,
    required this.isPrimary,
  });

  final int userId;
  final String name;
  final bool isPrimary;
}

int? _userIdFromIdentity(String? identity) {
  final match = RegExp(r'^u(\d+)$').firstMatch(identity ?? '');
  return match == null ? null : int.tryParse(match.group(1)!);
}

int? _asInt(Object? value) => int.tryParse('${value ?? ''}');

String _asText(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _initial(String name) {
  final text = name.trim();
  return text.isEmpty ? '?' : text.substring(0, 1);
}

String _clockText(int seconds) {
  final value = seconds < 0 ? 0 : seconds;
  final hours = value ~/ 3600;
  final minutes = (value % 3600) ~/ 60;
  final rest = value % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = rest.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

String _friendlyError(Object error) {
  if (error is FormatException) return error.message;
  final text = '$error';
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}

const _bg = Color(0xFF0B0D12);
const _panel = Color(0xFF151922);
const _line = Color(0x1FFFFFFF);
const _text = Color(0xFFF2F5FA);
const _muted = Color(0xFF94A0B3);
const _green = Color(0xFF34C759);
const _orange = Color(0xFFFF9F0A);
const _red = Color(0xFFFF453A);
const _blue = Color(0xFF2B63D9);
