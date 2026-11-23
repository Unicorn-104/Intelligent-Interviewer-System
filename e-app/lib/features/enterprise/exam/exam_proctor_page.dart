import 'dart:async';

import 'package:flutter/material.dart';

import '../../../api/exam_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';

class ExamProctorPage extends StatefulWidget {
  const ExamProctorPage({super.key});

  @override
  State<ExamProctorPage> createState() => _ExamProctorPageState();
}

class _ExamProctorPageState extends State<ExamProctorPage> {
  Timer? _timer;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final rows = await listOngoingExams();
      if (mounted) setState(() => _rows = rows);
    } catch (error) {
      if (mounted && !silent) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('监控监考'),
      backgroundColor: AppColors.canvas,
      actions: [
        IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh, color: AppColors.interactive)),
        const SizedBox(width: 6),
      ],
    ),
    body: _loading
        ? const SkeletonList(rows: 4)
        : _error != null
        ? PageMessage(icon: Icons.shield_outlined, title: '监考列表加载失败', message: _error!, onAction: _load)
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (_rows.isEmpty) _empty() else for (final row in _rows) _row(row),
              ],
            ),
          ),
  );

  Widget _row(Map<String, dynamic> row) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.hairline)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleAvatar(backgroundColor: AppColors.primarySoft, child: Text(_text(row['candidateName'], '?').characters.first, style: const TextStyle(color: AppColors.interactive))),
            const SizedBox(width: 10),
            Expanded(child: Text(_text(row['candidateName'], '未命名考生'), style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w700))),
            _tag(row['subOnline'] == true || _int(row['subOnline']) == 1 ? '副机位在线' : '副机位未接入'),
          ],
        ),
        const SizedBox(height: 10),
        Text('${_text(row['positionTitle'], '未填写岗位')} · ${_text(row['paperName'], '未填写试卷')}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text('开考：${_format(row['startAt'])}  截止：${_format(row['deadlineAt'])}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showDetails(row),
          icon: const Icon(Icons.shield_outlined, size: 17),
          label: const Text('查看监考状态'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.interactive),
        ),
      ],
    ),
  );

  Widget _tag(Object? value) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(999)), child: Text('$value', style: const TextStyle(color: AppColors.interactive, fontSize: 10)));
  Widget _empty() => const Padding(padding: EdgeInsets.symmetric(vertical: 90), child: Column(children: [Icon(Icons.video_camera_front_outlined, size: 40, color: AppColors.textMuted), SizedBox(height: 12), Text('当前没有进行中的笔试', style: TextStyle(color: AppColors.textMuted))]));
  String _text(Object? value, String fallback) { final text = value?.toString().trim() ?? ''; return text.isEmpty ? fallback : text; }
  int? _int(Object? value) => int.tryParse('$value');
  String _format(Object? value) => value == null ? '--' : value.toString().replaceFirst('T', ' ').substring(0, value.toString().length > 16 ? 16 : value.toString().length);
  String _friendlyError(Object error) => error is ApiException ? error.message : '请求失败，请稍后重试';

  Future<void> _showDetails(Map<String, dynamic> row) async {
    await showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('监考状态'), content: Text('考生：${_text(row['candidateName'], '未填写')}\n副机位：${row['subOnline'] == true || _int(row['subOnline']) == 1 ? '在线' : '未接入'}\n双机位要求：${_int(row['forceDualCamera']) == 1 ? '强制开启' : '不强制'}'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))]));
  }
}
