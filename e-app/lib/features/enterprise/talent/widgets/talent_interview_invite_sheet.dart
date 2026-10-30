import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../theme/app_theme.dart';
import '../data/talent_detail_data_source.dart';
import '../models/talent_detail_view_data.dart';

/// 阶段面试方式文案，与发布岗位时的招聘流程配置一致。
const _stageTypeLabels = <int, String>{
  1: '在线笔试',
  2: 'AI 技术面试',
  3: 'HR 综合面试',
  4: '编程实操',
};

/// 邀请面试弹窗：阶段列表、周历、时间轴与「面试时间设置」整合在同一个可滚动页面，
/// 步骤二「确认邀请」最终确认后才调用邀请接口。
///
/// 开始时间只有一份状态（当前阶段的日期 + 时间），点击时间轴与手动选择
/// 日期/时间都会写入同一份状态并互相同步；时长只读，来自岗位招聘流程配置。
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
  _StageDraft({
    required this.name,
    required this.duration,
    this.stageId,
    this.stageType,
    this.requiredFlag = false,
    this.skip = false,
    this.durationConfigured = true,
  });
  final String name;
  final int? stageId;
  final int? stageType;
  final bool requiredFlag;
  final bool skip;
  final int duration;
  final bool durationConfigured;
  int? interviewerId;
  DateTime? date;
  TimeOfDay? time;
  Map<String, dynamic>? appointment;

  DateTime? get start => date == null || time == null
      ? null
      : TalentUtc8.fromSelection(date!, time!.hour, time!.minute);
  DateTime? get end => start?.add(Duration(minutes: duration));
  bool get ready => interviewerId != null && start != null && durationConfigured;

  /// 结束时间超出开始日期当天 24:00 视为跨天面试。
  bool get crossDay {
    final start = this.start;
    final end = this.end;
    if (start == null || end == null || !durationConfigured) return false;
    final dayEnd = TalentUtc8.fromSelection(date!, 0, 0).add(
      const Duration(days: 1),
    );
    return end.isAfter(dayEnd);
  }

  Map<String, Object?> get payload => {
    'stageId': stageId,
    'interviewerId': interviewerId,
    'startTime': TalentUtc8.serverTime(start!),
    'durationMin': duration,
  };
}

enum _InviteView { setup, confirm }

class _TalentInterviewInviteSheetState
    extends State<TalentInterviewInviteSheet> {
  List<Map<String, dynamic>> _people = [], _jobs = [], _calendar = [];
  List<Map<String, dynamic>> _availability = [];
  List<_StageDraft> _stages = [];
  int? _positionId;
  int _selected = 0, _jobPage = 0, _workflowRequest = 0, _calendarRequest = 0;
  bool _loadingPeople = true,
      _loadingJobs = false,
      _loadingWorkflow = false,
      _loadingCalendar = false,
      _loadingMatch = false,
      _loadingAvailability = false,
      _saving = false,
      _uncertain = false,
      _moreJobs = false,
      _changed = false;
  String? _peopleError,
      _jobsError,
      _workflowError,
      _calendarError,
      _submitError;
  num? _matchScore;
  bool? _busy;
  late DateTime _week;
  late DateTime _day;
  _InviteView _view = _InviteView.setup;

  _StageDraft? get _current => _stages.isEmpty ? null : _stages[_selected];
  bool get _locked => _saving || _uncertain;
  DateTime _now() => (widget.clock?.call() ?? DateTime.now()).toUtc();
  static DateTime _monday(DateTime day) => DateTime(
    day.year,
    day.month,
    day.day,
  ).subtract(Duration(days: day.weekday - 1));
  DateTime _wallNow() => TalentUtc8.wallTime(_now());
  DateTime _wallToday() {
    final wall = _wallNow();
    return DateTime(wall.year, wall.month, wall.day);
  }

  @override
  void initState() {
    super.initState();
    _day = _wallToday();
    _week = _monday(_day);
    _positionId = widget.job?.positionId;
    _loadPeople();
    if (widget.job != null) _loadMatch();
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

  /// 适配度来自现有分析接口；失败或未分析时不阻塞邀请流程。
  Future<void> _loadMatch() async {
    if (_loadingMatch || widget.job == null) return;
    setState(() => _loadingMatch = true);
    try {
      final match = await widget.source.loadMatch(
        widget.candidateId,
        widget.job!,
      );
      if (!mounted) return;
      setState(
        () => _matchScore = match.result == null
            ? null
            : talentNumber(match.result!['totalScore']),
      );
    } catch (_) {
      if (mounted) setState(() => _matchScore = null);
    } finally {
      if (mounted) setState(() => _loadingMatch = false);
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
      _view = _InviteView.setup;
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
        final parsed = config is Map
            ? int.tryParse('${config['duration']}')
            : null;
        final configured =
            parsed != null && parsed >= 1 && parsed <= 1440;
        stages.add(
          _StageDraft(
            stageId: id,
            name: talentText(row['name']),
            stageType: talentId(row['type']),
            duration: configured ? parsed : 0,
            durationConfigured: configured,
            requiredFlag:
                row['required'] == true || '${row['required']}' == '1',
            skip: row['skip'] == true || '${row['skip']}' == '1',
          ),
        );
      }
      if (stages.isEmpty) {
        throw const FormatException('该岗位尚未配置招聘流程阶段，请先在岗位详情完善招聘流程');
      }
      for (final stage in stages) {
        // 未安排阶段默认落在当前查看日期，手动只选开始时间时也有日期基准。
        stage.date = _day;
        final matches = existing
            .where((row) => talentId(row['stageId']) == stage.stageId)
            .toList();
        if (matches.isEmpty) continue;
        final row = matches.last;
        stage.appointment = row;
        final start = TalentUtc8.parseServer(row['startTime']);
        if (start != null) {
          final wall = TalentUtc8.wallTime(start);
          stage.date = DateTime(wall.year, wall.month, wall.day);
          stage.time = TimeOfDay(hour: wall.hour, minute: wall.minute);
        }
        stage.interviewerId = talentId(row['interviewerId']);
      }
      if (!mounted || request != _workflowRequest) return;
      setState(() {
        _stages = stages;
        final first = stages.isNotEmpty ? stages.first : null;
        if (first != null && first.date != null) _day = first.date!;
        _week = _monday(_day);
      });
      await _loadCalendar();
      await _loadAvailability();
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

  /// 加载所选面试官在查看日期（以及跨天选择覆盖到的时间段）的忙闲，
  /// 用于时间轴展示与冲突提示。保存与提交时仍会再次检查。
  Future<void> _loadAvailability() async {
    final interviewer = _current?.interviewerId;
    final dayStart = TalentUtc8.fromSelection(_day, 0, 0);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final selectionEnd = _current?.end;
    final to = selectionEnd != null && selectionEnd.isAfter(dayEnd)
        ? selectionEnd
        : dayEnd;
    if (interviewer == null) {
      setState(() {
        _availability = [];
        _loadingAvailability = false;
      });
      return;
    }
    setState(() {
      _loadingAvailability = true;
    });
    try {
      final rows = await widget.source.loadAvailability(
        interviewer,
        from: TalentUtc8.serverTime(dayStart),
        to: TalentUtc8.serverTime(to),
      );
      if (!mounted || interviewer != _current?.interviewerId) return;
      setState(() => _availability = rows);
    } catch (_) {
      if (!mounted || interviewer != _current?.interviewerId) return;
      // 忙闲加载失败不得视为空闲；保存时仍会再次检查。
      setState(() => _availability = []);
    } finally {
      if (mounted && interviewer == _current?.interviewerId) {
        setState(() => _loadingAvailability = false);
      }
    }
  }

  bool _editable(Map<String, dynamic> row) {
    final status = int.tryParse('${row['status']}');
    final start = TalentUtc8.parseServer(row['startTime']);
    return (status == 0 || status == 1) &&
        start != null &&
        start.isAfter(_now());
  }

  /// 切换当前编辑阶段：各阶段的临时排期保存在各自的 _StageDraft 中，
  /// 切换只改变当前选中项，不会丢失已设置的时间。
  void _selectStage(int index) {
    if (_locked || _loadingWorkflow || _people.isEmpty) return;
    final stage = _stages[index];
    setState(() {
      _selected = index;
      _view = _InviteView.setup;
      _submitError = null;
      _busy = null;
      _availability = [];
      if (stage.date != null) _day = stage.date!;
      if (_monday(_day) != _week) {
        _week = _monday(_day);
        _loadCalendar();
      }
    });
    _loadAvailability();
  }

  /// 时间轴点击：写入当前阶段的日期与时间（唯一的开始时间状态源）。
  void _selectSlot(DateTime day, int hour, int minute) {
    final stage = _current;
    if (stage == null || _locked) return;
    // 已安排且只读的阶段不允许改选时间；可编辑安排允许调整。
    if (stage.appointment != null && !_editable(stage.appointment!)) return;
    setState(() {
      stage.date = DateTime(day.year, day.month, day.day);
      stage.time = TimeOfDay(hour: hour, minute: minute);
      _day = DateTime(day.year, day.month, day.day);
      _busy = null;
      _submitError = null;
    });
    _loadAvailability();
  }

  /// 手动选择面试日期：与时间轴共用同一份 stage.date/time 状态。
  Future<void> _pickDate() async {
    final stage = _current;
    if (stage == null || _locked) return;
    if (stage.appointment != null && !_editable(stage.appointment!)) return;
    final today = _wallToday();
    final value = await showDatePicker(
      context: context,
      initialDate: stage.date == null || stage.date!.isBefore(today)
          ? today
          : stage.date!,
      firstDate: today,
      lastDate: DateTime(today.year + 3),
    );
    if (!mounted || value == null) return;
    setState(() {
      stage.date = value;
      _day = value;
      if (_monday(value) != _week) {
        _week = _monday(value);
        _loadCalendar();
      }
      _busy = null;
      _submitError = null;
    });
    _loadAvailability();
  }

  /// 手动选择开始时间：同样写入当前阶段的唯一开始时间状态。
  Future<void> _pickTime() async {
    final stage = _current;
    if (stage == null || _locked) return;
    if (stage.appointment != null && !_editable(stage.appointment!)) return;
    final wall = TalentUtc8.wallTime(_now().add(const Duration(hours: 1)));
    final value = await showTimePicker(
      context: context,
      initialTime: stage.time ?? TimeOfDay(hour: wall.hour, minute: wall.minute),
    );
    if (!mounted || value == null) return;
    setState(() {
      stage.time = value;
      _busy = null;
      _submitError = null;
    });
    _loadAvailability();
  }

  /// 当前选择时段与已有安排/面试官忙闲的冲突提示（覆盖完整的开始至结束区间）。
  String? _slotConflict(DateTime? start, int duration) {
    if (start == null) return null;
    final end = start.add(Duration(minutes: duration));
    if (!start.isAfter(_now())) return '面试时间须晚于当前时间（UTC+8）';
    for (final row in _calendar) {
      if (int.tryParse('${row['status']}') == 2) continue;
      final busyStart = TalentUtc8.parseServer(row['startTime']);
      final busyEnd = TalentUtc8.parseServer(row['endTime']);
      if (busyStart == null ||
          busyEnd == null ||
          !busyEnd.isAfter(busyStart)) {
        continue;
      }
      if (TalentUtc8.overlaps(start, end, busyStart, busyEnd)) {
        return '该时间段已有面试安排，请选择其他时间';
      }
    }
    if (_availability.isNotEmpty) {
      try {
        if (TalentUtc8.isBusy(_availability, start, end)) {
          return '所选时段面试官已被占用';
        }
      } on FormatException {
        return '面试官忙闲数据不完整，请刷新后再试';
      }
    }
    return null;
  }

  Future<void> _openInterviewerSheet() async {
    final stage = _current;
    if (_locked || _loadingPeople || _people.isEmpty || stage == null) return;
    if (stage.appointment != null && !_editable(stage.appointment!)) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _InterviewerSheet(
        people: _people,
        current: stage.interviewerId,
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      stage.interviewerId = selected;
      _availability = [];
      _busy = null;
      _submitError = null;
    });
    await _loadAvailability();
  }

  /// 已安排且可编辑的阶段：保存调整走原改期接口。
  Future<void> _saveArranged() async {
    final stage = _current;
    if (_locked || stage == null) return;
    final row = stage.appointment;
    if (row == null || !_editable(row)) return;
    final start = stage.start;
    if (start == null || !start.isAfter(_now())) {
      setState(() => _submitError = '面试时间须晚于当前时间（UTC+8）');
      return;
    }
    if (!stage.durationConfigured) {
      setState(() => _submitError = '该阶段未配置面试时长，请先完善岗位招聘流程');
      return;
    }
    final conflict = _slotConflict(start, stage.duration);
    if (conflict != null) {
      setState(() => _submitError = conflict);
      return;
    }
    final id = talentId(row['appointmentId']);
    if (id == null || stage.interviewerId == null) return;
    setState(() {
      _saving = true;
      _submitError = null;
    });
    try {
      // 时长保持阶段配置/原预约时长，不随改期调整。
      final result = await widget.source.reschedule(
        id,
        newStartTime: TalentUtc8.serverTime(start),
        interviewerId: stage.interviewerId,
      );
      if (!mounted) return;
      if (talentId(result['appointmentId']) != id) {
        throw const FormatException('改期响应不完整，请刷新核对');
      }
      _changed = true;
      for (final item in _stages) {
        if (talentId(item.appointment?['appointmentId']) == id) {
          item.appointment = {...row, ...result};
        }
      }
      setState(() => _busy = null);
      await _loadCalendar();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('面试安排已更新')));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitError = talentError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 已安排阶段是否被修改过（时间或面试官与预约不一致）。
  bool _arrangedModified(_StageDraft stage) {
    final row = stage.appointment;
    if (row == null || !_editable(row)) return false;
    final start = TalentUtc8.parseServer(row['startTime']);
    final changedTime = stage.start != null &&
        (start == null || !stage.start!.isAtSameMomentAs(start));
    final changedInterviewer =
        stage.interviewerId != talentId(row['interviewerId']);
    return changedTime || changedInterviewer;
  }

  Future<void> _enterConfirm() async {
    if (_locked || _positionId == null || _workflowError != null) return;
    final pending = _stages
        .where((stage) => stage.appointment == null)
        .toList();
    if (pending.isEmpty) {
      // 全部已安排，无需再发邀约。
      Navigator.pop(context, _changed);
      return;
    }
    if (_stages.any((stage) => !stage.durationConfigured)) {
      setState(() => _submitError = '部分阶段未配置面试时长，请先在岗位详情完善招聘流程');
      return;
    }
    if (pending.any((stage) => !stage.ready)) {
      setState(() => _submitError = '请分别设置每个阶段的面试官、日期和时间');
      return;
    }
    setState(() {
      _view = _InviteView.confirm;
      _saving = true;
      _submitError = null;
    });
    try {
      String? conflict;
      DateTime? previousEnd;
      for (final stage in _stages) {
        final start = stage.appointment == null
            ? stage.start
            : TalentUtc8.parseServer(stage.appointment!['startTime']);
        final end = stage.appointment == null
            ? stage.end
            : TalentUtc8.parseServer(stage.appointment!['endTime']);
        if (start == null || end == null) continue;
        if (stage.appointment == null && !start.isAfter(_now())) {
          conflict = '面试时间须晚于当前时间（UTC+8）';
          break;
        }
        if (previousEnd != null && start.isBefore(previousEnd)) {
          conflict = '各阶段须按招聘流程先后安排，后一阶段不能早于前一阶段结束时间';
          break;
        }
        previousEnd = end;
      }
      if (conflict == null) {
        for (final item in pending) {
          final end = item.end!;
          final rows = await widget.source.loadAvailability(
            item.interviewerId!,
            to: TalentUtc8.serverTime(end),
          );
          if (!mounted) return;
          if (TalentUtc8.isBusy(rows, item.start!, end)) {
            conflict = '「${item.name}」所选时段面试官已被占用，请返回修改';
            break;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        if (conflict != null) _submitError = conflict;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitError = talentError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _send() async {
    if (_locked || _positionId == null || _workflowError != null) return;
    final pending = _stages
        .where((stage) => stage.appointment == null)
        .toList();
    if (pending.isEmpty) {
      Navigator.pop(context, _changed);
      return;
    }
    if (pending.any((stage) => !stage.ready || !stage.durationConfigured)) {
      setState(() => _submitError = '请分别设置每个阶段的面试官、日期和时间');
      return;
    }
    final positionTitle = widget.job?.title;
    setState(() {
      _saving = true;
      _submitError = null;
    });
    try {
      // 最终提交前再次复核面试官忙闲，防止多人同时预约造成冲突。
      for (final item in pending) {
        final end = item.end!;
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
          return;
        }
      }
      final single = pending.length == 1 && pending.first.stageId == null;
      final stage = pending.first;
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
      await _loadCalendar();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitError = talentError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _switchWeek(int delta) {
    if (_locked) return;
    setState(
      () => _week = delta == 0
          ? _monday(_wallToday())
          : _week.add(Duration(days: delta * 7)),
    );
    _loadCalendar();
  }

  void _pickDay(DateTime day) {
    if (_locked) return;
    setState(() => _day = DateTime(day.year, day.month, day.day));
    _loadAvailability();
  }

  String _scheduleLabel(_StageDraft stage) {
    final row = stage.appointment;
    if (row != null) {
      final start = talentText(row['startTime'], '');
      final end = talentText(row['endTime'], '');
      final time = start.isEmpty
          ? '已安排'
          : '${start.substring(0, 16)} — ${end.length >= 16 ? end.substring(0, 16) : ''}';
      return '$time\n${talentText(row['interviewerName'], '面试官待定')}';
    }
    if (!stage.ready) return '待安排面试时间';
    final people = _people.where(
      (row) => talentId(row['userId']) == stage.interviewerId,
    );
    final person = people.isEmpty
        ? '面试官未填写'
        : talentText(people.first['userName']);
    final end = TalentUtc8.serverTime(stage.end!);
    return '${TalentUtc8.serverTime(stage.start!).substring(0, 16)} — ${end.substring(0, 16)}\n$person · ${stage.duration}分钟';
  }

  String get _positionTitle => widget.job?.title ??
      talentText(
        _jobs
            .firstWhere(
              (row) => talentId(row['posId']) == _positionId,
              orElse: () => const {'title': '未选择岗位'},
            )['title'],
      );

  String? get _currentConflict =>
      _current == null ? null : _slotConflict(_current!.start, _current!.duration);

  /// 任一待安排阶段存在冲突时禁止进入确认页。
  bool get _hasPendingConflict {
    for (final stage in _stages) {
      if (stage.appointment == null &&
          _slotConflict(stage.start, stage.duration) != null) {
        return true;
      }
    }
    return false;
  }

  bool get _canSubmit =>
      !_locked &&
      !_loadingWorkflow &&
      !_loadingPeople &&
      _workflowError == null &&
      _peopleError == null &&
      _people.isNotEmpty &&
      _stages.isNotEmpty &&
      _busy != true &&
      !_hasPendingConflict &&
      _stages.every((item) => item.durationConfigured) &&
      _stages.every((item) => item.appointment != null || item.ready);

  bool get _canSaveArranged {
    final stage = _current;
    if (stage == null || !_arrangedModified(stage)) return false;
    return stage.interviewerId != null &&
        stage.start != null &&
        stage.start!.isAfter(_now()) &&
        _currentConflict == null &&
        !_loadingAvailability;
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(bottom: insets),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _header(),
            _stepIndicator(),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('invite-content-scroll'),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: switch (_view) {
                  _InviteView.setup => _setupContent(),
                  _InviteView.confirm => _confirmContent(),
                },
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
    child: Row(
      key: const Key('invite-fixed-header'),
      children: [
        Expanded(
          child: Text(
            '邀请面试',
            style: const TextStyle(
              color: AppColors.brand,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          key: const Key('invite-close'),
          tooltip: '关闭',
          onPressed: _saving
              ? null
              : () => Navigator.pop(context, _changed || _uncertain),
          icon: const Icon(Icons.close, color: AppColors.textMuted),
        ),
      ],
    ),
  );

  /// 步骤指示器：① 设置面试时间 —— ② 确认邀请。
  Widget _stepIndicator() {
    const active = TextStyle(
      color: AppColors.teal,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );
    const idle = TextStyle(
      color: AppColors.textMuted,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );
    final atSecond = _view == _InviteView.confirm;
    return Padding(
      key: const Key('invite-step-indicator'),
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Row(
        children: [
          Text('① 设置面试时间', style: atSecond ? idle : active),
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: atSecond ? AppColors.teal : AppColors.hairline,
            ),
          ),
          Text('② 确认邀请', style: atSecond ? active : idle),
        ],
      ),
    );
  }

  /// 步骤一：阶段列表、周历、时间轴、推荐时段与面试时间设置整合在同一页面。
  Widget _setupContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _candidateCard(),
      const SizedBox(height: 12),
      if (widget.job == null) ...[
        if (_jobs.isNotEmpty)
          DropdownButtonFormField<int>(
            key: const Key('invite-job'),
            initialValue: _positionId,
            isExpanded: true,
            borderRadius: BorderRadius.circular(10),
            dropdownColor: AppColors.canvas,
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
        if (_loadingJobs) const LinearProgressIndicator(minHeight: 2),
        if (!_loadingJobs && _jobs.isEmpty && _jobsError == null)
          const Text('暂无可邀约岗位', style: TextStyle(color: AppColors.textMuted)),
        if (_jobsError != null)
          Text(_jobsError!, style: const TextStyle(color: AppColors.error)),
        if (_jobsError != null || (!_loadingJobs && _jobs.isEmpty))
          TextButton(
            onPressed: _locked ? null : _loadJobs,
            child: const Text('重试加载岗位'),
          ),
        if (_moreJobs && !_loadingJobs)
          TextButton(
            onPressed: _locked ? null : _loadJobs,
            child: const Text('加载更多岗位'),
          ),
        const SizedBox(height: 12),
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
          onPressed: _locked ? null : () => _loadWorkflow(_positionId!),
          child: const Text('重新加载招聘流程'),
        ),
      ],
      if (_stages.isNotEmpty) ...[
        _stageList(),
        const SizedBox(height: 14),
        _weekStrip(),
        const SizedBox(height: 14),
        _timeline(),
        const SizedBox(height: 10),
        _recommendations(),
        const SizedBox(height: 14),
        _timeEditorCard(),
        const SizedBox(height: 12),
        _interviewerRow(),
      ],
      if (_loadingPeople)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(minHeight: 2),
        )
      else if (_peopleError != null) ...[
        Text(_peopleError!, style: const TextStyle(color: AppColors.error)),
        TextButton(
          onPressed: _locked ? null : _loadPeople,
          child: const Text('重试加载面试官'),
        ),
      ] else if (_people.isEmpty) ...[
        const Text('暂无可用面试官', style: TextStyle(color: AppColors.textMuted)),
        TextButton(
          onPressed: _locked ? null : _loadPeople,
          child: const Text('刷新面试官'),
        ),
      ],
      if (_submitError != null && _view == _InviteView.setup)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            _submitError!,
            key: const Key('invite-overview-error'),
            style: const TextStyle(color: AppColors.error),
          ),
        ),
    ],
  );

  /// 求职者信息卡：姓名、当前阶段、应聘岗位与适配度。
  Widget _candidateCard() => Container(
    key: const Key('invite-candidate-card'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F5FB),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '求职者：${widget.candidateName}',
                style: const TextStyle(
                  color: AppColors.brand,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '应聘岗位：${widget.job?.title ?? _positionTitle}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              if (widget.job?.currentStage != null) ...[
                const SizedBox(height: 4),
                Text(
                  '当前阶段：${widget.job!.currentStage}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        _matchScoreRing(),
      ],
    ),
  );

  Widget _matchScoreRing() {
    if (_loadingMatch) {
      return const SizedBox(
        width: 52,
        height: 52,
        child: Padding(
          padding: EdgeInsets.all(14),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final score = _matchScore;
    return SizedBox(
      key: const Key('invite-match-score'),
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              value: score == null
                  ? 0.0
                  : (score / 100).clamp(0.0, 1.0).toDouble(),
              strokeWidth: 4,
              strokeCap: StrokeCap.round,
              color: AppColors.teal,
              backgroundColor: AppColors.hairline,
            ),
          ),
          Text(
            score == null ? '—' : '$score',
            style: const TextStyle(
              color: AppColors.tealDeep,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageList() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '招聘流程阶段（${_stages.length}）',
        style: const TextStyle(
          color: AppColors.brand,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 10),
      for (final (index, item) in _stages.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _stageCard(index, item),
        ),
    ],
  );

  Widget _stageCard(int index, _StageDraft item) {
    final arranged = item.appointment != null;
    final selected = index == _selected;
    return Material(
      key: ValueKey('invite-stage-$index'),
      color: AppColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? AppColors.teal : AppColors.hairline,
          width: selected ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _locked ? null : () => _selectStage(index),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.interactive,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.brand,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (item.requiredFlag) ...[
                          const SizedBox(width: 6),
                          _miniBadge('必选', AppColors.warning),
                        ],
                        if (item.skip) ...[
                          const SizedBox(width: 6),
                          _miniBadge('可跳过', AppColors.textMuted),
                        ],
                        if (!item.durationConfigured) ...[
                          const SizedBox(width: 6),
                          _miniBadge('未配置时长', AppColors.error),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_stageTypeLabels[item.stageType] ?? '面试'} · ${item.durationConfigured ? '${item.duration}分钟' : '时长缺失'}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _scheduleLabel(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: arranged
                            ? AppColors.success
                            : AppColors.textMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (arranged)
                const _StatusTag(text: '已安排')
              else
                Container(
                  key: ValueKey('invite-stage-edit-$index'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.tealSoft
                        : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    selected ? '编辑中' : '设置时间',
                    style: TextStyle(
                      color: selected
                          ? AppColors.tealDeep
                          : AppColors.interactive,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
    ),
  );

  /// 简洁周历：周导航、日期格（含当日面试数量）、当天面试列表。
  Widget _weekStrip() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: AppColors.teal,
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                '查看排期，避免冲突',
                style: TextStyle(
                  color: AppColors.brand,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              key: const Key('invite-week-prev'),
              tooltip: '上一周',
              visualDensity: VisualDensity.compact,
              onPressed: _locked || _loadingCalendar
                  ? null
                  : () => _switchWeek(-1),
              icon: const Icon(Icons.chevron_left, color: AppColors.textMuted),
            ),
            Expanded(
              child: Text(
                _weekRangeLabel(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              key: const Key('invite-week-next'),
              tooltip: '下一周',
              visualDensity: VisualDensity.compact,
              onPressed: _locked || _loadingCalendar
                  ? null
                  : () => _switchWeek(1),
              icon: const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ),
            TextButton(
              key: const Key('invite-week-today'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.tealDeep,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: _locked || _loadingCalendar
                  ? null
                  : () => _switchWeek(0),
              child: const Text('今天'),
            ),
            IconButton(
              key: const Key('invite-week-refresh'),
              tooltip: '刷新日历',
              visualDensity: VisualDensity.compact,
              onPressed: _locked || _loadingCalendar ? null : _loadCalendar,
              icon: const Icon(Icons.refresh, color: AppColors.textMuted),
            ),
          ],
        ),
        Row(
          key: const Key('invite-week-strip'),
          children: [
            for (var index = 0; index < 7; index++)
              Expanded(child: _dayTile(index)),
          ],
        ),
        if (_loadingCalendar)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (_calendarError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _calendarError!,
              style: const TextStyle(color: AppColors.error),
            ),
          )
        else
          _dayList(),
      ],
    ),
  );

  String _weekRangeLabel() {
    final last = _week.add(const Duration(days: 6));
    return '${_week.month}月${_week.day}日 – ${last.month}月${last.day}日';
  }

  List<Map<String, dynamic>> _rowsOnDay(DateTime day) {
    final start = TalentUtc8.fromSelection(day, 0, 0);
    final end = start.add(const Duration(days: 1));
    final rows = _calendar.where((row) {
      if (int.tryParse('${row['status']}') == 2) return false;
      final a = TalentUtc8.parseServer(row['startTime']);
      final b = TalentUtc8.parseServer(row['endTime']);
      return a != null && b != null && TalentUtc8.overlaps(start, end, a, b);
    }).toList()
      ..sort(
        (a, b) => TalentUtc8.parseServer(
          a['startTime'],
        )!.compareTo(TalentUtc8.parseServer(b['startTime'])!),
      );
    return rows;
  }

  Widget _dayTile(int index) {
    final date = _week.add(Duration(days: index));
    final count = _loadingCalendar || _calendarError != null
        ? -1
        : _rowsOnDay(date).length;
    final selected = DateUtils.isSameDay(date, _day);
    final isToday = DateUtils.isSameDay(date, _wallToday());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Material(
        color: selected ? AppColors.teal : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ValueKey('invite-week-day-$index'),
          borderRadius: BorderRadius.circular(10),
          onTap: _locked ? null : () => _pickDay(date),
          child: SizedBox(
            height: 58,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _weekdayLabels[index],
                    style: TextStyle(
                      color: selected
                          ? Colors.white.withValues(alpha: .9)
                          : AppColors.textMuted,
                      fontSize: 11,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : isToday
                          ? AppColors.tealDeep
                          : AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: selected || isToday
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    count < 0 ? '—' : '$count场',
                    key: ValueKey('invite-week-count-$index'),
                    style: TextStyle(
                      color: selected
                          ? Colors.white.withValues(alpha: .85)
                          : count > 0
                          ? AppColors.warning
                          : AppColors.textMuted,
                      fontSize: 10,
                      height: 1.2,
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

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  Widget _dayList() {
    final rows = _rowsOnDay(_day);
    final stage = _current;
    final draftStart = stage?.appointment == null ? stage?.start : null;
    final draftEnd = stage?.appointment == null ? stage?.end : null;
    final dayStart = TalentUtc8.fromSelection(_day, 0, 0);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final draftOnDay = draftStart != null &&
        draftEnd != null &&
        TalentUtc8.overlaps(dayStart, dayEnd, draftStart, draftEnd);
    final total = rows.length + (draftOnDay ? 1 : 0);
    return Column(
      key: const Key('invite-day-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          '${_day.month}月${_day.day}日 · $total场面试',
          style: const TextStyle(
            color: AppColors.brand,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        if (rows.isEmpty && !draftOnDay)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '当天暂无面试安排',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        if (draftOnDay)
          Padding(
            key: const Key('invite-draft-row'),
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Container(width: 3, height: 30, color: AppColors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_rangeLabelFor(draftStart, draftEnd)}（当前所选）',
                        style: const TextStyle(
                          color: AppColors.tealDeep,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        draftStart.isBefore(dayStart)
                            ? '延续自前一日 · ${stage!.name}'
                            : '${stage!.name}${draftEnd.isAfter(dayEnd) ? ' · 延续至次日' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Container(width: 3, height: 30, color: AppColors.interactive),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _rangeLabel(row),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${talentText(row['candidateName'], '候选人')} · ${talentText(row['stageName'], '面试')}${row['interviewerName'] == null ? '' : ' · ${row['interviewerName']}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _rangeLabel(Map<String, dynamic> row) {
    final start = TalentUtc8.parseServer(row['startTime']);
    final end = TalentUtc8.parseServer(row['endTime']);
    if (start == null || end == null) return talentText(row['startTime']);
    return _rangeLabelFor(start, end);
  }

  String _rangeLabelFor(DateTime start, DateTime end) {
    final a = TalentUtc8.wallTime(start);
    final b = TalentUtc8.wallTime(end);
    String hhmm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${hhmm(a)}–${hhmm(b)}';
  }

  /// 空闲时段推荐：基于当日已有面试与面试官忙闲的真实空档生成。
  /// 时长超过当日营业窗口（09:00–19:00）时不产生推荐，避免虚假时段。
  Widget _recommendations() {
    final stage = _current;
    if (stage == null || !stage.durationConfigured) {
      return const SizedBox.shrink();
    }
    final gaps = _freeGaps(stage.duration);
    if (gaps.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '可选时段（按当日排期推荐，保存时仍会校验）',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (index, gap) in gaps.take(3).indexed)
              InkWell(
                key: ValueKey('invite-recommend-$index'),
                borderRadius: BorderRadius.circular(8),
                onTap: _locked
                    ? null
                    : () {
                        final wall = TalentUtc8.wallTime(gap);
                        _selectSlot(
                          DateTime(wall.year, wall.month, wall.day),
                          wall.hour,
                          wall.minute,
                        );
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: stage.start == gap
                        ? AppColors.tealSoft
                        : AppColors.fieldBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: stage.start == gap
                          ? AppColors.teal
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    '${_hhmm(gap)}–${_hhmm(gap.add(Duration(minutes: stage.duration)))}',
                    style: TextStyle(
                      color: stage.start == gap
                          ? AppColors.tealDeep
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  List<DateTime> _freeGaps(int duration) {
    final busy = <(DateTime, DateTime)>[];
    for (final row in _rowsOnDay(_day)) {
      final a = TalentUtc8.parseServer(row['startTime']);
      final b = TalentUtc8.parseServer(row['endTime']);
      if (a != null && b != null) busy.add((a, b));
    }
    if (_availability.isNotEmpty) {
      for (final slot in _availability) {
        if (int.tryParse('${slot['status']}') != 0) continue;
        final a = TalentUtc8.parseServer(slot['startTime']);
        final b = TalentUtc8.parseServer(slot['endTime']);
        if (a == null || b == null) continue;
        if (!busy.any((item) => TalentUtc8.overlaps(a, b, item.$1, item.$2))) {
          busy.add((a, b));
        }
      }
    }
    busy.sort((a, b) => a.$1.compareTo(b.$1));
    final gaps = <DateTime>[];
    final open = TalentUtc8.fromSelection(_day, 9, 0);
    final close = TalentUtc8.fromSelection(_day, 19, 0);
    var cursor = open;
    for (final (start, end) in busy) {
      if (start.isAfter(cursor) &&
          start.difference(cursor).inMinutes >= duration) {
        gaps.add(cursor);
        if (gaps.length >= 3) break;
      }
      if (end.isAfter(cursor)) cursor = end;
      if (cursor.isAfter(close) || gaps.length >= 3) break;
    }
    if (gaps.length < 3 &&
        cursor.isBefore(close) &&
        close.difference(cursor).inMinutes >= duration) {
      gaps.add(cursor);
    }
    return gaps;
  }

  String _hhmm(DateTime instant) {
    final wall = TalentUtc8.wallTime(instant);
    return '${wall.hour.toString().padLeft(2, '0')}:${wall.minute.toString().padLeft(2, '0')}';
  }

  static const _pxPerHour = 56.0;

  /// 24 小时时间轴：点击选择开始时间（15 分钟粒度，允许跨天），
  /// 与下方「面试时间设置」卡片共用同一份开始时间状态。
  Widget _timeline() {
    final stage = _current;
    final rows = stage == null ? const <Map<String, dynamic>>[] : _rowsOnDay(_day);
    final lanes = <int, int>{};
    final laneEnds = <DateTime>[];
    for (final row in rows) {
      final start = TalentUtc8.parseServer(row['startTime'])!;
      var lane = laneEnds.indexWhere((end) => !end.isAfter(start));
      if (lane < 0) {
        lane = laneEnds.length;
        laneEnds.add(TalentUtc8.parseServer(row['endTime'])!);
      } else {
        laneEnds[lane] = TalentUtc8.parseServer(row['endTime'])!;
      }
      lanes[talentId(row['appointmentId'])!] = lane;
    }
    final busySlots = <Map<String, dynamic>>[];
    if (_availability.isNotEmpty) {
      for (final slot in _availability) {
        if (int.tryParse('${slot['status']}') != 0) continue;
        final a = TalentUtc8.parseServer(slot['startTime']);
        final b = TalentUtc8.parseServer(slot['endTime']);
        if (a == null || b == null) continue;
        final overlapsEvent = rows.any((row) {
          final ra = TalentUtc8.parseServer(row['startTime'])!;
          final rb = TalentUtc8.parseServer(row['endTime'])!;
          return TalentUtc8.overlaps(a, b, ra, rb);
        });
        if (!overlapsEvent) busySlots.add(slot);
      }
    }
    final laneCount = math.max(1, laneEnds.length);
    final dayStart = TalentUtc8.fromSelection(_day, 0, 0);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final slotStart = stage?.start;
    final slotEnd = stage?.end;
    final conflict = _currentConflict;
    final visibleStart = slotStart == null
        ? null
        : slotStart.isBefore(dayStart)
        ? dayStart
        : slotStart;
    final visibleEnd = slotEnd == null
        ? null
        : slotEnd.isAfter(dayEnd)
        ? dayEnd
        : slotEnd;
    final selectionVisible = visibleStart != null &&
        visibleEnd != null &&
        visibleStart.isBefore(visibleEnd);
    final slotTop = !selectionVisible
        ? null
        : visibleStart.difference(dayStart).inMinutes * _pxPerHour / 60;
    final slotHeight = !selectionVisible
        ? 0.0
        : visibleEnd.difference(visibleStart).inMinutes * _pxPerHour / 60;
    final readOnly =
        stage?.appointment != null && !_editable(stage!.appointment!);
    return Container(
      key: const Key('invite-timeline'),
      height: 420,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: _timelineScroll,
        child: SingleChildScrollView(
          controller: _timelineScroll,
          child: SizedBox(
            height: 24 * _pxPerHour,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = math.max(
                  constraints.maxWidth,
                  46 + laneCount * 118.0,
                );
                final columnWidth = (width - 46) / laneCount;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    height: 24 * _pxPerHour,
                    child: Stack(
                      children: [
                        if (!readOnly)
                          Positioned(
                            left: 46,
                            top: 0,
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) {
                                final minutes =
                                    ((details.localPosition.dy /
                                                    _pxPerHour *
                                                    60) /
                                                15)
                                            .floor() *
                                        15;
                                if (minutes < 0) return;
                                final clamped = math.min(minutes, 24 * 60 - 15);
                                _selectSlot(
                                  _day,
                                  clamped ~/ 60,
                                  clamped % 60,
                                );
                              },
                              child: const ColoredBox(
                                color: Colors.transparent,
                              ),
                            ),
                          ),
                        for (var hour = 0; hour < 24; hour++) ...[
                          Positioned(
                            top: hour * _pxPerHour,
                            left: 0,
                            width: 42,
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          Positioned(
                            top: hour * _pxPerHour,
                            left: 46,
                            right: 0,
                            child: const Divider(
                              height: 1,
                              color: AppColors.hairline,
                            ),
                          ),
                        ],
                        for (final slot in busySlots)
                          _busyBlock(
                            slot,
                            dayStart,
                            dayEnd,
                            columnWidth,
                          ),
                        for (final row in rows)
                          _eventBlock(
                            row,
                            lanes[talentId(row['appointmentId'])!]!,
                            columnWidth,
                            dayStart,
                            dayEnd,
                          ),
                        if (slotTop != null &&
                            slotStart != null &&
                            selectionVisible)
                          _selectionBlock(
                            slotTop,
                            slotHeight,
                            conflict != null,
                            slotStart.isBefore(dayStart),
                            slotEnd!.isAfter(dayEnd),
                            TalentUtc8.serverTime(slotStart).substring(11, 16),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  late final ScrollController _timelineScroll = ScrollController(
    initialScrollOffset: (_wallNow().hour * 60 + _wallNow().minute - 60)
        .clamp(0, 20 * 60) *
        _pxPerHour /
        60,
  );

  @override
  void dispose() {
    _timelineScroll.dispose();
    super.dispose();
  }

  Widget _busyBlock(
    Map<String, dynamic> slot,
    DateTime dayStart,
    DateTime dayEnd,
    double columnWidth,
  ) {
    final start = TalentUtc8.parseServer(slot['startTime'])!;
    final end = TalentUtc8.parseServer(slot['endTime'])!;
    final visibleStart = start.isBefore(dayStart) ? dayStart : start;
    final visibleEnd = end.isAfter(dayEnd) ? dayEnd : end;
    final top = visibleStart.difference(dayStart).inMinutes * _pxPerHour / 60;
    final height = math.max(
      4.0,
      visibleEnd.difference(visibleStart).inMinutes * _pxPerHour / 60,
    );
    return Positioned(
      top: top,
      left: 48,
      width: columnWidth * 2 - 8,
      height: height,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.error.withValues(alpha: .4)),
        ),
        child: const Center(
          child: Text(
            '面试官占用',
            style: TextStyle(color: AppColors.error, fontSize: 10),
          ),
        ),
      ),
    );
  }

  Widget _eventBlock(
    Map<String, dynamic> row,
    int lane,
    double columnWidth,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
    final start = TalentUtc8.parseServer(row['startTime'])!;
    final end = TalentUtc8.parseServer(row['endTime'])!;
    final visibleStart = start.isBefore(dayStart) ? dayStart : start;
    final visibleEnd = end.isAfter(dayEnd) ? dayEnd : end;
    final top = visibleStart.difference(dayStart).inMinutes * _pxPerHour / 60;
    final height = math.max(
      4.0,
      visibleEnd.difference(visibleStart).inMinutes * _pxPerHour / 60,
    );
    final label =
        '${talentText(row['candidateName'], '候选人')} · ${talentText(row['stageName'], '面试')}';
    return Positioned(
      top: top,
      left: 48 + lane * columnWidth,
      width: columnWidth - 6,
      height: height,
      child: Container(
        key: ValueKey('invite-event-${row['appointmentId']}'),
        margin: const EdgeInsets.only(right: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.interactive.withValues(alpha: .5)),
        ),
        child: height >= 40
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_rangeLabel(row)}\n$label',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.interactive,
                      fontSize: 10,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (height >= 64)
                    Text(
                      talentText(row['positionTitle'], ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.interactive,
                        fontSize: 10,
                      ),
                    ),
                ],
              )
            : Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _rangeLabel(row),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.interactive,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }

  /// 当前所选时段的可见部分：跨天选择在次日显示延续块。
  Widget _selectionBlock(
    double top,
    double height,
    bool conflict,
    bool continuesFromYesterday,
    bool continuesToTomorrow,
    String startLabel,
  ) => Positioned(
    top: top,
    left: 48,
    right: 2,
    height: height,
    child: IgnorePointer(
      child: CustomPaint(
        key: const Key('invite-selection'),
        painter: _DashedRectPainter(
          color: conflict ? AppColors.error : AppColors.teal,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: (conflict ? AppColors.dangerSoft : AppColors.tealSoft)
              .withValues(alpha: .75),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              height >= 24
                  ? continuesFromYesterday
                      ? '跨日延续（已选 $startLabel 开始）'
                      : '已选 $startLabel 开始${continuesToTomorrow ? ' · 延续至次日' : ''}'
                  : '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: conflict ? AppColors.error : AppColors.tealDeep,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// 「面试时间设置」卡片：手动选择日期与开始时间，时长只读，
  /// 结束时间按开始时间 + 阶段配置时长自动计算。
  Widget _timeEditorCard() {
    final stage = _current;
    if (stage == null) return const SizedBox.shrink();
    final readOnly = stage.appointment != null && !_editable(stage.appointment!);
    final start = stage.start;
    final end = stage.end;
    final conflict = _currentConflict;
    return Container(
      key: const Key('invite-time-editor'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '面试时间设置',
            style: TextStyle(
              color: AppColors.brand,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (readOnly) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '该面试已开始、已完成或已取消，仅可查看',
                style: TextStyle(color: AppColors.warning, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _editorRow(
            fieldKey: const Key('invite-date-field'),
            label: '面试日期',
            value: stage.date == null
                ? '请选择日期'
                : TalentUtc8.dateLabel(stage.date!),
            onTap: readOnly || _locked ? null : _pickDate,
          ),
          _editorRow(
            fieldKey: const Key('invite-time-field'),
            label: '开始时间',
            value: stage.time == null
                ? '请选择时间'
                : '${stage.time!.hour.toString().padLeft(2, '0')}:${stage.time!.minute.toString().padLeft(2, '0')}',
            onTap: readOnly || _locked ? null : _pickTime,
          ),
          _editorRow(
            fieldKey: const Key('invite-duration-info'),
            label: '面试时长',
            value: stage.durationConfigured
                ? '${stage.duration}分钟 · 来自岗位招聘流程配置'
                : '未配置时长',
            valueColor: stage.durationConfigured
                ? AppColors.textPrimary
                : AppColors.error,
            readOnly: true,
          ),
          _editorRow(
            fieldKey: const Key('invite-end-info'),
            label: '结束时间',
            value: end == null
                ? '待选择开始时间'
                : TalentUtc8.serverTime(end).substring(0, 16),
            readOnly: true,
          ),
          if (!stage.durationConfigured) ...[
            const SizedBox(height: 8),
            const Text(
              '该阶段未配置面试时长，请先在岗位详情完善招聘流程',
              key: Key('invite-duration-missing'),
              style: TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
          if (start != null && end != null && stage.durationConfigured) ...[
            if (stage.crossDay)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Container(
                      key: const Key('invite-cross-day'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '跨天面试',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (conflict != null) ...[
            const SizedBox(height: 8),
            Text(
              conflict,
              key: const Key('invite-conflict'),
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _editorRow({
    required Key fieldKey,
    required String label,
    required String value,
    VoidCallback? onTap,
    Color? valueColor,
    bool readOnly = false,
  }) => InkWell(
    key: fieldKey,
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
              size: 20,
            ),
        ],
      ),
    ),
  );

  Widget _interviewerRow() {
    final stage = _current;
    if (stage == null) return const SizedBox.shrink();
    final readOnly = stage.appointment != null && !_editable(stage.appointment!);
    final name = stage.interviewerId == null
        ? null
        : talentText(
            _people
                .firstWhere(
                  (row) => talentId(row['userId']) == stage.interviewerId,
                  orElse: () => const {'userName': '未填写'},
                )['userName'],
          );
    return Material(
      color: AppColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.hairline),
      ),
      child: InkWell(
        key: const Key('invite-interviewer'),
        borderRadius: BorderRadius.circular(14),
        onTap: readOnly || _locked ? null : _openInterviewerSheet,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 20,
                color: AppColors.teal,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name == null ? '请选择面试官' : '面试官：$name',
                  style: TextStyle(
                    color: name == null
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: name == null ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ),
              if (_loadingAvailability)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (!readOnly)
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- 确认邀请视图 ----------------

  Widget _confirmContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        key: const Key('invite-confirm-candidate'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F5FB),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '求职者：${widget.candidateName}',
              style: const TextStyle(
                color: AppColors.brand,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '应聘岗位：$_positionTitle',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        '面试安排汇总',
        style: TextStyle(
          color: AppColors.brand,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 10),
      for (final (index, stage) in _stages.indexed)
        _confirmStageCard(index, stage),
      if (_submitError != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            _submitError!,
            key: const Key('invite-confirm-error'),
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      if (_saving)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(minHeight: 2),
        ),
    ],
  );

  Widget _confirmStageCard(int index, _StageDraft stage) {
    final row = stage.appointment;
    final start = row == null
        ? stage.start
        : TalentUtc8.parseServer(row['startTime']);
    final end = row == null
        ? stage.end
        : TalentUtc8.parseServer(row['endTime']);
    final crossDay = row == null ? stage.crossDay : (() {
      if (start == null || end == null) return false;
      final wallStart = TalentUtc8.wallTime(start);
      final dayEnd = TalentUtc8.fromSelection(
        DateTime(wallStart.year, wallStart.month, wallStart.day),
        0,
        0,
      ).add(const Duration(days: 1));
      return end.isAfter(dayEnd);
    })();
    return Container(
      key: ValueKey('invite-confirm-stage-$index'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.interactive,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stage.name,
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (row != null)
                const _StatusTag(text: '已安排')
              else if (start != null)
                const _StatusTag(text: '待发送')
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '未安排',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '面试方式：${_stageTypeLabels[stage.stageType] ?? '面试'}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          if (start != null && end != null)
            Text(
              '${TalentUtc8.serverTime(start).substring(0, 16)} – ${TalentUtc8.serverTime(end).substring(0, 16)}（UTC+8）',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            const Text(
              '尚未设置面试时间',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          const SizedBox(height: 4),
          Text(
            '面试官：${row == null ? _interviewerName(stage.interviewerId) : talentText(row['interviewerName'], '面试官待定')} · 时长 ${row == null ? stage.duration : (start != null && end != null ? end.difference(start).inMinutes : '—')} 分钟${crossDay ? ' · 跨天面试' : ''}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _interviewerName(int? id) {
    if (id == null) return '未选择';
    for (final row in _people) {
      if (talentId(row['userId']) == id) {
        return talentText(row['userName']);
      }
    }
    return '未填写';
  }

  // ---------------- 底部操作区 ----------------

  Widget _bottomBar() {
    final stage = _current;
    final showSaveArranged =
        stage != null && _arrangedModified(stage) && _canSaveArranged;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: switch (_view) {
            _InviteView.setup => Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const Key('invite-cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(
                            context,
                            _changed || _uncertain,
                          ),
                    child: Text(_uncertain ? '关闭并查看面试安排' : '取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: showSaveArranged
                      ? FilledButton(
                          key: const Key('invite-stage-save'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            disabledBackgroundColor: AppColors.teal.withValues(
                              alpha: .45,
                            ),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _saving ? null : _saveArranged,
                          child: const Text('保存调整'),
                        )
                      : FilledButton(
                          key: const Key('invite-submit'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            disabledBackgroundColor: AppColors.teal.withValues(
                              alpha: .45,
                            ),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _canSubmit ? _enterConfirm : null,
                          child: const Text('下一步'),
                        ),
                ),
              ],
            ),
            _InviteView.confirm => Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('invite-confirm-cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      minimumSize: const Size(0, 48),
                      side: const BorderSide(color: AppColors.hairline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            _view = _InviteView.setup;
                            _submitError = null;
                          }),
                    child: const Text('返回修改'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('invite-confirm-send'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      disabledBackgroundColor: AppColors.teal.withValues(
                        alpha: .45,
                      ),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _saving || !_canSubmit || _submitError != null
                        ? null
                        : _send,
                    child: Text(
                      _saving
                          ? '正在提交…'
                          : _uncertain
                          ? '关闭并查看面试安排'
                          : '确认邀请',
                    ),
                  ),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.tealSoft,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.success,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// 面试官选择弹层：搜索 + 列表 + 确认。
class _InterviewerSheet extends StatefulWidget {
  const _InterviewerSheet({required this.people, this.current});
  final List<Map<String, dynamic>> people;
  final int? current;
  @override
  State<_InterviewerSheet> createState() => _InterviewerSheetState();
}

class _InterviewerSheetState extends State<_InterviewerSheet> {
  late final TextEditingController _search = TextEditingController();
  late int? _selected = widget.current;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final rows = widget.people
        .where(
          (row) =>
              query.isEmpty ||
              talentText(row['userName']).toLowerCase().contains(query) ||
              talentText(row['department'], '').toLowerCase().contains(query),
        )
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.66,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '选择面试官',
                      style: TextStyle(
                        color: AppColors.brand,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: TextField(
                key: const Key('interviewer-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '搜索面试官',
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.fieldBackground,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无匹配面试官',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      children: [
                        for (final row in rows)
                          _interviewerRow(row),
                      ],
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(
                color: AppColors.canvas,
                border: Border(top: BorderSide(color: AppColors.hairline)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        key: const Key('interviewer-cancel'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          minimumSize: const Size(0, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const Key('interviewer-confirm'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          minimumSize: const Size(0, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, _selected),
                        child: const Text('确定'),
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

  Widget _interviewerRow(Map<String, dynamic> row) {
    final id = talentId(row['userId'])!;
    final selected = _selected == id;
    final parts = [
      talentText(row['userName']),
      talentText(row['department'], ''),
      talentText(row['jobTitle'], ''),
    ].where((part) => part.isNotEmpty).join(' · ');
    return InkWell(
      key: ValueKey('interviewer-option-$id'),
      onTap: () => setState(() => _selected = id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.tealSoft.withValues(alpha: .55)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_outline, size: 20, color: AppColors.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                parts,
                style: TextStyle(
                  color: selected ? AppColors.tealDeep : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.teal, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    const dash = 6.0, gap = 4.0;
    final radius = Radius.circular(size.width > 0 ? 8 : 0);
    final rect = Offset.zero & size;
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));
    final metrics = path.computeMetrics().first;
    var distance = 0.0;
    while (distance < metrics.length) {
      canvas.drawPath(
        metrics.extractPath(distance, math.min(distance + dash, metrics.length)),
        paint,
      );
      distance += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color;
}
