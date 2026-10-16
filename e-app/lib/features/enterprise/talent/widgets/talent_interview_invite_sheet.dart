import 'package:flutter/material.dart';

import '../data/talent_detail_data_source.dart';
import '../models/talent_detail_view_data.dart';

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

class _TalentInterviewInviteSheetState
    extends State<TalentInterviewInviteSheet> {
  List<Map<String, dynamic>> _interviewers = [], _jobs = [];
  bool _loadingPeople = true,
      _loadingJobs = false,
      _moreJobs = false,
      _checking = false,
      _submitting = false,
      _uncertain = false;
  String? _peopleError, _jobsError, _availabilityError, _submitError;
  int? _interviewerId, _positionId;
  int _jobPage = 0, _availabilityRequest = 0;
  int _duration = 45;
  DateTime? _date;
  TimeOfDay? _time;
  bool? _busy;
  DateTime _now() => (widget.clock?.call() ?? DateTime.now()).toUtc();
  DateTime? get _start => _date == null || _time == null
      ? null
      : TalentUtc8.fromSelection(_date!, _time!.hour, _time!.minute);
  @override
  void initState() {
    super.initState();
    _positionId = widget.job?.positionId;
    _loadPeople();
    if (widget.job == null) {
      _loadJobs(reset: true);
    }
  }

  Future<void> _loadPeople() async {
    setState(() {
      _loadingPeople = true;
      _peopleError = null;
    });
    try {
      final rows = await widget.source.loadInterviewers();
      if (!mounted) {
        return;
      }
      setState(() => _interviewers = rows);
    } catch (error) {
      if (mounted) {
        setState(() => _peopleError = talentError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loadingPeople = false);
      }
    }
  }

  Future<void> _loadJobs({bool reset = false}) async {
    if (_loadingJobs) {
      return;
    }
    final page = reset ? 1 : _jobPage + 1;
    setState(() {
      _loadingJobs = true;
      _jobsError = null;
    });
    try {
      final rows = await widget.source.loadJobs(pageNum: page);
      if (rows.any((row) => talentId(row['posId']) == null)) {
        throw const FormatException('岗位标识无效');
      }
      if (!mounted) {
        return;
      }
      setState(() {
        final all = [if (!reset) ..._jobs, ...rows];
        final seen = <int>{};
        _jobs = all.where((row) => seen.add(talentId(row['posId'])!)).toList();
        _jobPage = page;
        _moreJobs = rows.length == 20;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _jobsError = talentError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loadingJobs = false);
      }
    }
  }

  Future<void> _chooseDate() async {
    final today = TalentUtc8.wallTime(_now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime(today.year, today.month, today.day),
      firstDate: DateTime(today.year, today.month, today.day),
      currentDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 2, 12, 31),
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() => _date = selected);
    await _checkAvailability();
  }

  Future<void> _chooseTime() async {
    final wall = TalentUtc8.wallTime(_now().add(const Duration(hours: 1)));
    final selected = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay(hour: wall.hour, minute: wall.minute),
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() => _time = selected);
    await _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final request = ++_availabilityRequest;
    final id = _interviewerId;
    final start = _start;
    setState(() {
      _busy = null;
      _availabilityError = null;
      _checking = id != null && start != null;
    });
    if (id == null || start == null) {
      return;
    }
    try {
      final end = start.add(Duration(minutes: _duration));
      final rows = await widget.source.loadAvailability(
        id,
        to: TalentUtc8.serverTime(end),
      );
      final busy = TalentUtc8.isBusy(rows, start, end);
      if (!mounted || request != _availabilityRequest) {
        return;
      }
      setState(() => _busy = busy);
    } catch (error) {
      if (mounted && request == _availabilityRequest) {
        setState(() => _availabilityError = talentError(error));
      }
    } finally {
      if (mounted && request == _availabilityRequest) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting || _uncertain) {
      return;
    }
    final position = _positionId;
    final interviewer = _interviewerId;
    final start = _start;
    if (position == null || interviewer == null || start == null) {
      setState(() => _submitError = '请选择岗位、面试官、日期和时间');
      return;
    }
    if (!start.isAfter(_now())) {
      setState(() => _submitError = '面试时间须晚于当前时间（UTC+8）');
      return;
    }
    final interviewerName = talentText(
      _interviewers.firstWhere(
        (row) => talentId(row['userId']) == interviewer,
      )['userName'],
    );
    final positionTitle =
        widget.job?.title ??
        talentText(
          _jobs.firstWhere(
            (row) => talentId(row['posId']) == position,
          )['title'],
        );
    final duration = _duration;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('确认发送面试邀约？'),
          content: SingleChildScrollView(
            child: Text(
              '候选人：${widget.candidateName}\n岗位：$positionTitle\n面试官：$interviewerName\n时间：${TalentUtc8.serverTime(start).substring(0, 16)}（UTC+8）\n时长：$duration 分钟',
            ),
          ),
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
      if (!mounted || confirmed != true) {
        return;
      }
      // 提交前重新查询；失败不得当作空闲。服务器仍负责最终冲突校验。
      final end = start.add(Duration(minutes: _duration));
      final rows = await widget.source.loadAvailability(
        interviewer,
        to: TalentUtc8.serverTime(end),
      );
      if (!mounted) {
        return;
      }
      if (TalentUtc8.isBusy(rows, start, end)) {
        setState(() {
          _busy = true;
          _submitError = '所选时段面试官已被占用，请调整时间';
        });
        return;
      }
      if (!start.isAfter(_now())) {
        setState(() => _submitError = '面试时间须晚于当前时间（UTC+8）');
        return;
      }
      final result = await widget.source.invite(
        candidateId: widget.candidateId,
        positionId: position,
        interviewerId: interviewer,
        startTime: TalentUtc8.serverTime(start),
        durationMin: _duration,
      );
      if (!mounted) {
        return;
      }
      if (talentId(result['appointmentId']) == null) {
        setState(() {
          _uncertain = true;
          _submitError = '服务已响应但未返回预约编号，请关闭并检查面试安排，避免重复邀约';
        });
        return;
      }
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _submitError = '${talentError(error)}。若已点击提交，请先检查面试安排再决定是否重试',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _submitting || _uncertain;
    return PopScope(
      canPop: !_submitting,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('邀请面试', style: Theme.of(context).textTheme.titleLarge),
              const Text('日期和时间均按 UTC+8 展示'),
              const SizedBox(height: 12),
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
                            value: talentId(row['posId'])!,
                            child: Text(talentText(row['title'])),
                          ),
                        )
                        .toList(),
                    onChanged: locked
                        ? null
                        : (value) => setState(() => _positionId = value),
                  ),
                if (_loadingJobs) const LinearProgressIndicator(),
                if (!_loadingJobs && _jobs.isEmpty && _jobsError == null)
                  const Text('暂无可邀约岗位'),
                if (_jobsError != null) Text(_jobsError!),
                if (_jobsError != null || (!_loadingJobs && _jobs.isEmpty))
                  TextButton(
                    onPressed: locked
                        ? null
                        : () => _loadJobs(reset: _jobPage == 0),
                    child: const Text('重试加载岗位'),
                  ),
                if (_moreJobs && !_loadingJobs)
                  TextButton(
                    onPressed: locked ? null : _loadJobs,
                    child: const Text('加载更多岗位'),
                  ),
              ],
              const SizedBox(height: 12),
              if (_loadingPeople)
                const LinearProgressIndicator()
              else if (_peopleError != null) ...[
                Text(_peopleError!),
                TextButton(
                  onPressed: locked ? null : _loadPeople,
                  child: const Text('重试加载面试官'),
                ),
              ] else if (_interviewers.isEmpty) ...[
                const Text('暂无可用面试官'),
                TextButton(
                  onPressed: locked ? null : _loadPeople,
                  child: const Text('刷新面试官'),
                ),
              ] else
                DropdownButtonFormField<int>(
                  key: const Key('invite-interviewer'),
                  initialValue: _interviewerId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '面试官'),
                  items: _interviewers
                      .map(
                        (row) => DropdownMenuItem(
                          value: talentId(row['userId'])!,
                          child: Text(
                            [
                              talentText(row['userName']),
                              talentText(row['department'], ''),
                              talentText(row['jobTitle'], ''),
                            ].where((part) => part.isNotEmpty).join(' · '),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: locked
                      ? null
                      : (value) {
                          setState(() => _interviewerId = value);
                          _checkAvailability();
                        },
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const Key('invite-date'),
                    onPressed: locked ? null : _chooseDate,
                    child: Text(
                      _date == null ? '选择日期' : TalentUtc8.dateLabel(_date!),
                    ),
                  ),
                  OutlinedButton(
                    key: const Key('invite-time'),
                    onPressed: locked ? null : _chooseTime,
                    child: Text(
                      _time == null
                          ? '选择时间'
                          : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<int>(
                key: const Key('invite-duration'),
                initialValue: _duration,
                decoration: const InputDecoration(labelText: '时长'),
                items: [
                  for (final minutes in [30, 45, 60, 90, 120])
                    DropdownMenuItem(
                      value: minutes,
                      child: Text('$minutes 分钟'),
                    ),
                ],
                onChanged: locked
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _duration = value);
                          _checkAvailability();
                        }
                      },
              ),
              const SizedBox(height: 12),
              if (_checking)
                const Text('正在检查面试官忙闲')
              else if (_availabilityError != null) ...[
                Text(_availabilityError!),
                TextButton(
                  onPressed: locked ? null : _checkAvailability,
                  child: const Text('重试查询忙闲'),
                ),
              ] else if (_busy == true)
                const Text('所选时段面试官已被占用')
              else if (_busy == false)
                const Text('当前查询未发现占用，提交时将再次核验'),
              if (_submitError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_submitError!),
                ),
              FilledButton(
                key: const Key('invite-submit'),
                onPressed:
                    locked ||
                        _loadingPeople ||
                        _loadingJobs ||
                        _checking ||
                        _peopleError != null ||
                        _jobsError != null ||
                        _availabilityError != null ||
                        _busy != false ||
                        _positionId == null ||
                        _interviewerId == null ||
                        _start == null
                    ? null
                    : _submit,
                child: Text(_submitting ? '正在提交' : '确认邀请'),
              ),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.pop(context, _uncertain),
                child: Text(_uncertain ? '关闭并查看面试安排' : '取消'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
