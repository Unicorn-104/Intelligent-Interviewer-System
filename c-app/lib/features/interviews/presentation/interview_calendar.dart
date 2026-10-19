import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/formatters/backend_date.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/async_state_card.dart';
import '../../../widgets/section_header.dart';
import '../domain/interview_schedule.dart';
import 'interview_controller.dart';

class InterviewCalendar extends StatefulWidget {
  const InterviewCalendar({
    super.key,
    required this.controller,
    required this.onOpen,
  });
  final InterviewController controller;
  final Future<void> Function(InterviewSchedule) onOpen;

  @override
  State<InterviewCalendar> createState() => _InterviewCalendarState();
}

class _InterviewCalendarState extends State<InterviewCalendar> {
  Timer? _timer;
  final ScrollController _dateScroll = ScrollController();
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => widget.controller.tick(),
    );
    _alignDate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dateScroll.dispose();
    super.dispose();
  }

  void _alignDate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_dateScroll.hasClients) return;
      final day = DateTime.parse(widget.controller.selectedDate).day;
      final target =
          (day - 1) *
          (MediaQuery.textScalerOf(context).scale(AppSpacing.minTouch) +
              AppSpacing.sm);
      _dateScroll.jumpTo(
        target.clamp(0.0, _dateScroll.position.maxScrollExtent),
      );
    });
  }

  Future<void> _changeMonth(int offset) async {
    final future = widget.controller.changeMonth(offset);
    _alignDate();
    await future;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final month = controller.month;
      final days = DateTime(month.year, month.month + 1, 0).day;
      final selected = controller.selectedItems;
      final upcoming = controller.upcoming;
      final marked = controller.markedDates;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '面试', subtitle: '查看面试日程，提前安排时间'),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${month.year}年${month.month}月',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: '上个月',
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        tooltip: '下个月',
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      TextButton(
                        onPressed: () {
                          controller.today();
                          _alignDate();
                        },
                        child: const Text('今天'),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        child: Text(_expanded ? '收起月历' : '展开月历'),
                      ),
                      TextButton(
                        onPressed: controller.loading ? null : controller.load,
                        child: const Text('刷新日程'),
                      ),
                    ],
                  ),
                  if (controller.loading) const LinearProgressIndicator(),
                  const SizedBox(height: AppSpacing.sm),
                  if (_expanded)
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (var day = 1; day <= days; day++)
                          _dateButton(
                            DateTime(month.year, month.month, day),
                            marked,
                          ),
                      ],
                    )
                  else
                    SizedBox(
                      height: MediaQuery.textScalerOf(
                        context,
                      ).scale(AppSpacing.minTouch + AppSpacing.xxl),
                      child: ListView.separated(
                        controller: _dateScroll,
                        scrollDirection: Axis.horizontal,
                        itemCount: days,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (_, index) => _dateButton(
                          DateTime(month.year, month.month, index + 1),
                          marked,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${controller.selectedDate} · ${selected.length} 场面试',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (controller.error case final error?)
                    AsyncStateCard(
                      title: '面试日程加载失败',
                      message: error,
                      icon: Icons.wifi_off_outlined,
                      onRetry: controller.load,
                    )
                  else if (controller.initialized && selected.isEmpty)
                    const AsyncStateCard(
                      title: '当天暂无面试',
                      message: '可切换日期查看安排。',
                      icon: Icons.event_available_outlined,
                    ),
                  if (controller.error == null)
                    for (final item in selected) ...[
                      InterviewTile(
                        item: item,
                        onTap: () => widget.onOpen(item),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  if (controller.initialized && controller.error == null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '本月接下来的面试',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (upcoming.isEmpty) const Text('本月暂无接下来的面试，可切换月份查看。'),
                    for (final item in upcoming) ...[
                      InterviewTile(
                        item: item,
                        highlight: true,
                        onTap: () => widget.onOpen(item),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _dateButton(DateTime date, Set<String> marked) {
    final key = dateKey(date);
    final hasInterview = marked.contains(key);
    final selected = key == widget.controller.selectedDate;
    final today = key == dateKey(widget.controller.now());
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Semantics(
      label: '$key${today ? '，今天' : ''}${hasInterview ? '，有面试' : '，暂无面试'}',
      selected: selected,
      button: true,
      child: SizedBox(
        width: MediaQuery.textScalerOf(context).scale(AppSpacing.minTouch),
        child: TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.all(AppSpacing.xs),
            backgroundColor: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            foregroundColor: selected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : null,
          ),
          onPressed: () => widget.controller.select(date),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(today ? '今' : weekdays[date.weekday - 1]),
              Text('${date.day}'),
              Text(
                hasInterview ? '●' : ' ',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InterviewTile extends StatelessWidget {
  const InterviewTile({
    super.key,
    required this.item,
    required this.onTap,
    this.highlight = false,
  });
  final InterviewSchedule item;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Card(
    color: highlight ? Theme.of(context).colorScheme.primaryContainer : null,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.positionTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(item.companyName),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${item.dayKey ?? '日期待定'} ${scheduleTime(item.startAt)} – ${scheduleTime(item.endAt)}',
            ),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                Chip(label: Text(item.statusText)),
                Chip(label: Text(interviewModeLabel(item.mode))),
              ],
            ),
            const Text('查看面试详情'),
          ],
        ),
      ),
    ),
  );
}
