import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_theme.dart';
import '../models/talent_detail_view_data.dart';
import '../data/talent_detail_data_source.dart';

class InterviewTimeSelection {
  const InterviewTimeSelection({
    required this.start,
    required this.duration,
    required this.interviewerId,
  });
  final DateTime start;
  final int duration;
  final int interviewerId;
}

class TalentInterviewTimeEditor extends StatefulWidget {
  const TalentInterviewTimeEditor({
    super.key,
    required this.appointment,
    required this.people,
    required this.now,
    required this.editable,
    this.draft = false,
    this.initialStart,
    this.initialDuration = 45,
    this.initialInterviewerId,
    this.validateSelection,
  });
  final Map<String, dynamic> appointment;
  final List<Map<String, dynamic>> people;
  final DateTime now;
  final bool editable;
  final bool draft;
  final DateTime? initialStart;
  final int initialDuration;
  final int? initialInterviewerId;
  final Future<void> Function(InterviewTimeSelection)? validateSelection;
  @override
  State<TalentInterviewTimeEditor> createState() =>
      _TalentInterviewTimeEditorState();
}

class _TalentInterviewTimeEditorState extends State<TalentInterviewTimeEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _duration;
  DateTime? _date;
  TimeOfDay? _time;
  int? _interviewer;
  String? _error;
  bool _checking = false;
  @override
  void initState() {
    super.initState();
    final start = widget.draft
        ? widget.initialStart
        : TalentUtc8.parseServer(widget.appointment['startTime']);
    final end = TalentUtc8.parseServer(widget.appointment['endTime']);
    if (start != null) {
      final wall = TalentUtc8.wallTime(start);
      _date = DateTime(wall.year, wall.month, wall.day);
      _time = TimeOfDay(hour: wall.hour, minute: wall.minute);
    }
    _interviewer = widget.draft
        ? widget.initialInterviewerId
        : talentId(widget.appointment['interviewerId']);
    _duration = TextEditingController(
      text: widget.draft
          ? '${widget.initialDuration}'
          : '${end!.difference(start!).inMinutes}',
    );
  }

  @override
  void dispose() {
    _duration.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final wall = TalentUtc8.wallTime(widget.now);
    final today = DateTime(wall.year, wall.month, wall.day);
    final value = await showDatePicker(
      context: context,
      initialDate: _date == null || _date!.isBefore(today) ? today : _date!,
      firstDate: today,
      lastDate: DateTime(today.year + 3),
    );
    if (mounted && value != null) setState(() => _date = value);
  }

  Future<void> _chooseTime() async {
    final wall = TalentUtc8.wallTime(widget.now.add(const Duration(hours: 1)));
    final value = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay(hour: wall.hour, minute: wall.minute),
    );
    if (mounted && value != null) setState(() => _time = value);
  }

  Future<void> _save() async {
    if (_checking || !_form.currentState!.validate() || _interviewer == null) {
      return;
    }
    if (_date == null || _time == null) {
      setState(() => _error = '请选择日期和时间');
      return;
    }
    final start = TalentUtc8.fromSelection(_date!, _time!.hour, _time!.minute);
    if (!start.isAfter(widget.now)) {
      setState(() => _error = '面试时间须晚于当前时间');
      return;
    }
    final selection = InterviewTimeSelection(
      start: start,
      duration: int.parse(_duration.text),
      interviewerId: _interviewer!,
    );
    FocusScope.of(context).unfocus();
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      await widget.validateSelection?.call(selection);
      if (mounted) Navigator.pop(context, selection);
    } catch (error) {
      if (!mounted) return;
      final message = talentError(error);
      setState(() => _error = message);
      if (message.contains('冲突') || message.contains('占用')) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('时间冲突'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('调整时间'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_checking,
    child: AlertDialog(
      backgroundColor: AppColors.canvas,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      title: Row(
        children: [
          Expanded(
            child: Text(widget.appointment['stageName']?.toString() ?? '面试安排'),
          ),
          IconButton(
            key: const Key('invite-stage-close'),
            tooltip: '关闭',
            onPressed: _checking ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: AppColors.textMuted),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: AbsorbPointer(
            absorbing: _checking,
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('候选人：${widget.appointment['candidateName'] ?? '未填写'}'),
                  Text('岗位：${widget.appointment['positionTitle'] ?? '未填写'}'),
                  const SizedBox(height: 12),
                  if (!widget.editable) ...[
                    Text(
                      '时间：${widget.appointment['startTime']} — ${widget.appointment['endTime']}',
                    ),
                    Text(
                      '面试官：${widget.appointment['interviewerName'] ?? '未填写'}',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '该面试已开始、已完成或已取消，仅可查看',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ] else ...[
                    DropdownButtonFormField<int>(
                      key: Key(
                        widget.draft
                            ? 'invite-interviewer'
                            : 'appointment-edit-interviewer',
                      ),
                      initialValue:
                          widget.people.any(
                            (row) => talentId(row['userId']) == _interviewer,
                          )
                          ? _interviewer
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '面试官'),
                      items: widget.people
                          .map(
                            (row) => DropdownMenuItem(
                              value: talentId(row['userId']),
                              child: Text(
                                widget.draft
                                    ? [
                                            talentText(row['userName']),
                                            talentText(row['department'], ''),
                                            talentText(row['jobTitle'], ''),
                                          ]
                                          .where((part) => part.isNotEmpty)
                                          .join(' · ')
                                    : talentText(row['userName']),
                              ),
                            ),
                          )
                          .toList(),
                      validator: (value) => value == null ? '请选择面试官' : null,
                      onChanged: (value) =>
                          setState(() => _interviewer = value),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          key: Key(
                            widget.draft
                                ? 'invite-date'
                                : 'appointment-edit-date',
                          ),
                          onPressed: _chooseDate,
                          child: Text(
                            _date == null
                                ? '选择日期'
                                : TalentUtc8.dateLabel(_date!),
                          ),
                        ),
                        OutlinedButton(
                          key: Key(
                            widget.draft
                                ? 'invite-time'
                                : 'appointment-edit-time',
                          ),
                          onPressed: _chooseTime,
                          child: Text(
                            _time == null
                                ? '选择时间'
                                : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (widget.draft)
                      DropdownButtonFormField<int>(
                        key: const Key('invite-duration'),
                        initialValue: int.parse(_duration.text),
                        decoration: const InputDecoration(labelText: '时长'),
                        items:
                            ({
                                  30,
                                  45,
                                  60,
                                  90,
                                  120,
                                  widget.initialDuration,
                                }.toList()..sort())
                                .map(
                                  (minutes) => DropdownMenuItem(
                                    value: minutes,
                                    child: Text('$minutes 分钟'),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) _duration.text = '$value';
                        },
                      )
                    else
                      TextFormField(
                        key: const Key('appointment-edit-duration'),
                        controller: _duration,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(labelText: '时长（分钟）'),
                        validator: (value) {
                          final minutes = int.tryParse(value ?? '');
                          return minutes == null ||
                                  minutes < 1 ||
                                  minutes > 1440
                              ? '请输入1至1440分钟'
                              : null;
                        },
                      ),
                    if (_checking)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('正在检查面试官忙闲'),
                      ),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                      if (widget.draft)
                        TextButton(
                          onPressed: _checking ? null : _save,
                          child: const Text('重试查询忙闲'),
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: Key(
            widget.draft ? 'invite-stage-cancel' : 'appointment-edit-cancel',
          ),
          onPressed: _checking ? null : () => Navigator.pop(context),
          child: Text(widget.editable ? '取消' : '关闭'),
        ),
        if (widget.editable)
          FilledButton(
            key: Key(
              widget.draft ? 'invite-stage-save' : 'appointment-edit-save',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: _checking ? null : _save,
            child: Text(
              _checking
                  ? '检查中…'
                  : widget.draft
                  ? '保存设置'
                  : '保存调整',
            ),
          ),
      ],
    ),
  );
}
