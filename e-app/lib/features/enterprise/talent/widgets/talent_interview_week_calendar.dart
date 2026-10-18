import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../../../theme/app_theme.dart';
import '../models/talent_detail_view_data.dart';

/// 日期格只显示当天数量；选中日期后在时间轴上展示实际面试安排。
class TalentInterviewWeekCalendar extends StatefulWidget {
  const TalentInterviewWeekCalendar({
    super.key,
    required this.weekStart,
    required this.appointments,
    required this.loading,
    required this.error,
    required this.today,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onRefresh,
    required this.onOpen,
    required this.onMove,
    required this.canEdit,
    required this.onChooseDay,
    required this.onChooseTime,
    this.selectedDay,
    this.enabled = true,
  });
  final DateTime weekStart, today;
  final DateTime? selectedDay;
  final List<Map<String, dynamic>> appointments;
  final bool loading, enabled;
  final String? error;
  final VoidCallback onPrevious, onNext, onToday, onRefresh;
  final ValueChanged<DateTime> onChooseDay;
  final void Function(DateTime, int hour, int minute) onChooseTime;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final bool Function(Map<String, dynamic>) canEdit;
  final void Function(Map<String, dynamic>, DateTime, int duration) onMove;
  @override
  State<TalentInterviewWeekCalendar> createState() =>
      _TalentInterviewWeekCalendarState();
}

class _TalentInterviewWeekCalendarState
    extends State<TalentInterviewWeekCalendar> {
  late DateTime _day;
  late final ScrollController _scroll;
  int? _previewId;
  (DateTime, DateTime)? _preview;
  static const _pixelsPerHour = 96.0;
  static const _dayLabels = ['一', '二', '三', '四', '五', '六', '日'];
  @override
  void initState() {
    super.initState();
    _day = _initialDay();
    _scroll = ScrollController(initialScrollOffset: 8 * _pixelsPerHour);
  }

  DateTime _initialDay() {
    final preferred = widget.selectedDay ?? widget.today;
    return preferred.isBefore(widget.weekStart) ||
            !preferred.isBefore(widget.weekStart.add(const Duration(days: 7)))
        ? widget.weekStart
        : DateTime(preferred.year, preferred.month, preferred.day);
  }

  @override
  void didUpdateWidget(covariant TalentInterviewWeekCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weekStart != widget.weekStart ||
        oldWidget.selectedDay != widget.selectedDay) {
      _day = _initialDay();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  DateTime? _start(Map<String, dynamic> row) =>
      TalentUtc8.parseServer(row['startTime']);
  DateTime? _end(Map<String, dynamic> row) =>
      TalentUtc8.parseServer(row['endTime']);
  List<Map<String, dynamic>> _onDay(DateTime day) {
    final start = TalentUtc8.fromSelection(day, 0, 0);
    final end = start.add(const Duration(days: 1));
    return widget.appointments.where((row) {
      if (int.tryParse('${row['status']}') == 2) return false;
      final a = _start(row), b = _end(row);
      return a != null && b != null && TalentUtc8.overlaps(start, end, a, b);
    }).toList()..sort((a, b) => _start(a)!.compareTo(_start(b)!));
  }

  Color _countColor(int count) => count <= 5
      ? AppColors.success
      : count <= 10
      ? AppColors.warning
      : AppColors.error;
  Color _eventColor(Map<String, dynamic> row) =>
      switch (int.tryParse('${row['status']}')) {
        0 => AppColors.warning,
        1 => AppColors.interactive,
        3 => AppColors.textMuted,
        _ => AppColors.textMuted,
      };
  @override
  Widget build(BuildContext context) {
    final rows = _onDay(_day);
    final controlsEnabled = widget.enabled && !widget.loading;
    final last = widget.weekStart.add(const Duration(days: 6));
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.weekStart.year}年${widget.weekStart.month}月${widget.weekStart.day}日 — ${last.month}月${last.day}日',
              style: const TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: '上一周',
                  onPressed: controlsEnabled ? widget.onPrevious : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: '下一周',
                  onPressed: controlsEnabled ? widget.onNext : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                const Spacer(),
                TextButton(
                  onPressed: controlsEnabled ? widget.onToday : null,
                  child: const Text('今天'),
                ),
                IconButton(
                  tooltip: '刷新日历',
                  onPressed: controlsEnabled ? widget.onRefresh : null,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            Row(
              children: [
                for (var index = 0; index < 7; index++)
                  Expanded(child: _dateTile(index, controlsEnabled)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '≤5场 绿 · 6–10场 黄 · >10场 红',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 6),
            Text(
              '${_day.month}月${_day.day}日 · ${widget.error != null || widget.loading ? '查询中' : '${rows.length}场面试'}',
              style: const TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.loading) const LinearProgressIndicator(minHeight: 2),
            if (widget.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  widget.error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            if (widget.error == null)
              SizedBox(
                height: 420,
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: _timeline(rows, controlsEnabled),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dateTile(int index, bool enabled) {
    final date = widget.weekStart.add(Duration(days: index));
    final color = _countColor(_onDay(date).length);
    final selected = DateUtils.isSameDay(date, _day);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Material(
        color: color.withValues(alpha: selected ? .2 : .08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
            color: selected ? AppColors.interactive : AppColors.hairline,
          ),
        ),
        child: InkWell(
          key: ValueKey('interview-calendar-day-$index'),
          onTap: enabled
              ? () {
                  setState(() => _day = date);
                  widget.onChooseDay(date);
                }
              : null,
          child: SizedBox(
            height: 68,
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '周${_dayLabels[index]}\n${date.day}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected
                            ? AppColors.brand
                            : AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 3,
                  child: Text(
                    widget.loading || widget.error != null
                        ? '—'
                        : '${_onDay(date).length}',
                    key: ValueKey('interview-calendar-count-$index'),
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeline(List<Map<String, dynamic>> rows, bool enabled) {
    final dayStart = TalentUtc8.fromSelection(_day, 0, 0);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final laneEnds = <DateTime>[];
    final lanes = <int, int>{};
    for (final row in rows) {
      final start = _start(row)!;
      var lane = laneEnds.indexWhere((end) => !end.isAfter(start));
      if (lane < 0) {
        lane = laneEnds.length;
        laneEnds.add(_end(row)!);
      } else {
        laneEnds[lane] = _end(row)!;
      }
      lanes[talentId(row['appointmentId'])!] = lane;
    }
    final laneCount = math.max(1, laneEnds.length);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, 42 + laneCount * 115.0);
        final columnWidth = (width - 42) / laneCount;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: 24 * _pixelsPerHour,
            child: Stack(
              children: [
                Positioned.fill(
                  left: 42,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: enabled
                        ? (details) {
                            final minutes =
                                ((details.localPosition.dy /
                                            _pixelsPerHour *
                                            60) /
                                        15)
                                    .floor() *
                                15;
                            widget.onChooseTime(
                              _day,
                              minutes ~/ 60,
                              minutes % 60,
                            );
                          }
                        : null,
                    child: const ColoredBox(color: AppColors.canvas),
                  ),
                ),
                for (var hour = 0; hour < 24; hour++) ...[
                  Positioned(
                    top: hour * _pixelsPerHour,
                    left: 0,
                    width: 38,
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Positioned(
                    top: hour * _pixelsPerHour,
                    left: 42,
                    right: 0,
                    child: const Divider(height: 1, color: AppColors.hairline),
                  ),
                ],
                for (final row in rows)
                  Builder(
                    builder: (context) {
                      final id = talentId(row['appointmentId'])!;
                      final originalStart = _start(row)!;
                      final originalEnd = _end(row)!;
                      final preview = _previewId == id ? _preview : null;
                      final start = preview?.$1 ?? originalStart;
                      final end = preview?.$2 ?? originalEnd;
                      final visibleStart = start.isBefore(dayStart)
                          ? dayStart
                          : start.isAfter(dayEnd)
                          ? dayEnd
                          : start;
                      final visibleEnd = end.isAfter(dayEnd)
                          ? dayEnd
                          : end.isBefore(dayStart)
                          ? dayStart
                          : end;
                      final minutes = visibleEnd
                          .difference(visibleStart)
                          .inMinutes;
                      final top =
                          visibleStart.difference(dayStart).inMinutes *
                          _pixelsPerHour /
                          60;
                      return Positioned(
                        top: top.clamp(0, 24 * _pixelsPerHour - 4),
                        left: 44 + lanes[id]! * columnWidth,
                        width: columnWidth - 5,
                        height: math.max(4, minutes * _pixelsPerHour / 60),
                        child: _CalendarEvent(
                          key: ValueKey('interview-event-$id'),
                          row: row,
                          color: _eventColor(row),
                          pixelsPerHour: _pixelsPerHour,
                          canEdit: () =>
                              widget.enabled &&
                              !widget.loading &&
                              widget.canEdit(row),
                          showStartHandle: !originalStart.isBefore(dayStart),
                          showEndHandle: !originalEnd.isAfter(dayEnd),
                          displayedStart: start,
                          displayedEnd: end,
                          onOpen: widget.enabled
                              ? () => widget.onOpen(row)
                              : null,
                          onPreview: (range) => setState(() {
                            _previewId = range == null ? null : id;
                            _preview = range;
                          }),
                          onChange: (range) {
                            setState(() {
                              _previewId = null;
                              _preview = null;
                            });
                            if (widget.enabled &&
                                !widget.loading &&
                                widget.canEdit(row)) {
                              widget.onMove(
                                row,
                                range.$1,
                                range.$2.difference(range.$1).inMinutes,
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _CalendarDrag { move, start, end }

class _CalendarEvent extends StatefulWidget {
  const _CalendarEvent({
    super.key,
    required this.row,
    required this.color,
    required this.pixelsPerHour,
    required this.canEdit,
    required this.showStartHandle,
    required this.showEndHandle,
    required this.displayedStart,
    required this.displayedEnd,
    required this.onOpen,
    required this.onPreview,
    required this.onChange,
  });
  final Map<String, dynamic> row;
  final Color color;
  final double pixelsPerHour;
  final bool Function() canEdit;
  final bool showStartHandle, showEndHandle;
  final DateTime displayedStart, displayedEnd;
  final VoidCallback? onOpen;
  final ValueChanged<(DateTime, DateTime)?> onPreview;
  final ValueChanged<(DateTime, DateTime)> onChange;
  @override
  State<_CalendarEvent> createState() => _CalendarEventState();
}

class _CalendarEventState extends State<_CalendarEvent> {
  _CalendarDrag? _mode;
  double _distance = 0;
  late DateTime _anchorStart, _anchorEnd;

  void _begin(_CalendarDrag mode) {
    if (!widget.canEdit()) return;
    _mode = mode;
    _distance = 0;
    _anchorStart = TalentUtc8.parseServer(widget.row['startTime'])!;
    _anchorEnd = TalentUtc8.parseServer(widget.row['endTime'])!;
  }

  (DateTime, DateTime) _range() {
    final delta = (_distance / widget.pixelsPerHour * 4).round() * 15;
    final duration = _anchorEnd.difference(_anchorStart).inMinutes;
    return switch (_mode!) {
      _CalendarDrag.move => (
        _anchorStart.add(Duration(minutes: delta)),
        _anchorEnd.add(Duration(minutes: delta)),
      ),
      _CalendarDrag.start => (
        _anchorEnd.subtract(
          Duration(minutes: (duration - delta).clamp(1, 1440)),
        ),
        _anchorEnd,
      ),
      _CalendarDrag.end => (
        _anchorStart,
        _anchorStart.add(Duration(minutes: (duration + delta).clamp(1, 1440))),
      ),
    };
  }

  void _change(double distance) {
    if (_mode == null) return;
    if (!widget.canEdit()) {
      _cancel();
      return;
    }
    _distance = distance;
    widget.onPreview(_range());
  }

  void _finish() {
    if (_mode == null) return;
    final range = _range();
    final changed = range.$1 != _anchorStart || range.$2 != _anchorEnd;
    _mode = null;
    if (changed && widget.canEdit()) {
      widget.onChange(range);
    } else {
      widget.onPreview(null);
    }
  }

  void _cancel() {
    if (_mode == null) return;
    _mode = null;
    widget.onPreview(null);
  }

  String _time(DateTime instant) =>
      TalentUtc8.serverTime(instant).substring(11, 16);

  Widget _handle(_CalendarDrag mode, double height) {
    final top = mode == _CalendarDrag.start;
    final id = widget.row['appointmentId'];
    return Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      height: height,
      child: Semantics(
        label: top ? '拖动调整开始时间' : '拖动调整结束时间',
        child: GestureDetector(
          key: ValueKey(
            top ? 'interview-resize-start-$id' : 'interview-resize-$id',
          ),
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onVerticalDragStart: (_) => _begin(mode),
          onVerticalDragUpdate: (details) =>
              _change(_distance + (details.primaryDelta ?? 0)),
          onVerticalDragEnd: (_) => _finish(),
          onVerticalDragCancel: _cancel,
          child: Center(
            child: Container(
              width: 26,
              height: 3,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: .7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final label =
          '${widget.row['candidateName'] ?? '候选人'} · ${widget.row['stageName'] ?? '面试'}';
      final editable = widget.canEdit();
      final handleHeight = math.min(20.0, constraints.maxHeight / 2);
      final topInset = editable && widget.showStartHandle ? handleHeight : 0.0;
      final bottomInset = editable && widget.showEndHandle ? handleHeight : 0.0;
      final contentHeight = math.max(
        0,
        constraints.maxHeight - topInset - bottomInset,
      );
      final time =
          '${_time(widget.displayedStart)}—${_time(widget.displayedEnd)}';
      return Semantics(
        label:
            '$label，${TalentUtc8.serverTime(widget.displayedStart)}至${TalentUtc8.serverTime(widget.displayedEnd)}',
        button: true,
        child: Listener(
          // 已识别的拖动在系统取消触摸时也可能回调 onEnd，先丢弃预览。
          onPointerCancel: (_) => _cancel(),
          child: Material(
            key: ValueKey(
              'interview-event-surface-${widget.row['appointmentId']}',
            ),
            color: widget.color.withValues(alpha: .15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: widget.color),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  top: topInset,
                  bottom: bottomInset,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onOpen,
                    onLongPressStart: editable
                        ? (_) => _begin(_CalendarDrag.move)
                        : null,
                    onLongPressMoveUpdate: editable
                        ? (details) => _change(details.offsetFromOrigin.dy)
                        : null,
                    onLongPressEnd: editable ? (_) => _finish() : null,
                    onLongPressCancel: _cancel,
                    child: ClipRect(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 3,
                        ),
                        child: contentHeight >= 20
                            ? Text(
                                contentHeight >= 54
                                    ? '$label\n${widget.row['positionTitle'] ?? ''}\n$time'
                                    : contentHeight >= 36
                                    ? '$label\n$time'
                                    : time,
                                maxLines: contentHeight >= 54
                                    ? 3
                                    : contentHeight >= 36
                                    ? 2
                                    : 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: widget.color,
                                  fontSize: 11,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                if (editable && widget.showStartHandle)
                  _handle(_CalendarDrag.start, handleHeight),
                if (editable && widget.showEndHandle)
                  _handle(_CalendarDrag.end, handleHeight),
              ],
            ),
          ),
        ),
      );
    },
  );
}
