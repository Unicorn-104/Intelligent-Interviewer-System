import 'package:flutter/material.dart';

import '../../../api/interview_room_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/skeleton_list.dart';
import 'recording_playback_page.dart';

/// 模块五：面试执行与级联评估 - 面试回放页（P4）。
///
/// 参考 Web 端「录制回放与存储管理」（enterprise_pc records.vue）设计，
/// 接入真实后端接口，展示真实数据：
/// - GET /system/conference/recordings            录制文件列表
/// - GET /system/conference/recordings/storage    存储空间占用
/// - GET /system/conference/storage-policy        存储保留策略
/// - GET /system/conference/recordings/{id}       录制详情（面试官/时间轴打点/录制地址）
///
/// 说明：App 内暂未接入视频播放器，回放能力通过「录制详情」底部弹层展示
/// 录制地址与时间轴打点；下载走真实下载码流程。
class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  List<Map<String, dynamic>>? _recordings;
  Map<String, dynamic>? _storageUsage;
  Map<String, dynamic>? _storagePolicy;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 并行加载录制列表、存储占用与存储策略。
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        listRecordings(),
        getStorageUsage(),
        getStoragePolicy(),
      ]);
      if (!mounted) return;
      setState(() {
        _recordings = results[0] as List<Map<String, dynamic>>;
        _storageUsage = results[1] as Map<String, dynamic>;
        _storagePolicy = results[2] as Map<String, dynamic>;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  /// 打开录制详情底部弹层（真实数据：面试官/时间轴打点/录制地址/访问级别）。
  Future<void> _showDetail(Map<String, dynamic> item) async {
    final recordingId = _asInt(item['recordingId']);
    if (recordingId <= 0) {
      _toast('该记录缺少录制编号');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _RecordingDetailSheet(recordingId: recordingId),
    );
  }

  /// 申请下载码并下载（真实接口，与 Web 端一致走二次验证）。
  Future<void> _download(Map<String, dynamic> item) async {
    final recordingId = _asInt(item['recordingId']);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await requestRecordingDownloadCode(recordingId);
      if (!mounted) return;
      final codeCtrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('输入下载码'),
          content: TextField(
            controller: codeCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '请输入收到的下载码'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认下载'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await downloadRecording(recordingId, {'code': codeCtrl.text.trim()});
      messenger.showSnackBar(
        const SnackBar(content: Text('下载链接已发送，请查收')),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  /// 打开录制在线回放页（真实录制文件，参考 Web 端「在线回放」）。
  void _openPlayback(Map<String, dynamic> item) {
    final recordingId = _asInt(item['recordingId']);
    if (recordingId <= 0) {
      _toast('该记录缺少录制编号');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecordingPlaybackPage(recordingId: recordingId),
      ),
    );
  }

  /// 仅「已完成」的录制可回放（对齐 Web 端 `item.status !== '已完成'` 的禁用逻辑）。
  bool _canPlay(Map<String, dynamic> item) => _asInt(item['status']) == 1;

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('录播回放')),
      body: _loading
          ? const SkeletonList(rows: 4)
          : _error != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _storageCard(),
                      const SizedBox(height: 8),
                      if (_recordings == null || _recordings!.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: Text('暂无面试录制记录')),
                        )
                      else
                        for (final item in _recordings!) _recordingCard(item),
                    ],
                  ),
                ),
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

  /// 存储空间占用卡片（参考 Web 端存储区域）。
  Widget _storageCard() {
    final usedGb = _num(_storageUsage?['usedGb']).toDouble();
    final maxGb = _num(_storageUsage?['maxGb']).toDouble();
    final percent = _num(_storageUsage?['percent']).toDouble();
    final keepDays = _text(
      _storagePolicy?['keepDays'] ?? _storageUsage?['keepDays'],
      fallback: '90',
    );
    final ratio = maxGb > 0 ? (usedGb / maxGb).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cloud_outlined,
                size: 18,
                color: AppColors.interactive,
              ),
              const SizedBox(width: 8),
              const Text(
                '存储空间',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '保留 $keepDays 天',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: AppColors.background,
              color: AppColors.interactive,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '已用 ${_formatStorage(usedGb)} / ${_formatStorage(maxGb)}'
            ' · 使用率 ${percent.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 12, color: AppColors.bodySoft),
          ),
        ],
      ),
    );
  }

  /// 单条录制卡片（候选人与岗位、状态、面试ID、时长/占用/模式、操作）。
  Widget _recordingCard(Map<String, dynamic> item) {
    final (statusText, statusColor) = _statusBadge(item['status']);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item['candidateName'] ?? '—'} · ${item['positionTitle'] ?? '—'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _pill(statusText, statusColor),
            ],
          ),
          const SizedBox(height: 6),
          _metaLine('面试ID：${_text(item['code'])}'),
          const SizedBox(height: 2),
          _metaLine(
            '${_text(item['interviewDate'])}'
            ' · ${_formatDuration(item['durationSec'])}'
            ' · ${_formatSize(item['recSizeBytes'])}'
            ' · ${_modeText(item['mode'])}',
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            runSpacing: 4,
            children: [
              // 回放：主操作，蓝底白字，对齐网页端「回放」入口（仅已完成可点）。
              FilledButton.icon(
                onPressed: _canPlay(item) ? () => _openPlayback(item) : null,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('回放'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.interactive,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              // 下载：次要操作，蓝描边白底、蓝字。
              OutlinedButton.icon(
                onPressed: () => _download(item),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('下载'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.interactive,
                  side: const BorderSide(color: AppColors.interactive),
                  minimumSize: const Size(0, 34),
                ),
              ),
              // 查看详情：文字按钮，蓝字。
              TextButton.icon(
                onPressed: () => _showDetail(item),
                icon: const Icon(Icons.info_outline, size: 16),
                label: const Text('查看详情'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.interactive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    ),
  );

  Widget _metaLine(String text) => Text(
    text,
    style: const TextStyle(fontSize: 12, color: AppColors.bodySoft),
  );

  // ==================== 格式化工具 ====================

  static int _asInt(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  static num _num(Object? value) => value is num ? value : 0;

  static String _text(Object? value, {String fallback = '—'}) {
    if (value == null) return fallback;
    final s = '$value'.trim();
    return s.isEmpty ? fallback : s;
  }

  static (String, Color) _statusBadge(Object? status) {
    switch (_asInt(status)) {
      case 0:
        return ('录制中', AppColors.warning);
      case 1:
        return ('已完成', AppColors.success);
      case 2:
        return ('异常终止', AppColors.error);
      default:
        return ('已完成', AppColors.muted);
    }
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

  static String _formatDuration(Object? seconds) {
    final sec = _asInt(seconds);
    if (sec <= 0) return '—';
    final min = sec ~/ 60;
    if (min < 60) return '$min 分钟';
    final hour = min ~/ 60;
    final remain = min % 60;
    return remain > 0 ? '$hour 小时 $remain 分钟' : '$hour 小时';
  }

  static String _formatSize(Object? bytes) {
    final b = _asInt(bytes);
    if (b <= 0) return '—';
    final mb = b / 1024 / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(0)} MB';
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }

  static String _formatStorage(double gb) {
    if (gb >= 1) return '${gb.toStringAsFixed(1)} GB';
    final mb = gb * 1024;
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb * 1024).round()} KB';
  }
}

/// 录制详情底部弹层：进入后按 recordingId 拉取真实详情。
class _RecordingDetailSheet extends StatefulWidget {
  const _RecordingDetailSheet({required this.recordingId});
  final int recordingId;

  @override
  State<_RecordingDetailSheet> createState() => _RecordingDetailSheetState();
}

class _RecordingDetailSheetState extends State<_RecordingDetailSheet> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

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
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                '录制详情',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Column(
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _load, child: const Text('重试')),
                ],
              )
            else
              Flexible(child: _detailBody(_detail!)),
          ],
        ),
      ),
    );
  }

  Widget _detailBody(Map<String, dynamic> detail) {
    final interviewers = (detail['interviewers'] as List?)
            ?.map((e) => _text((e as Map)['userName']))
            .where((s) => s != '—')
            .toList() ??
        const <String>[];
    final chapters = (detail['chapters'] as List?) ?? const <dynamic>[];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field('候选人', _text(detail['candidateName'])),
          _field('岗位', _text(detail['positionTitle'])),
          _field('面试日期', _text(detail['interviewDate'])),
          _field(
            '录制时长',
            _RecordingPageState._formatDuration(detail['durationSec']),
          ),
          _field(
            '文件占用',
            _RecordingPageState._formatSize(detail['recSizeBytes']),
          ),
          _field('面试模式', _RecordingPageState._modeText(detail['mode'])),
          _field('访问级别', _accessText(detail['recAccessLevel'])),
          _field('授权有效期', _text(detail['recExpiresAt'])),
          _field(
            '面试官',
            interviewers.isEmpty ? '—' : interviewers.join('、'),
          ),
          _field('录制地址', _text(detail['recUrl'])),
          if (chapters.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              '时间轴打点',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            for (final c in chapters.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${_RecordingPageState._formatDuration((c as Map)['second'])}'
                  '  ${_text(c['title'])}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.bodySoft,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
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

  static String _text(Object? value) {
    if (value == null) return '—';
    final s = '$value'.trim();
    return s.isEmpty ? '—' : s;
  }

  static String _accessText(Object? level) {
    switch (int.tryParse('$level') ?? 0) {
      case 1:
        return '仅HR/面试官';
      case 2:
        return '含管理员';
      case 3:
        return '候选人可见';
      default:
        return '—';
    }
  }
}
