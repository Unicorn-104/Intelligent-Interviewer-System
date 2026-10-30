import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';
import '../../../core/network/api_client.dart';
import '../../../core/formatters/backend_date.dart';
import '../../../theme/app_theme.dart';
import '../../auth/domain/auth_session.dart';
import '../data/conference_api.dart';
import '../data/conference_media.dart';
import '../domain/interview_schedule.dart';
import 'conference_controller.dart';
import 'conference_room_view.dart';

class ConferenceScreen extends StatefulWidget {
  const ConferenceScreen({
    super.key,
    required this.session,
    this.roomToken,
    this.sessionId,
    this.controller,
  });
  final AuthSession session;
  final String? roomToken;
  final int? sessionId;
  final ConferenceController? controller;
  @override
  State<ConferenceScreen> createState() => _ConferenceScreenState();
}

class _ConferenceScreenState extends State<ConferenceScreen>
    with WidgetsBindingObserver {
  ApiClient? _client;
  late final ConferenceController c;
  bool _allowPop = false;
  @override
  void initState() {
    super.initState();
    c =
        widget.controller ??
        ConferenceController(
          api: ConferenceApi(_client = ApiClient(), widget.session.token),
          media: ConferenceMedia(),
          userId: widget.session.userId,
          roomToken: widget.roomToken,
          initialSessionId: widget.sessionId,
        );
    WidgetsBinding.instance.addObserver(this);
    unawaited(c.load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(c.foreground(false));
    }
    if (state == AppLifecycleState.resumed) unawaited(c.foreground(true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.dispose();
    _client?.close();
    super.dispose();
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _back() async {
    if (c.busy) return;
    if (c.phase == ConferencePhase.meeting &&
        !await _confirm('暂时离开面试？', '离开后将关闭本机音视频，面试不会被结束。你可以从邀请卡片重新进入。', '离开')) {
      return;
    }
    await c.leaveWaiting();
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _consent(bool? checked) async {
    if (checked != true) {
      await c.setConsent(false);
      return;
    }
    if (await _confirm(
      '面试录制告知',
      '本次面试的音视频及作答内容将用于本次招聘评估与合规存档，仅供获授权的招聘人员访问。请独立作答，并保持摄像头和麦克风可用。',
      '同意并继续',
    )) {
      await c.setConsent(true);
    }
  }

  Future<void> _finish() async {
    if (c.busy) return;
    if (await _confirm('结束本场面试？', '结束后将关闭音视频并提交面试结束状态，无法继续本场面试。', '确认结束')) {
      await c.finish();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) {
      final phase = c.phase;
      return PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_back());
        },
        child:
            phase == ConferencePhase.waiting || phase == ConferencePhase.meeting
            ? ConferenceRoomView(
                controller: c,
                session: widget.session,
                onLeave: _back,
                onFinish: _finish,
              )
            : Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    onPressed: _back,
                    tooltip: '返回',
                    icon: const Icon(Icons.arrow_back),
                  ),
                  title: Text(switch (phase) {
                    ConferencePhase.preparation => '面试准备',
                    ConferencePhase.waiting => '面试等候室',
                    ConferencePhase.meeting => '视频面试',
                    ConferencePhase.ended => '面试已结束',
                    _ => '面试邀请',
                  }),
                  actions: [
                    if (phase == ConferencePhase.meeting ||
                        phase == ConferencePhase.waiting)
                      IconButton(
                        onPressed: c.poll,
                        tooltip: '刷新面试状态',
                        icon: const Icon(Icons.refresh),
                      ),
                  ],
                ),
                body: phase == ConferencePhase.loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        children: [
                          if (c.error != null) _notice(c.error!, error: true),
                          if (c.notice != null) _notice(c.notice!),
                          if (phase == ConferencePhase.error) ...[
                            _status(
                              Icons.wifi_off,
                              '面试信息加载失败',
                              '请检查网络，或联系 HR 确认邀请是否有效。',
                            ),
                            FilledButton(
                              onPressed: c.load,
                              child: const Text('重新加载'),
                            ),
                          ] else if (phase == ConferencePhase.invalid) ...[
                            _status(
                              Icons.event_busy,
                              c.context['reason'] == 'finished'
                                  ? '本场面试已结束'
                                  : '无法进入本场面试',
                              c.context['reason'] == 'finished'
                                  ? '请返回消息列表，关注 HR 的后续通知。'
                                  : '邀请已失效，或当前账号不是本场面试的候选人，请联系 HR 确认。',
                            ),
                          ] else if (phase == ConferencePhase.ended)
                            ..._result()
                          else ...[
                            _information(),
                            const SizedBox(height: AppSpacing.lg),
                            if (phase == ConferencePhase.preparation)
                              ..._preparation(),
                          ],
                        ],
                      ),
                bottomNavigationBar: phase == ConferencePhase.preparation
                    ? SafeArea(
                        top: false,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          color: AppColors.canvas,
                          child: FilledButton(
                            onPressed: c.canEnter ? c.enter : null,
                            child: Text(
                              c.busy
                                  ? '正在进入…'
                                  : c.mode == 1
                                  ? '进入 AI 面试'
                                  : '进入等候室',
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
      );
    },
  );
  Widget _notice(String text, {bool error = false}) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: error ? AppColors.warningSoft : AppColors.primarySoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(color: error ? AppColors.body : AppColors.brand),
        ),
      ),
    ),
  );
  Widget _card(List<Widget> children) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  );
  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: AppColors.body)),
        ),
      ],
    ),
  );
  Widget _information() => _card([
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.videocam_outlined, color: AppColors.interactive),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${c.context['positionTitle'] ?? '岗位面试'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '${c.context['companyName'] ?? '企业'}',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
    const Divider(height: 28),
    _row('面试模式', interviewModeLabel(c.mode)),
    _row(
      '开始时间',
      displayBackendDate(c.context['appointmentStartAt']?.toString()),
    ),
    _row('结束时间', displayBackendDate(c.context['appointmentEndAt']?.toString())),
    _row(
      '面试官',
      c.mode == 1 ? 'AI 面试官' : '${c.context['interviewerName'] ?? '待确认'}',
    ),
    if (c.context['roundNo'] != null)
      _row('面试轮次', '第 ${c.context['roundNo']} 轮'),
  ]);
  List<Widget> _preparation() => [
    _card([
      _heading('设备检测'),
      AspectRatio(
        aspectRatio: 16 / 10,
        child: _video(c.media.cameraOn ? c.media.camera : null, '本机画面预览'),
      ),
      const SizedBox(height: AppSpacing.md),
      _checkRow(
        Icons.videocam_outlined,
        '摄像头',
        c.media.cameraOn ? '已开启' : '待授权 / 检测',
        c.media.cameraOn,
      ),
      _checkRow(
        Icons.mic_none,
        '麦克风',
        c.media.microphoneOn ? '已授权' : '待授权 / 检测',
        c.media.microphoneOn,
      ),
      _checkRow(
        Icons.wifi,
        '网络',
        c.networkOk ? '已连接 · ${c.rttMs} ms' : '待检测',
        c.networkOk,
      ),
      if (c.media.error != null) _notice(c.media.error!, error: true),
      if (c.media.blocked)
        TextButton.icon(
          onPressed: openAppSettings,
          icon: const Icon(Icons.settings_outlined),
          label: const Text('打开系统权限设置'),
        ),
      OutlinedButton.icon(
        onPressed: c.checking || c.busy ? null : c.check,
        icon: c.checking
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
        label: Text(c.checking ? '正在检测…' : '检测摄像头、麦克风和网络'),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: c.speakerConfirmed,
        onChanged: c.busy ? null : (v) => c.confirmSpeaker(v == true),
        title: const Text('已确认手机 / 耳机音量正常'),
        subtitle: const Text('请确认媒体音量已打开，能够听到面试官声音。'),
      ),
    ]),
    const SizedBox(height: AppSpacing.lg),
    _card([
      _heading('面试须知'),
      const Text('请在安静、光线充足的环境中独立作答。进入面试前，请关闭占用相机或麦克风的其他应用。'),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: c.consentAccepted,
        onChanged: c.busy ? null : _consent,
        title: const Text('我已阅读并同意面试录制告知'),
        subtitle: const Text('音视频及作答内容将用于招聘评估与合规存档。'),
      ),
      Text(
        c.mode == 1 ? '本场为纯 AI 面试，准备完成后即可开始。' : '准备完成后进入等候室，由面试官开始面试。',
        style: const TextStyle(color: AppColors.muted),
      ),
    ]),
  ];
  Widget _checkRow(IconData icon, String label, String state, bool ok) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.brand),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
            Flexible(
              child: Text(
                state,
                style: TextStyle(color: ok ? AppColors.green : AppColors.muted),
              ),
            ),
          ],
        ),
      );
  Widget _status(IconData icon, String title, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
    child: Column(
      children: [
        Icon(icon, size: 52, color: AppColors.interactive),
        const SizedBox(height: 20),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
      ],
    ),
  );
  Widget _video(lk.VideoTrack? track, String label) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: AppColors.brandDeep,
          child: track == null
              ? const Center(
                  child: Icon(
                    Icons.videocam_off_outlined,
                    color: AppColors.canvas,
                    size: 34,
                  ),
                )
              : lk.VideoTrackRenderer(track, fit: lk.VideoViewFit.cover),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            color: AppColors.ink.withValues(alpha: .65),
            child: Text(
              label,
              style: const TextStyle(color: AppColors.canvas, fontSize: 12),
            ),
          ),
        ),
      ],
    ),
  );
  List<Widget> _result() => [
    _status(Icons.check_circle_outline, '本场面试已结束', '感谢你的参与，请关注 HR 的后续通知。'),
    _card([
      _row('面试时长', _clock(conferenceInt(c.result['durationSeconds']))),
      if (c.mode != 4)
        _row(
          '完成题目',
          '${c.result['answeredCount'] ?? '—'} / ${c.result['totalQuestionNo'] ?? '—'}',
        ),
      _row('面试报告', c.result['reportStatus'] == 'ready' ? '已生成' : '整理中，请稍后查看'),
      TextButton.icon(
        onPressed: c.busy ? null : c.refreshResult,
        icon: const Icon(Icons.refresh),
        label: const Text('刷新结果'),
      ),
    ]),
    const SizedBox(height: 20),
    FilledButton(onPressed: _back, child: const Text('返回消息')),
  ];
}

String _clock(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
