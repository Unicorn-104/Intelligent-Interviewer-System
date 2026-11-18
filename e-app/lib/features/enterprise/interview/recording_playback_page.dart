import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../api/interview_room_api.dart';
import '../../../config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/resource_url.dart';
import '../../../theme/app_theme.dart';

/// 模块五：面试录播在线回放页。
///
/// 参考 Web 端「在线回放」（enterprise_pc playback.vue）设计：
/// - 进入后按 recordingId 拉取真实录制详情（recUrl / chapters / 面试信息）；
/// - 用 video_player 播放后端返回的 mp4 录制文件；
/// - 提供播放/暂停、进度拖动、问答时间线点击跳转。
///
/// 说明：录制文件为 mp4，recUrl 是后端相对路径（/profile/upload/recording/...），
/// 通过 resolveResourceUrl 拼上 AppConfig.apiBaseUrl 得到可播放的完整地址。
class RecordingPlaybackPage extends StatefulWidget {
  const RecordingPlaybackPage({super.key, required this.recordingId});

  final int recordingId;

  @override
  State<RecordingPlaybackPage> createState() => _RecordingPlaybackPageState();
}

class _RecordingPlaybackPageState extends State<RecordingPlaybackPage> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  String? _error;

  VideoPlayerController? _controller;
  bool _videoReady = false;
  bool _videoFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // 释放播放器资源，避免页面退出后仍占用解码器。
    _controller?.dispose();
    super.dispose();
  }

  /// 先拉取录制详情，再据此初始化视频播放器。
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await getRecordingDetail(widget.recordingId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
      await _initVideo(detail['recUrl']);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  /// 拼接录制地址并初始化视频播放器；无地址或初始化失败时降级为占位提示。
  Future<void> _initVideo(Object? recUrl) async {
    final resolved = resolveResourceUrl(
      recUrl?.toString(),
      apiBaseUrl: AppConfig.apiBaseUrl,
    );
    if (resolved == null || resolved.isEmpty) {
      setState(() => _videoFailed = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(resolved));
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() => _videoReady = true);
      controller.addListener(_onVideoTick);
    } catch (_) {
      if (!mounted) return;
      setState(() => _videoFailed = true);
    }
  }

  /// 播放器状态变化（进度/播放态）时刷新进度条与按钮。
  void _onVideoTick() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _seekTo(Duration position) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.seekTo(position);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        title: const Text(
          '在线回放',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _body(_detail!),
    );
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: _load, child: const Text('重试')),
        ],
      ),
    ),
  );

  Widget _body(Map<String, dynamic> detail) {
    final chapters = (detail['chapters'] as List?) ?? const <dynamic>[];
    final duration = _controller?.value.duration ?? Duration.zero;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _player(),
        const SizedBox(height: 16),
        _infoCard(detail),
        if (chapters.isNotEmpty) ...[
          const SizedBox(height: 12),
          _timelineCard(chapters, duration),
        ],
      ],
    );
  }

  /// 视频播放器区域（画面 + 底部控制条）。
  Widget _player() {
    final controller = _controller;
    final value = controller?.value;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: _videoReady && value != null && value.aspectRatio > 0
            ? value.aspectRatio
            : 16 / 9,
        child: Container(
          color: const Color(0xFF0B0F18),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_videoReady && value != null)
                VideoPlayer(controller!)
              else
                _noVideo(),
              if (_videoReady && value != null) _controls(controller!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noVideo() => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        _videoFailed ? '录制文件加载失败（可能已过期或外链失效）' : '该场次暂无录制文件',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF8FA1BD), fontSize: 13),
      ),
    ),
  );

  Widget _controls(VideoPlayerController controller) {
    final value = controller.value;
    final duration = value.duration;
    final position = value.position;
    final maxMs = duration.inMilliseconds;
    final curMs = position.inMilliseconds.clamp(0, maxMs > 0 ? maxMs : 1);
    final progress = maxMs > 0 ? curMs / maxMs : 0.0;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x000B0F18), Color(0xE60B0F18)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: AppColors.interactive,
                inactiveTrackColor: const Color(0x4DFFFFFF),
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChanged: (v) async {
                  if (maxMs <= 0) return;
                  await _seekTo(
                    Duration(milliseconds: (v * maxMs).round()),
                  );
                },
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: _togglePlay,
                  icon: Icon(
                    value.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                Text(
                  '${_fmt(position)} / ${_fmt(duration)}',
                  style: const TextStyle(
                    color: Color(0xFFCFD8E6),
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(Map<String, dynamic> detail) {
    final interviewers = (detail['interviewers'] as List?)
            ?.map((e) => _text((e as Map)['userName']))
            .where((s) => s != '—')
            .toList() ??
        const <String>[];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_text(detail['candidateName'])} · ${_text(detail['positionTitle'])}',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _row('面试时间', _text(detail['interviewDate'])),
          _row('面试模式', _modeText(detail['mode'])),
          _row('面试官', interviewers.isEmpty ? '—' : interviewers.join('、')),
          _row('录制编号', _text(detail['code'])),
        ],
      ),
    );
  }

  Widget _timelineCard(List<dynamic> chapters, Duration duration) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '问答时间线',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final c in chapters.take(10))
            _chapterTile(c as Map, duration),
        ],
      ),
    );
  }

  Widget _chapterTile(Map chapter, Duration duration) {
    final second = _asInt(chapter['second']);
    final title = _text(chapter['title']);
    return InkWell(
      onTap: () async {
        if (second <= 0) return;
        await _seekTo(Duration(seconds: second));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Text(
                _fmt(Duration(seconds: second)),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 13, color: AppColors.body),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: AppColors.body),
          ),
        ),
      ],
    ),
  );

  // ==================== 工具函数 ====================

  static int _asInt(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  static String _text(Object? value) {
    if (value == null) return '—';
    final s = '$value'.trim();
    return s.isEmpty ? '—' : s;
  }

  static String _modeText(Object? mode) {
    switch (_asInt(mode)) {
      case 1:
        return 'AI 面试';
      case 2:
        return 'AI+单面试官';
      case 3:
        return 'AI+多面试官';
      case 4:
        return '纯人工面试';
      default:
        return '面试';
    }
  }

  /// 播放器时间展示（mm:ss），与 Web 端一致。
  static String _fmt(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
