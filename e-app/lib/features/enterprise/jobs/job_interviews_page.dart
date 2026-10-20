import 'dart:async';

import 'package:flutter/material.dart';

import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import '../../../theme/app_theme.dart';
import '../dashboard/home_models.dart';
import '../dashboard/widgets/home_interview_preview.dart';
import 'data/job_detail_data_source.dart';
import 'models/job_detail_view_data.dart';
import '../talent/widgets/talent_interview_reschedule_sheet.dart';

class JobInterviewsPage extends StatefulWidget {
  const JobInterviewsPage({
    super.key,
    required this.positionId,
    required this.positionTitle,
    this.source = const JobDetailDataSource(),
    this.initialRange,
    this.onRangeChanged,
    this.detailBuilder,
    this.now,
    this.onStartInterview,
  });
  final int positionId;
  final String positionTitle;
  final JobDetailDataSource source;
  final DateTimeRange? initialRange;
  final ValueChanged<DateTimeRange?>? onRangeChanged;
  final Widget Function(Map<String, dynamic>)? detailBuilder;
  final DateTime Function()? now;
  final Future<void> Function(HomeInterview)? onStartInterview;

  @override
  State<JobInterviewsPage> createState() => _JobInterviewsPageState();
}

enum _InterviewFilter {
  all('全部'),
  pending('待面试'),
  confirmed('已确认'),
  completed('已完成'),
  cancelled('已取消'),
  expired('已失效'),
  unknown('状态未知');

  const _InterviewFilter(this.label);
  final String label;
}

class _JobInterviewsPageState extends State<JobInterviewsPage>
    with WidgetsBindingObserver {
  DateTimeRange? _range;
  bool _loading = true;
  bool _tooMany = false;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];
  int _request = 0;
  bool _descending = false;
  _InterviewFilter _filter = _InterviewFilter.all;
  Timer? _expiryTimer;
  Timer? _hintTimer;
  OverlayEntry? _hint;
  bool _rescheduling = false;
  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _range = widget.initialRange;
    _load();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _hideHint();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      _scheduleExpiry();
    } else {
      _expiryTimer?.cancel();
    }
  }

  HomeInterview? _interview(Map<String, dynamic> row) {
    final text = homeText(row['startTime'], '').replaceFirst(' ', 'T');
    final offset = RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(text);
    final start = DateTime.tryParse(offset ? text : '$text+08:00');
    if (start == null) return null;
    return HomeInterview(
      raw: Map.unmodifiable({
        ...row,
        'positionTitle': homeText(row['positionTitle'], widget.positionTitle),
      }),
      startTime: start,
      status: int.tryParse('${row['status']}') ?? -1,
    );
  }

  _InterviewFilter _status(HomeInterview item, DateTime now) {
    if (item.isExpiredAt(now)) return _InterviewFilter.expired;
    return switch (item.status) {
      0 => _InterviewFilter.pending,
      1 => _InterviewFilter.confirmed,
      2 => _InterviewFilter.cancelled,
      3 => _InterviewFilter.completed,
      _ => _InterviewFilter.unknown,
    };
  }

  List<HomeInterview> _visible() {
    final now = _now;
    final indexed =
        [
              for (final (index, row) in _rows.indexed)
                (index: index, item: _interview(row)),
            ]
            .where(
              (entry) =>
                  entry.item != null &&
                  (_filter == _InterviewFilter.all ||
                      _status(entry.item!, now) == _filter),
            )
            .toList();
    indexed.sort((a, b) {
      final order = a.item!.startTime.compareTo(b.item!.startTime);
      return order == 0
          ? a.index.compareTo(b.index)
          : (_descending ? -order : order);
    });
    return [for (final entry in indexed) entry.item!];
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final now = _now;
    final ends = [
      for (final row in _rows)
        if (_interview(row) case final item?)
          if ((item.status == 0 || item.status == 1) &&
              item.endTime != null &&
              item.endTime!.isAfter(now))
            item.endTime!,
    ]..sort();
    if (ends.isEmpty) return;
    _expiryTimer = Timer(ends.first.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleExpiry();
    });
  }

  void _hideHint() {
    _hintTimer?.cancel();
    _hintTimer = null;
    _hint?.remove();
    _hint?.dispose();
    _hint = null;
  }

  void _showHint(String message) {
    _hideHint();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _hint = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: IgnorePointer(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Material(
                color: AppColors.brandDeep,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Text(
                    message,
                    key: const Key('job-reschedule-hint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.canvas),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_hint!);
    _hintTimer = Timer(const Duration(seconds: 2), _hideHint);
  }

  Future<void> _reschedule(HomeInterview interview) async {
    if (_rescheduling) return;
    if ((interview.status != 0 && interview.status != 1) ||
        !interview.startTime.isAfter(_now)) {
      _showHint('仅未开始且未取消的面试可以改期');
      return;
    }
    _hideHint();
    setState(() => _rescheduling = true);
    try {
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: AppColors.canvas,
        builder: (_) => FractionallySizedBox(
          heightFactor: .9,
          child: TalentInterviewRescheduleSheet(
            appointment: interview.raw,
            source: widget.source.candidateActionsSource,
            now: widget.now,
          ),
        ),
      );
      if (mounted) await _load();
    } finally {
      if (mounted) setState(() => _rescheduling = false);
    }
  }

  Future<void> _start(HomeInterview interview) async {
    if (!interview.canStartAt(_now)) return;
    if (widget.onStartInterview == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('面试会议功能开发中，会议入口已预留')));
      return;
    }
    await widget.onStartInterview!(interview);
    if (mounted) await _load();
  }

  String _date(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (!mounted || range == null) {
      return;
    }
    setState(() => _range = range);
    widget.onRangeChanged?.call(range);
    await _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    _expiryTimer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
      _tooMany = false;
    });
    try {
      if (widget.positionId <= 0) {
        throw const FormatException('岗位数据缺少有效ID');
      }
      final from = _range == null ? null : '${_date(_range!.start)} 00:00:00';
      final to = _range == null ? null : '${_date(_range!.end)} 23:59:59';
      Future<List<Map<String, dynamic>>> page(int number) async {
        final rows = await widget.source.loadInterviews(
          pageNum: number,
          pageSize: 50,
          from: from,
          to: to,
        );
        if (rows.length > 50) {
          throw const FormatException('面试分页响应异常');
        }
        return rows;
      }

      final first = await page(1);
      final rows = [...first];
      if (first.length == 50) {
        final second = await page(2);
        rows.addAll(second);
        if (second.length == 50) {
          final probe = await page(3);
          if (probe.isNotEmpty) {
            if (!mounted || request != _request) {
              return;
            }
            setState(() {
              _tooMany = true;
              _rows = const [];
            });
            return;
          }
        }
      }
      if (!mounted || request != _request) {
        return;
      }
      setState(
        () => _rows = rows
            .where(
              (row) => jobPositiveId(row['positionId']) == widget.positionId,
            )
            .toList(),
      );
    } catch (error) {
      if (!mounted || request != _request) {
        return;
      }
      setState(() {
        _error = jobDetailError(error);
        _rows = const [];
      });
    } finally {
      if (mounted && request == _request) {
        setState(() => _loading = false);
        _scheduleExpiry();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${widget.positionTitle} · 面试安排',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: SafeArea(
      top: false,
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  key: const Key('job-interview-range'),
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    _range == null
                        ? '选择日期范围'
                        : '${_date(_range!.start)} ~ ${_date(_range!.end)}',
                  ),
                ),
                if (_range != null)
                  TextButton(
                    key: const Key('job-interview-clear'),
                    onPressed: () {
                      setState(() => _range = null);
                      widget.onRangeChanged?.call(null);
                      _load();
                    },
                    child: const Text('清除日期'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    key: const Key('job-interview-status-scroll'),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final status in _InterviewFilter.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              key: ValueKey(
                                'job-interview-filter-${status.name}',
                              ),
                              label: Text(status.label),
                              selected: _filter == status,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => _filter = status),
                              selectedColor: AppColors.interactiveSoft,
                              backgroundColor: AppColors.canvas,
                              side: BorderSide(
                                color: _filter == status
                                    ? AppColors.interactive
                                    : AppColors.hairline,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              labelStyle: TextStyle(
                                color: _filter == status
                                    ? AppColors.interactive
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: _descending
                      ? '当前从晚到早，点击切换为从早到晚'
                      : '当前从早到晚，点击切换为从晚到早',
                  child: SizedBox(
                    width: 100,
                    child: OutlinedButton(
                      key: const Key('job-interview-sort'),
                      onPressed: () =>
                          setState(() => _descending = !_descending),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(100, 46),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: AppColors.interactive,
                        backgroundColor: AppColors.canvas,
                        side: const BorderSide(color: AppColors.hairline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _descending
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _descending ? '时间倒序' : '时间正序',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    ),
  );

  Widget _body() {
    if (_loading) {
      return const SkeletonList(rows: 4);
    }
    if (_error != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '面试安排加载失败',
        message: _error!,
        onAction: _load,
      );
    }
    if (_tooMany) {
      return PageMessage(
        icon: Icons.filter_alt_outlined,
        title: '数据量过大，请缩小日期范围',
        message: '面试记录超过100条，请选择更短的日期范围',
        actionLabel: '选择日期范围',
        onAction: _pickRange,
      );
    }
    final visible = _visible();
    final invalid = _rows.where((row) => _interview(row) == null).length;
    if (visible.isEmpty) {
      return PageMessage(
        icon: Icons.event_busy_outlined,
        title: '暂无面试安排',
        message: invalid > 0
            ? '$invalid 条面试记录的开始时间无效，请刷新重试'
            : _filter == _InterviewFilter.all
            ? '当前岗位和日期范围内没有面试记录'
            : '当前岗位和日期范围内暂无「${_filter.label}」面试',
        actionLabel: _filter == _InterviewFilter.all ? '刷新' : '查看全部状态',
        onAction: _filter == _InterviewFilter.all
            ? _load
            : () => setState(() => _filter = _InterviewFilter.all),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        key: const Key('job-interview-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: visible.length + (invalid > 0 ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == visible.length) {
            return Text(
              '$invalid 条面试记录的开始时间无效，请刷新重试',
              style: const TextStyle(color: AppColors.warning, fontSize: 12),
            );
          }
          final interview = visible[index];
          return Card(
            child: HomeInterviewPreview(
              key: ValueKey('job-interview-card-${interview.id}'),
              interview: interview,
              now: () => _now,
              onOpen: () => _start(interview),
              onReschedule: () => _reschedule(interview),
            ),
          );
        },
      ),
    );
  }
}
