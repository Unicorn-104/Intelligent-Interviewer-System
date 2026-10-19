import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

/// Calendar controls stay visible while the selected day's records load or fail.
class HomeInterviewCalendar extends StatefulWidget {
  const HomeInterviewCalendar({
    super.key,
    required this.selectedDate,
    required this.today,
    required this.onDateSelected,
    required this.onRefresh,
    required this.child,
    this.count,
  });

  final DateTime selectedDate;
  final DateTime today;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onRefresh;
  final int? count;
  final Widget child;

  @override
  State<HomeInterviewCalendar> createState() => _HomeInterviewCalendarState();
}

class _HomeInterviewCalendarState extends State<HomeInterviewCalendar> {
  bool _expanded = false;

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  void _move(int direction) {
    final selected = widget.selectedDate;
    if (!_expanded) {
      widget.onDateSelected(
        DateTime(selected.year, selected.month, selected.day + direction * 7),
      );
      return;
    }
    final month = DateTime(selected.year, selected.month + direction);
    final lastDay = DateUtils.getDaysInMonth(month.year, month.month);
    widget.onDateSelected(
      DateTime(month.year, month.month, selected.day.clamp(1, lastDay)),
    );
  }

  Widget _day(DateTime date) {
    final selected = DateUtils.isSameDay(date, widget.selectedDate);
    final today = DateUtils.isSameDay(date, widget.today);
    return Semantics(
      label: '${date.year}年${date.month}月${date.day}日${today ? '，今天' : ''}',
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: TextButton(
        key: ValueKey('home-calendar-day-${_dateKey(date)}'),
        onPressed: () => widget.onDateSelected(date),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          backgroundColor: selected
              ? AppColors.interactiveSoft
              : AppColors.canvas,
          foregroundColor: selected
              ? AppColors.interactive
              : AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(
              color: today ? AppColors.interactive : AppColors.canvas,
            ),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _action({
    required String key,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) => IconButton(
    key: ValueKey(key),
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      minimumSize: const Size(44, 46),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
      foregroundColor: AppColors.interactive,
      backgroundColor: AppColors.canvas,
    ),
    icon: Icon(icon, size: 20),
  );

  Widget _header(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final month = '${widget.selectedDate.year}年${widget.selectedDate.month}月';
      const monthStyle = TextStyle(
        color: AppColors.brand,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      );
      double textWidth(String text, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: DefaultTextStyle.of(context).style.merge(style),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final width = painter.width.ceilToDouble();
        painter.dispose();
        return width;
      }

      final minimumWidth = textWidth(month, monthStyle) + 236;
      final header = Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(month, style: monthStyle),
                IconButton(
                  key: const ValueKey('home-calendar-previous'),
                  tooltip: _expanded ? '上个月' : '上一周',
                  onPressed: () => _move(-1),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.brand,
                  ),
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                ),
                IconButton(
                  key: const ValueKey('home-calendar-next'),
                  tooltip: _expanded ? '下个月' : '下一周',
                  onPressed: () => _move(1),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.brand,
                  ),
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _action(
            key: 'home-calendar-today',
            icon: Icons.today_outlined,
            tooltip: '跳转到今天',
            onPressed: () => widget.onDateSelected(widget.today),
          ),
          const SizedBox(width: 4),
          _action(
            key: 'home-calendar-expand',
            icon: _expanded
                ? Icons.unfold_less_rounded
                : Icons.calendar_month_outlined,
            tooltip: _expanded ? '收起月历' : '展开月历',
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
          const SizedBox(width: 4),
          _action(
            key: 'home-calendar-refresh',
            tooltip: '刷新日程',
            icon: Icons.refresh_rounded,
            onPressed: widget.onRefresh,
          ),
        ],
      );
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: constraints.maxWidth < minimumWidth
              ? minimumWidth
              : constraints.maxWidth,
          child: header,
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedDate;
    final start = _expanded
        ? DateTime(selected.year, selected.month)
        : DateTime(selected.year, selected.month, selected.day);
    final first = DateTime(
      start.year,
      start.month,
      start.day - start.weekday + 1,
    );
    final monthDays = DateUtils.getDaysInMonth(selected.year, selected.month);
    final weeks = _expanded ? (start.weekday - 1 + monthDays + 6) ~/ 7 : 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(context),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final label in const ['一', '二', '三', '四', '五', '六', '日'])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var week = 0; week < weeks; week++) ...[
          if (week > 0) const SizedBox(height: 4),
          Row(
            children: [
              for (var day = 0; day < 7; day++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Builder(
                      builder: (context) {
                        final date = DateTime(
                          first.year,
                          first.month,
                          first.day + week * 7 + day,
                        );
                        if (_expanded && date.month != selected.month) {
                          return const SizedBox(height: 44);
                        }
                        return _day(date);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.hairline),
        const SizedBox(height: 12),
        Row(
          key: const ValueKey('home-calendar-summary'),
          children: [
            Expanded(
              child: Text(
                _dateKey(selected),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.brand,
                ),
              ),
            ),
            if (widget.count != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${widget.count}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppColors.interactive,
                        ),
                      ),
                      const TextSpan(text: ' 场面试'),
                    ],
                  ),
                  key: const ValueKey('home-calendar-count'),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        widget.child,
      ],
    );
  }
}
