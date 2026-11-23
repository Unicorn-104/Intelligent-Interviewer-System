import 'package:flutter/material.dart';

import '../../../../api/exam_api.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../theme/app_theme.dart';

class JobExamInviteSheet extends StatefulWidget {
  const JobExamInviteSheet({
    super.key,
    required this.positionId,
    required this.candidates,
  });

  final int positionId;
  final List<Map<String, dynamic>> candidates;

  @override
  State<JobExamInviteSheet> createState() => _JobExamInviteSheetState();
}

class _JobExamInviteSheetState extends State<JobExamInviteSheet> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  List<Map<String, dynamic>> _papers = const [];
  int? _paperId;
  late Set<int> _selectedCandidates;
  DateTime _startAt = DateTime.now().add(const Duration(hours: 1));

  @override
  void initState() {
    super.initState();
    _selectedCandidates = {
      for (final row in widget.candidates)
        if (int.tryParse('${row['talId']}') case final int id when id > 0) id,
    };
    _loadPapers();
  }

  Future<void> _loadPapers() async {
    try {
      final papers = (await listExamPapers(positionId: widget.positionId))
          .where((paper) => paper['status'] == 1 || '${paper['status']}' == '1')
          .toList();
      if (!mounted) return;
      setState(() {
        _papers = papers;
        _paperId = papers.isEmpty ? null : int.tryParse('${papers.first['paperId']}');
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException ? error.message : '试卷加载失败，请稍后重试';
      });
    }
  }

  Future<void> _pickStartAt() async {
    final day = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDate: _startAt,
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_startAt));
    if (time == null) return;
    setState(() {
      _startAt = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    });
  }

  String _format(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:00';
  }

  Future<void> _submit() async {
    if (_submitting || _paperId == null || _selectedCandidates.isEmpty) return;
    final paper = _papers.firstWhere((row) => '${row['paperId']}' == '$_paperId');
    final total = double.tryParse('${paper['totalScore']}') ?? 100;
    setState(() => _submitting = true);
    try {
      final scheduleId = await createExamSchedule(
        positionId: widget.positionId,
        paperId: _paperId!,
        startAt: _format(_startAt),
        endAt: _format(_startAt.add(const Duration(hours: 24))),
        passThreshold: (total * .6).clamp(1, total),
      );
      if (scheduleId == null) throw const ApiException('笔试安排创建失败，请重试');
      await sendExamNotify(scheduleId, candidateIds: _selectedCandidates.toList());
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error is ApiException ? error.message : '笔试发起失败，请稍后重试')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: _loading
          ? const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('发起笔试', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                if (_error == null && _papers.isEmpty)
                  const Text('当前岗位没有可用试卷，请先在笔试管理中启用试卷。'),
                if (_papers.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                    initialValue: _paperId,
                    decoration: const InputDecoration(labelText: '选择试卷', border: OutlineInputBorder()),
                    items: [
                      for (final paper in _papers)
                        DropdownMenuItem(
                          value: int.tryParse('${paper['paperId']}'),
                          child: Text('${paper['name'] ?? '未命名试卷'} · ${paper['durationMin'] ?? 0}分钟'),
                        ),
                    ],
                    onChanged: _submitting ? null : (value) => setState(() => _paperId = value),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _pickStartAt,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text('开始时间：${_format(_startAt)}'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(child: Text('选择求职者', style: TextStyle(fontWeight: FontWeight.w700))),
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _selectedCandidates = {
                                  for (final row in widget.candidates)
                                    if (int.tryParse('${row['talId']}') case final int id when id > 0) id,
                                }),
                        child: const Text('全选'),
                      ),
                      TextButton(
                        onPressed: _submitting ? null : () => setState(() => _selectedCandidates.clear()),
                        child: const Text('清空'),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 190,
                    child: ListView(
                      children: [
                        for (final row in widget.candidates)
                          if (int.tryParse('${row['talId']}') case final int id when id > 0)
                            CheckboxListTile(
                              dense: true,
                              value: _selectedCandidates.contains(id),
                              title: Text('${row['name'] ?? '未填写姓名'}'),
                              subtitle: Text('${row['statusLabel'] ?? ''}'),
                              onChanged: _submitting
                                  ? null
                                  : (value) => setState(() {
                                        if (value == true) {
                                          _selectedCandidates.add(id);
                                        } else {
                                          _selectedCandidates.remove(id);
                                        }
                                      }),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _submitting || _selectedCandidates.isEmpty ? null : _submit,
                    child: Text(_submitting ? '发送中…' : '确认并发送笔试链接'),
                  ),
                ],
              ],
            ),
    ),
  );
}
