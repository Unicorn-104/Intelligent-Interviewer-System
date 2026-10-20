import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../core/network/api_exception.dart';
import '../data/talent_detail_data_source.dart';
import '../models/talent_detail_view_data.dart';
import 'talent_interview_time_editor.dart';
import 'talent_interview_week_calendar.dart';

/// 现有预约改期：日历只读展示企业安排，保存复用原服务端事务与冲突检查。
class TalentInterviewRescheduleSheet extends StatefulWidget {
  const TalentInterviewRescheduleSheet({
    super.key,
    required this.appointment,
    required this.source,
    this.now,
  });
  final Map<String, dynamic> appointment;
  final TalentDetailDataSource source;
  final DateTime Function()? now;
  @override
  State<TalentInterviewRescheduleSheet> createState() =>
      _TalentInterviewRescheduleSheetState();
}

class _TalentInterviewRescheduleSheetState
    extends State<TalentInterviewRescheduleSheet> {
  late Map<String, dynamic> _appointment;
  late DateTime _week, _day;
  bool _loading = true,
      _saving = false,
      _editing = false,
      _changed = false,
      _uncertain = false;
  String? _calendarError, _peopleError, _error;
  List<Map<String, dynamic>> _calendar = [], _people = [];
  int _request = 0;
  DateTime get _now => widget.now?.call() ?? DateTime.now();
  bool get _locked => _saving || _editing;
  int get _id => talentId(_appointment['appointmentId']) ?? 0;
  int get _candidate => talentId(_appointment['candidateId']) ?? 0;
  int get _position => talentId(_appointment['positionId']) ?? 0;
  static DateTime _monday(DateTime day) => DateTime(
    day.year,
    day.month,
    day.day,
  ).subtract(Duration(days: day.weekday - 1));
  bool _editable(Map<String, dynamic> row) {
    final status = int.tryParse('${row['status']}');
    final start = TalentUtc8.parseServer(row['startTime']);
    return (status == 0 || status == 1) && start != null && start.isAfter(_now);
  }

  @override
  void initState() {
    super.initState();
    _appointment = Map.of(widget.appointment);
    final start = TalentUtc8.parseServer(_appointment['startTime']) ?? _now;
    final wall = TalentUtc8.wallTime(start);
    _day = DateTime(wall.year, wall.month, wall.day);
    _week = _monday(_day);
    _loadPeople();
    _loadCalendar();
  }

  Future<void> _loadPeople() async {
    try {
      final people = await widget.source.loadInterviewers();
      if (mounted) {
        setState(() {
          _people = people;
          _peopleError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _peopleError = talentError(error));
    }
  }

  Future<void> _loadCalendar() async {
    final request = ++_request;
    final week = _week;
    setState(() {
      _loading = true;
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
        if (!mounted || request != _request) return;
        var added = 0;
        for (final row in rows) {
          final id = talentId(row['appointmentId']);
          final start = TalentUtc8.parseServer(row['startTime']),
              end = TalentUtc8.parseServer(row['endTime']);
          if (id == null ||
              start == null ||
              end == null ||
              !end.isAfter(start)) {
            throw const FormatException('日历数据不完整，请刷新');
          }
          if (!collected.containsKey(id)) added++;
          collected[id] = row;
        }
        if (rows.length < 100) break;
        if (page >= 200 || added == 0) {
          throw const FormatException('日历分页异常，请缩小范围');
        }
      }
      setState(() => _calendar = collected.values.toList());
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _calendarError = talentError(error));
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _weekBy(int offset) {
    if (_locked) return;
    setState(() {
      _week = offset == 0
          ? _monday(TalentUtc8.wallTime(_now))
          : _week.add(Duration(days: offset * 7));
      _day = _week;
    });
    _loadCalendar();
  }

  Future<void> _validate(InterviewTimeSelection selection) async {
    if (!_editable(_appointment)) {
      throw const FormatException('仅未开始且未取消的面试可以改期');
    }
    if (!selection.start.isAfter(_now)) {
      throw const FormatException('面试时间须晚于当前时间（UTC+8）');
    }
    if (_id == 0 || _candidate == 0 || _position == 0) {
      throw const FormatException('预约身份数据不完整，请刷新列表');
    }
    final plan = await widget.source.loadCandidatePlan(_candidate, _position);
    final current = plan
        .where(
          (row) =>
              talentId(row['appointmentId']) == _id &&
              talentId(row['candidateId']) == _candidate &&
              talentId(row['positionId']) == _position,
        )
        .toList();
    if (current.length != 1 || !_editable(current.single)) {
      throw const FormatException('预约已变更或已开始，请关闭后刷新列表');
    }
    final fresh = current.single;
    if (TalentUtc8.parseServer(fresh['startTime']) !=
            TalentUtc8.parseServer(_appointment['startTime']) ||
        TalentUtc8.parseServer(fresh['endTime']) !=
            TalentUtc8.parseServer(_appointment['endTime']) ||
        talentId(fresh['interviewerId']) !=
            talentId(_appointment['interviewerId'])) {
      throw const FormatException('预约已被修改，请关闭后刷新列表');
    }
    final end = selection.start.add(Duration(minutes: selection.duration));
    if (selection.start == TalentUtc8.parseServer(fresh['startTime']) &&
        end == TalentUtc8.parseServer(fresh['endTime']) &&
        selection.interviewerId == talentId(fresh['interviewerId'])) {
      throw const FormatException('请选择与原安排不同的时间或面试官');
    }
    final order = int.tryParse('${fresh['stageOrder']}') ?? 0;
    for (final row in plan) {
      if (talentId(row['appointmentId']) == _id ||
          int.tryParse('${row['status']}') == 2) {
        continue;
      }
      if (talentId(row['candidateId']) != _candidate ||
          talentId(row['positionId']) != _position) {
        throw const FormatException('候选人排期数据不一致');
      }
      final a = TalentUtc8.parseServer(row['startTime']),
          b = TalentUtc8.parseServer(row['endTime']);
      if (a == null || b == null || !b.isAfter(a)) {
        throw const FormatException('排期数据不完整，请刷新');
      }
      final otherOrder = int.tryParse('${row['stageOrder']}') ?? 0;
      if (TalentUtc8.overlaps(selection.start, end, a, b)) {
        throw const FormatException('时间冲突：求职者已有面试安排');
      }
      if (order > 0 &&
          otherOrder > 0 &&
          ((otherOrder < order && b.isAfter(selection.start)) ||
              (otherOrder > order && a.isBefore(end)))) {
        throw const FormatException('时间冲突：各阶段须按招聘流程先后安排');
      }
    }
    for (final row in _calendar) {
      if (talentId(row['appointmentId']) == _id ||
          int.tryParse('${row['status']}') == 2) {
        continue;
      }
      if (talentId(row['candidateId']) != _candidate &&
          talentId(row['interviewerId']) != selection.interviewerId) {
        continue;
      }
      final a = TalentUtc8.parseServer(row['startTime']),
          b = TalentUtc8.parseServer(row['endTime']);
      if (a == null || b == null || !b.isAfter(a)) {
        throw const FormatException('日历数据不完整，请刷新');
      }
      if (TalentUtc8.overlaps(selection.start, end, a, b)) {
        throw const FormatException('时间冲突：求职者或面试官已有面试安排');
      }
    }
    final slots = await widget.source.loadAvailability(
      selection.interviewerId,
      to: TalentUtc8.serverTime(end),
    );
    final oldSlot = talentId(fresh['slotId']);
    final otherSlots = slots
        .where((row) => oldSlot == null || talentId(row['slotId']) != oldSlot)
        .toList();
    if (TalentUtc8.isBusy(otherSlots, selection.start, end)) {
      throw const FormatException('时间冲突：面试官在该时段已被占用');
    }
  }

  Future<void> _edit({DateTime? start}) async {
    if (_locked ||
        _loading ||
        _calendarError != null ||
        _peopleError != null ||
        _people.isEmpty ||
        _uncertain) {
      return;
    }
    if (!_editable(_appointment)) {
      setState(() => _error = '仅未开始且未取消的面试可以改期');
      return;
    }
    final oldStart = TalentUtc8.parseServer(_appointment['startTime']),
        oldEnd = TalentUtc8.parseServer(_appointment['endTime']);
    if (oldStart == null || oldEnd == null || !oldEnd.isAfter(oldStart)) {
      setState(() => _error = '原面试时间不完整，请刷新列表');
      return;
    }
    final editing = start == null
        ? _appointment
        : {
            ..._appointment,
            'startTime': TalentUtc8.serverTime(start),
            'endTime': TalentUtc8.serverTime(
              start.add(oldEnd.difference(oldStart)),
            ),
          };
    setState(() => _editing = true);
    InterviewTimeSelection? selection;
    try {
      selection = await showDialog<InterviewTimeSelection>(
        context: context,
        barrierDismissible: false,
        builder: (_) => TalentInterviewTimeEditor(
          appointment: editing,
          people: _people,
          now: _now,
          editable: true,
          validateSelection: _validate,
        ),
      );
    } finally {
      if (mounted) setState(() => _editing = false);
    }
    if (!mounted || selection == null) return;
    final value = selection;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认面试改期？'),
        content: Text(
          '原时间：${_appointment['startTime']}\n新时间：${TalentUtc8.serverTime(value.start)}\n时长：${value.duration}分钟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('reschedule-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认改期'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _save(value);
  }

  Future<void> _save(InterviewTimeSelection value) async {
    if (_saving || _uncertain) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    var submitted = false;
    try {
      await _validate(value);
      submitted = true;
      final result = await widget.source.reschedule(
        _id,
        newStartTime: TalentUtc8.serverTime(value.start),
        durationMin: value.duration,
        interviewerId: value.interviewerId,
      );
      if (!mounted) return;
      if (talentId(result['appointmentId']) != _id ||
          TalentUtc8.parseServer(
                result['startTime'] ?? result['newStartTime'],
              ) !=
              value.start ||
          talentId(result['candidateId']) != _candidate ||
          talentId(result['positionId']) != _position ||
          talentId(result['interviewerId']) != value.interviewerId ||
          TalentUtc8.parseServer(result['endTime']) !=
              value.start.add(Duration(minutes: value.duration))) {
        setState(() {
          _uncertain = true;
          _changed = true;
          _error = '改期已响应但结果不完整，请返回列表核对，避免重复提交';
        });
        return;
      }
      setState(() {
        _changed = true;
        _appointment = {
          ..._appointment,
          ...result,
          'startTime': TalentUtc8.serverTime(value.start),
          'endTime': TalentUtc8.serverTime(
            value.start.add(Duration(minutes: value.duration)),
          ),
        };
      });
      await _loadCalendar();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('面试已改期')));
      }
    } catch (error) {
      if (mounted) {
        final unknown =
            submitted &&
            (error is! ApiException ||
                error.code == null ||
                (error.statusCode ?? 0) >= 500);
        setState(() {
          _uncertain = unknown;
          _changed = _changed || unknown;
          _error = unknown ? '改期结果尚未确认，请返回列表核对，避免重复提交' : talentError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openCalendar(Map<String, dynamic> row) {
    if (_locked) return;
    if (talentId(row['appointmentId']) == _id) {
      _edit();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('当日面试安排'),
        content: Text(
          '${row['candidateName'] ?? '求职者'} · ${row['positionTitle'] ?? '面试'}\n${row['startTime']} — ${row['endTime']}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_locked,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '面试改期',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brand,
                  ),
                ),
              ),
              IconButton(
                key: const Key('reschedule-close'),
                tooltip: '关闭改期',
                onPressed: _locked
                    ? null
                    : () => Navigator.pop(context, _changed),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            '${_appointment['candidateName'] ?? '求职者'} · ${_appointment['stageName'] ?? '面试'}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          if (!_loading && _peopleError == null && _people.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '暂无可用面试官',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          if (_peopleError != null)
            Row(
              children: [
                Expanded(child: Text(_peopleError!)),
                TextButton(onPressed: _loadPeople, child: const Text('重试面试官')),
              ],
            ),
          Expanded(
            child: SingleChildScrollView(
              child: TalentInterviewWeekCalendar(
                weekStart: _week,
                selectedDay: _day,
                today: TalentUtc8.wallTime(_now),
                appointments: _calendar,
                loading: _loading,
                error: _calendarError,
                enabled: !_locked,
                onPrevious: () => _weekBy(-1),
                onNext: () => _weekBy(1),
                onToday: () => _weekBy(0),
                onRefresh: _loadCalendar,
                onChooseDay: (day) => setState(() => _day = day),
                onChooseTime: (day, hour, minute) =>
                    _edit(start: TalentUtc8.fromSelection(day, hour, minute)),
                onOpen: _openCalendar,
                canEdit: (_) => false,
                onMove: (_, start, duration) {},
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          FilledButton.icon(
            key: const Key('reschedule-edit'),
            onPressed:
                _locked ||
                    _loading ||
                    _calendarError != null ||
                    _people.isEmpty ||
                    _uncertain
                ? null
                : () => _edit(),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: Text(_saving ? '保存中…' : '调整面试时间'),
          ),
        ],
      ),
    ),
  );
}
