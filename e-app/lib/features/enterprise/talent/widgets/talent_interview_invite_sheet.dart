import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../theme/app_theme.dart';
import '../data/talent_detail_data_source.dart';
import '../models/talent_detail_view_data.dart';
import 'talent_interview_week_calendar.dart';
import 'talent_interview_time_editor.dart';

class TalentInterviewInviteSheet extends StatefulWidget {
  const TalentInterviewInviteSheet({
    super.key,
    required this.candidateId,
    required this.candidateName,
    required this.source,
    this.job,
    this.clock,
  });
  final int candidateId;
  final String candidateName;
  final TalentDetailDataSource source;
  final TalentJobContext? job;
  final DateTime Function()? clock;
  @override
  State<TalentInterviewInviteSheet> createState() =>
      _TalentInterviewInviteSheetState();
}

class _StageDraft {
  _StageDraft({required this.name, required this.duration, this.stageId});
  final String name;
  final int? stageId;
  int duration;
  int? interviewerId;
  DateTime? date;
  TimeOfDay? time;
  Map<String, dynamic>? appointment;
  DateTime? get start => date == null || time == null
      ? null
      : TalentUtc8.fromSelection(date!, time!.hour, time!.minute);
  bool get ready => interviewerId != null && start != null;
  Map<String, Object?> get payload => {
    'stageId': stageId,
    'interviewerId': interviewerId,
    'startTime': TalentUtc8.serverTime(start!),
    'durationMin': duration,
  };
}

class _TalentInterviewInviteSheetState
    extends State<TalentInterviewInviteSheet> {
  List<Map<String, dynamic>> _people = [], _jobs = [], _calendar = [];
  List<_StageDraft> _stages = [];
  int? _positionId;
  int _selected = 0, _jobPage = 0, _workflowRequest = 0, _calendarRequest = 0;
  bool _loadingPeople = true,
      _loadingJobs = false,
      _loadingWorkflow = false,
      _loadingCalendar = false,
      _stageEditorOpen = false,
      _saving = false,
      _uncertain = false,
      _moreJobs = false,
      _changed = false;
  String? _peopleError,
      _jobsError,
      _workflowError,
      _calendarError,
      _submitError;
  bool? _busy;
  late DateTime _week;
  _StageDraft? get _current => _stages.isEmpty ? null : _stages[_selected];
  bool get _locked => _saving || _uncertain || _stageEditorOpen;
  DateTime _now() => (widget.clock?.call() ?? DateTime.now()).toUtc();
  DateTime _monday(DateTime day) => DateTime(
    day.year,
    day.month,
    day.day,
  ).subtract(Duration(days: day.weekday - 1));

  @override
  void initState() {
    super.initState();
    _week = _monday(TalentUtc8.wallTime(_now()));
    _positionId = widget.job?.positionId;
    _loadPeople();
    if (_positionId != null) {
      _loadWorkflow(_positionId!);
    } else {
      _loadJobs();
    }
  }

  Future<void> _loadPeople() async {
    setState(() {
      _loadingPeople = true;
      _peopleError = null;
    });
    try {
      final rows = await widget.source.loadInterviewers();
      if (mounted) setState(() => _people = rows);
    } catch (error) {
      if (mounted) setState(() => _peopleError = talentError(error));
    } finally {
      if (mounted) setState(() => _loadingPeople = false);
    }
  }

  Future<void> _loadJobs() async {
    if (_loadingJobs) return;
    setState(() {
      _loadingJobs = true;
      _jobsError = null;
    });
    try {
      final rows = await widget.source.loadJobs(pageNum: _jobPage + 1);
      if (rows.any((row) => talentId(row['posId']) == null)) {
        throw const FormatException('岗位标识无效');
      }
      if (!mounted) return;
      setState(() {
        final seen = <int>{};
        _jobs = [
          ..._jobs,
          ...rows,
        ].where((row) => seen.add(talentId(row['posId'])!)).toList();
        _jobPage++;
        _moreJobs = rows.length == 20;
      });
    } catch (error) {
      if (mounted) setState(() => _jobsError = talentError(error));
    } finally {
      if (mounted) setState(() => _loadingJobs = false);
    }
  }

  Future<void> _loadWorkflow(int positionId) async {
    final request = ++_workflowRequest;
    setState(() {
      _loadingWorkflow = true;
      _workflowError = null;
      _stages = [];
      _selected = 0;
      _busy = null;
      _submitError = null;
    });
    try {
      final responses = await Future.wait([
        widget.source.loadWorkflow(positionId),
        widget.source.loadCandidatePlan(widget.candidateId, positionId),
      ]);
      final workflow = responses[0] as Map<String, dynamic>;
      final existing = responses[1] as List<Map<String, dynamic>>;
      final stages = <_StageDraft>[];
      for (final row in talentRows(workflow['stages'], '招聘流程')) {
        final id = talentId(row['stageId']);
        if (id == null) throw const FormatException('招聘阶段缺少ID，请刷新流程');
        final raw = row['configJson'];
        final config = raw is String && raw.isNotEmpty ? jsonDecode(raw) : raw;
        final duration = config is Map
            ? int.tryParse('${config['duration']}') ?? 45
            : 45;
        if (duration < 1 || duration > 1440) {
          throw const FormatException('招聘阶段时长无效');
        }
        stages.add(
          _StageDraft(
            stageId: id,
            name: talentText(row['name']),
            duration: duration,
          ),
        );
      }
      if (stages.isEmpty) {
        stages.add(
          _StageDraft(name: widget.job?.currentStage ?? '面试阶段', duration: 45),
        );
      }
      for (final stage in stages) {
        final matches = existing
            .where((row) => talentId(row['stageId']) == stage.stageId)
            .toList();
        if (matches.isNotEmpty) stage.appointment = matches.last;
      }
      if (!mounted || request != _workflowRequest) return;
      setState(() => _stages = stages);
      await _loadCalendar();
    } catch (error) {
      if (mounted && request == _workflowRequest) {
        setState(() => _workflowError = talentError(error));
      }
    } finally {
      if (mounted && request == _workflowRequest) {
        setState(() => _loadingWorkflow = false);
      }
    }
  }

  Future<void> _loadCalendar() async {
    final request = ++_calendarRequest;
    final week = _week;
    setState(() {
      _loadingCalendar = true;
      _calendarError = null;
    });
    try {
      final collected = <int, Map<String, dynamic>>{};
      for (var page = 1; ; page++) {
        final rows = await widget.source.loadInterviews(
          pageNum: page,
          pageSize: 100,
          from: TalentUtc8.serverTime(TalentUtc8.fromSelection(week, 0, 0)),
          to: TalentUtc8.serverTime(
            TalentUtc8.fromSelection(week.add(const Duration(days: 7)), 0, 0),
          ),
        );
        if (!mounted || request != _calendarRequest) return;
        var added = 0;
        for (final row in rows) {
          final id = talentId(row['appointmentId']);
          final start = TalentUtc8.parseServer(row['startTime']);
          final end = TalentUtc8.parseServer(row['endTime']);
          if (id == null ||
              start == null ||
              end == null ||
              !end.isAfter(start)) {
            throw const FormatException('面试日历数据不完整，请刷新');
          }
          if (!collected.containsKey(id)) added++;
          collected[id] = row;
        }
        if (rows.length < 100) break;
        if (added == 0 || page >= 200) {
          throw const FormatException('日历分页异常，请缩小范围后重试');
        }
      }
      setState(() => _calendar = collected.values.toList());
    } catch (error) {
      if (mounted && request == _calendarRequest) {
        setState(() {
          _calendar = [];
          _calendarError = talentError(error);
        });
      }
    } finally {
      if (mounted && request == _calendarRequest) {
        setState(() => _loadingCalendar = false);
      }
    }
  }

  Future<void> _editStage(int index, {DateTime? suggestedStart}) async {
    if (_locked || _loadingPeople || _loadingWorkflow || _people.isEmpty) {
      return;
    }
    final stage = _stages[index];
    setState(() => _selected = index);
    if (stage.appointment != null) {
      await _openAppointment(stage.appointment!);
      return;
    }
    setState(() => _stageEditorOpen = true);
    try {
      final selection = await showDialog<InterviewTimeSelection>(
        context: context,
        barrierDismissible: false,
        builder: (_) => TalentInterviewTimeEditor(
          draft: true,
          appointment: {
            'stageName': stage.name,
            'candidateName': widget.candidateName,
            'positionTitle':
                widget.job?.title ??
                talentText(
                  _jobs.firstWhere(
                    (row) => talentId(row['posId']) == _positionId,
                  )['title'],
                ),
          },
          people: _people,
          now: _now(),
          editable: true,
          initialStart: suggestedStart ?? stage.start,
          initialDuration: stage.duration,
          initialInterviewerId: stage.interviewerId,
          validateSelection: (value) async {
            final end = value.start.add(Duration(minutes: value.duration));
            final slots = await widget.source.loadAvailability(
              value.interviewerId,
              to: TalentUtc8.serverTime(end),
            );
            if (TalentUtc8.isBusy(slots, value.start, end)) {
              throw const ApiException('所选时段面试官已被占用');
            }
          },
        ),
      );
      if (!mounted || selection == null) return;
      final wall = TalentUtc8.wallTime(selection.start);
      setState(() {
        stage.interviewerId = selection.interviewerId;
        stage.date = DateTime(wall.year, wall.month, wall.day);
        stage.time = TimeOfDay(hour: wall.hour, minute: wall.minute);
        stage.duration = selection.duration;
        _week = _monday(stage.date!);
        _busy = false;
        _submitError = null;
      });
      await _loadCalendar();
    } finally {
      if (mounted) setState(() => _stageEditorOpen = false);
    }
  }

  Future<void> _showConflict([String message = '所选时间与已有面试安排冲突，请调整面试时间']) =>
      showDialog<void>(
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

  Future<void> _submit() async {
    if (_locked || _positionId == null || _workflowError != null) return;
    final pending = _stages
        .where((stage) => stage.appointment == null)
        .toList();
    if (pending.isEmpty) {
      Navigator.pop(context, _changed);
      return;
    }
    if (pending.any((stage) => !stage.ready)) {
      setState(() => _submitError = '请分别设置每个阶段的面试官、日期和时间');
      return;
    }
    DateTime? previousEnd;
    for (final stage in _stages) {
      final start = stage.appointment == null
          ? stage.start
          : TalentUtc8.parseServer(stage.appointment!['startTime']);
      final end = stage.appointment == null
          ? start?.add(Duration(minutes: stage.duration))
          : TalentUtc8.parseServer(stage.appointment!['endTime']);
      if (start == null || end == null) continue;
      if (stage.appointment == null && !start.isAfter(_now())) {
        setState(() => _submitError = '面试时间须晚于当前时间（UTC+8）');
        return;
      }
      if (previousEnd != null && start.isBefore(previousEnd)) {
        await _showConflict('各阶段须按招聘流程先后安排，后一阶段不能早于前一阶段结束时间');
        return;
      }
      previousEnd = end;
    }
    final positionTitle =
        widget.job?.title ??
        talentText(
          _jobs.firstWhere(
            (row) => talentId(row['posId']) == _positionId,
          )['title'],
        );
    final single = pending.length == 1 && pending.first.stageId == null;
    final stage = pending.first;
    final person = _people.firstWhere(
      (row) => talentId(row['userId']) == stage.interviewerId,
    );
    final description = single
        ? '候选人：${widget.candidateName}\n岗位：$positionTitle\n面试官：${talentText(person['userName'])}\n时间：${TalentUtc8.serverTime(stage.start!).substring(0, 16)}（UTC+8）\n时长：${stage.duration} 分钟'
        : '候选人：${widget.candidateName}\n岗位：$positionTitle\n\n${pending.map((item) => '${item.name}\n${TalentUtc8.serverTime(item.start!).substring(0, 16)} · ${item.duration}分钟').join('\n\n')}';
    setState(() {
      _saving = true;
      _submitError = null;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('确认发送面试邀约？'),
          content: SingleChildScrollView(child: Text(description)),
          actions: [
            TextButton(
              key: const Key('invite-confirm-cancel'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            TextButton(
              key: const Key('invite-confirm-send'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确认发送'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      for (final item in pending) {
        final end = item.start!.add(Duration(minutes: item.duration));
        final rows = await widget.source.loadAvailability(
          item.interviewerId!,
          to: TalentUtc8.serverTime(end),
        );
        if (!mounted) return;
        if (TalentUtc8.isBusy(rows, item.start!, end)) {
          setState(() {
            _busy = true;
            _submitError = '所选时段面试官已被占用，请调整时间';
          });
          await _showConflict();
          return;
        }
      }
      final List<Map<String, dynamic>> results;
      try {
        results = single
            ? [
                await widget.source.invite(
                  candidateId: widget.candidateId,
                  positionId: _positionId!,
                  interviewerId: stage.interviewerId!,
                  startTime: TalentUtc8.serverTime(stage.start!),
                  durationMin: stage.duration,
                ),
              ]
            : await widget.source.inviteStages(
                candidateId: widget.candidateId,
                positionId: _positionId!,
                stages: pending.map((item) => item.payload).toList(),
              );
      } on ApiException catch (error) {
        if (error.code != null ||
            error.message.contains('冲突') ||
            error.message.contains('占用')) {
          rethrow;
        }
        if (mounted) {
          setState(() {
            _uncertain = true;
            _submitError = '邀约结果暂时无法确认，请关闭并检查面试安排，避免重复邀约';
          });
        }
        return;
      } catch (_) {
        if (mounted) {
          setState(() {
            _uncertain = true;
            _submitError = '邀约结果暂时无法确认，请关闭并检查面试安排，避免重复邀约';
          });
        }
        return;
      }
      if (!mounted) return;
      if (results.length != pending.length ||
          results.any((row) => talentId(row['appointmentId']) == null) ||
          (!single &&
              (results.map((row) => talentId(row['stageId'])).toSet().length !=
                      pending.length ||
                  results.any(
                    (row) => !pending.any(
                      (stage) => stage.stageId == talentId(row['stageId']),
                    ),
                  )))) {
        setState(() {
          _uncertain = true;
          _submitError = '服务已响应但未返回预约编号，请关闭并检查面试安排，避免重复邀约';
        });
        return;
      }
      _changed = true;
      if (single) {
        Navigator.pop(context, true);
        return;
      }
      for (final row in results) {
        final item = pending.firstWhere(
          (stage) => stage.stageId == talentId(row['stageId']),
        );
        item.appointment = {
          ...row,
          'candidateName': widget.candidateName,
          'positionTitle': positionTitle,
        };
      }
      setState(() => _submitError = null);
      await _loadCalendar();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('各阶段面试已安排成功')));
      }
    } catch (error) {
      if (!mounted) return;
      final message = talentError(error);
      setState(() => _submitError = message);
      if (message.contains('冲突') || message.contains('占用')) {
        await _showConflict(message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _editable(Map<String, dynamic> row) {
    final status = int.tryParse('${row['status']}');
    final start = TalentUtc8.parseServer(row['startTime']);
    return (status == 0 || status == 1) &&
        start != null &&
        start.isAfter(_now());
  }

  Future<void> _openAppointment(Map<String, dynamic> row) async {
    if (_locked) return;
    final selection = await showDialog<InterviewTimeSelection>(
      context: context,
      builder: (_) => TalentInterviewTimeEditor(
        appointment: row,
        people: _people,
        now: _now(),
        editable: _editable(row),
      ),
    );
    if (!mounted || selection == null) return;
    await _update(row, selection);
  }

  Future<void> _update(
    Map<String, dynamic> row,
    InterviewTimeSelection selection,
  ) async {
    if (_locked || !_editable(row)) return;
    if (!selection.start.isAfter(_now())) {
      setState(() => _submitError = '面试时间须晚于当前时间（UTC+8）');
      return;
    }
    final id = talentId(row['appointmentId']);
    if (id == null) return;
    setState(() {
      _saving = true;
      _submitError = null;
    });
    try {
      final result = await widget.source.reschedule(
        id,
        newStartTime: TalentUtc8.serverTime(selection.start),
        durationMin: selection.duration,
        interviewerId: selection.interviewerId,
      );
      if (!mounted) return;
      if (talentId(result['appointmentId']) != id) {
        throw const FormatException('改期响应不完整，请刷新核对');
      }
      _changed = true;
      for (final stage in _stages) {
        if (talentId(stage.appointment?['appointmentId']) == id) {
          stage.appointment = {...row, ...result};
        }
      }
      await _loadCalendar();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('面试安排已更新')));
      }
    } catch (error) {
      if (!mounted) return;
      final message = talentError(error);
      setState(() => _submitError = message);
      if (message.contains('冲突') || message.contains('占用')) {
        await _showConflict(message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _switchWeek(int delta) {
    if (_locked) return;
    setState(
      () => _week = delta == 0
          ? _monday(TalentUtc8.wallTime(_now()))
          : _week.add(Duration(days: delta * 7)),
    );
    _loadCalendar();
  }

  String _scheduleLabel(_StageDraft stage) {
    final row = stage.appointment;
    if (row != null) {
      return '${row['startTime']} · ${row['interviewerName'] ?? '已安排'}';
    }
    if (!stage.ready) return '待设置面试官及时间';
    final people = _people.where(
      (row) => talentId(row['userId']) == stage.interviewerId,
    );
    final person = people.isEmpty
        ? '面试官未填写'
        : talentText(people.first['userName']);
    return '${TalentUtc8.serverTime(stage.start!).substring(0, 16)}\n$person · ${stage.duration}分钟';
  }

  @override
  Widget build(BuildContext context) {
    final stage = _current;
    final allSaved =
        _stages.isNotEmpty && _stages.every((item) => item.appointment != null);
    final canSubmit =
        !_locked &&
        !_loadingWorkflow &&
        !_loadingPeople &&
        _workflowError == null &&
        _peopleError == null &&
        _people.isNotEmpty &&
        _stages.isNotEmpty &&
        _busy != true &&
        _stages.every((item) => item.appointment != null || item.ready);
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              key: const Key('invite-fixed-header'),
              children: [
                Expanded(
                  child: Text(
                    '邀请面试',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const Key('invite-close'),
                  tooltip: '关闭',
                  onPressed: _saving
                      ? null
                      : () => Navigator.pop(context, _changed || _uncertain),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('invite-content-scroll'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.job != null)
                      Text('岗位：${widget.job!.title}')
                    else ...[
                      if (_jobs.isNotEmpty)
                        DropdownButtonFormField<int>(
                          key: const Key('invite-job'),
                          initialValue: _positionId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: '岗位'),
                          items: _jobs
                              .map(
                                (row) => DropdownMenuItem(
                                  value: talentId(row['posId']),
                                  child: Text(talentText(row['title'])),
                                ),
                              )
                              .toList(),
                          onChanged: _locked
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() => _positionId = value);
                                  _loadWorkflow(value);
                                },
                        ),
                      if (_loadingJobs) const LinearProgressIndicator(),
                      if (!_loadingJobs && _jobs.isEmpty && _jobsError == null)
                        const Text('暂无可邀约岗位'),
                      if (_jobsError != null) Text(_jobsError!),
                      if (_jobsError != null ||
                          (!_loadingJobs && _jobs.isEmpty))
                        TextButton(
                          onPressed: _locked ? null : _loadJobs,
                          child: const Text('重试加载岗位'),
                        ),
                      if (_moreJobs && !_loadingJobs)
                        TextButton(
                          onPressed: _locked ? null : _loadJobs,
                          child: const Text('加载更多岗位'),
                        ),
                    ],
                    if (_loadingWorkflow)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      ),
                    if (_workflowError != null) ...[
                      Text(
                        _workflowError!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                      TextButton(
                        onPressed: _locked
                            ? null
                            : () => _loadWorkflow(_positionId!),
                        child: const Text('重新加载招聘流程'),
                      ),
                    ],
                    if (_stages.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        '招聘流程 · 点击卡片设置面试时间',
                        style: TextStyle(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      for (final (index, item) in _stages.indexed)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Material(
                            color: index == _selected
                                ? AppColors.interactiveSoft
                                : AppColors.canvas,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: index == _selected
                                    ? AppColors.interactive
                                    : AppColors.hairline,
                              ),
                            ),
                            child: ListTile(
                              key: ValueKey('invite-stage-$index'),
                              dense: true,
                              leading: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: AppColors.interactive,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              title: Text(item.name),
                              subtitle: Text(_scheduleLabel(item)),
                              trailing: IconButton(
                                key: ValueKey('invite-stage-edit-$index'),
                                tooltip: item.appointment == null
                                    ? '设置${item.name}'
                                    : '查看或编辑${item.name}',
                                onPressed: _locked
                                    ? null
                                    : () => _editStage(index),
                                icon: Icon(
                                  item.appointment != null
                                      ? Icons.check_circle_outline
                                      : Icons.edit_outlined,
                                  color: item.appointment != null
                                      ? AppColors.success
                                      : AppColors.interactive,
                                  size: 20,
                                ),
                              ),
                              onTap: _locked ? null : () => _editStage(index),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    if (_loadingPeople)
                      const LinearProgressIndicator()
                    else if (_peopleError != null) ...[
                      Text(_peopleError!),
                      TextButton(
                        onPressed: _locked ? null : _loadPeople,
                        child: const Text('重试加载面试官'),
                      ),
                    ] else if (_people.isEmpty) ...[
                      const Text('暂无可用面试官'),
                      TextButton(
                        onPressed: _locked ? null : _loadPeople,
                        child: const Text('刷新面试官'),
                      ),
                    ],
                    if (_submitError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          _submitError!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const Key('invite-submit'),
                      onPressed: canSubmit ? _submit : null,
                      child: Text(
                        _saving
                            ? '正在提交'
                            : allSaved
                            ? '完成'
                            : _stages.length > 1
                            ? '确认邀请全部阶段'
                            : '确认邀请',
                      ),
                    ),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () =>
                                Navigator.pop(context, _changed || _uncertain),
                      child: Text(_uncertain ? '关闭并查看面试安排' : '取消'),
                    ),
                    const SizedBox(height: 8),
                    TalentInterviewWeekCalendar(
                      weekStart: _week,
                      appointments: _calendar,
                      loading: _loadingCalendar,
                      error: _calendarError,
                      enabled: !_locked,
                      today: TalentUtc8.wallTime(_now()),
                      selectedDay: stage?.date,
                      onPrevious: () => _switchWeek(-1),
                      onNext: () => _switchWeek(1),
                      onToday: () => _switchWeek(0),
                      onRefresh: _loadCalendar,
                      onChooseDay: (_) {},
                      onChooseTime: (day, hour, minute) {
                        if (stage == null || stage.appointment != null) return;
                        _editStage(
                          _selected,
                          suggestedStart: TalentUtc8.fromSelection(
                            day,
                            hour,
                            minute,
                          ),
                        );
                      },
                      canEdit: _editable,
                      onOpen: _openAppointment,
                      onMove: (row, start, duration) => _update(
                        row,
                        InterviewTimeSelection(
                          start: start,
                          duration: duration,
                          interviewerId: talentId(row['interviewerId'])!,
                        ),
                      ),
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
}
