import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../talent/data/talent_detail_data_source.dart';
import '../../talent/widgets/talent_interview_reschedule_sheet.dart';
import '../home_models.dart';

/// Shared appointment card with an injectable future meeting entry point.
class HomeInterviewPreview extends StatefulWidget {
  const HomeInterviewPreview({
    super.key,
    required this.interview,
    required this.onOpen,
    this.now,
    this.onViewJob,
    this.onViewCandidate,
    this.onReschedule,
    this.rescheduleSource,
    this.onRescheduled,
  });

  final HomeInterview interview;
  final VoidCallback onOpen;
  final VoidCallback? onViewJob;
  final VoidCallback? onViewCandidate;
  final VoidCallback? onReschedule;
  final TalentDetailDataSource? rescheduleSource;
  final Future<void> Function()? onRescheduled;
  final DateTime Function()? now;

  @override
  State<HomeInterviewPreview> createState() => _HomeInterviewPreviewState();
}

class _HomeInterviewPreviewState extends State<HomeInterviewPreview>
    with WidgetsBindingObserver {
  bool _rescheduling = false;
  Timer? _boundaryTimer;
  Timer? _hintTimer;
  OverlayEntry? _hintEntry;
  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleBoundary();
  }

  @override
  void didUpdateWidget(covariant HomeInterviewPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleBoundary();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      _scheduleBoundary();
    } else {
      _boundaryTimer?.cancel();
      _hideHint();
    }
  }

  void _scheduleBoundary() {
    _boundaryTimer?.cancel();
    if (!TickerMode.valuesOf(context).enabled ||
        (widget.interview.status != 0 && widget.interview.status != 1)) {
      return;
    }
    final now = _now;
    final future = [
      widget.interview.startTime,
      ?widget.interview.endTime,
    ].where((time) => time.isAfter(now)).toList()..sort();
    if (future.isEmpty) return;
    _boundaryTimer = Timer(future.first.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleBoundary();
    });
  }

  @override
  void dispose() {
    _boundaryTimer?.cancel();
    _hideHint();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _detail(
    IconData icon,
    String label,
    String value, {
    Color textColor = AppColors.textSecondary,
  }) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$label：$value',
            style: TextStyle(color: textColor, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    ),
  );

  void _showStartHint() {
    final interview = widget.interview;
    final message = switch (interview.status) {
      2 => '面试已取消',
      3 => '面试已完成',
      0 || 1 => _now.isBefore(interview.startTime) ? '到预约时间后可开始' : '面试已失效',
      _ => '面试状态暂不可用',
    };
    _showHint(message);
  }

  Future<void> _reschedule() async {
    if (_rescheduling) return;
    final interview = widget.interview;
    if ((interview.status != 0 && interview.status != 1) ||
        !interview.startTime.isAfter(_now)) {
      _showHint('仅未开始且未取消的面试可以改期');
      return;
    }
    final source = widget.rescheduleSource;
    if (source == null) return;
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
            source: source,
            now: widget.now,
          ),
        ),
      );
      if (mounted) await widget.onRescheduled?.call();
    } finally {
      if (mounted) setState(() => _rescheduling = false);
    }
  }

  void _showHint(String message) {
    _hideHint();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _hintEntry = OverlayEntry(
      builder: (_) => Positioned.fill(
        left: 16,
        right: 16,
        child: IgnorePointer(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Semantics(
                liveRegion: true,
                child: Material(
                  key: const ValueKey('home-interview-hint'),
                  color: AppColors.brandDeep,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.canvas,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_hintEntry!);
    _hintTimer = Timer(const Duration(seconds: 2), _hideHint);
  }

  void _hideHint() {
    _hintTimer?.cancel();
    _hintTimer = null;
    _hintEntry?.remove();
    _hintEntry?.dispose();
    _hintEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final interview = widget.interview;
    final now = _now;
    final expired = interview.isExpiredAt(now);
    final (label, icon, color) = expired
        ? ('已失效', Icons.event_busy_outlined, AppColors.textMuted)
        : switch (interview.status) {
            0 => ('待面试', Icons.schedule, AppColors.warning),
            1 => ('已确认', Icons.check_circle_outline, AppColors.interactive),
            2 => ('已取消', Icons.cancel_outlined, AppColors.textMuted),
            3 => ('已完成', Icons.task_alt_rounded, AppColors.success),
            _ => ('状态未知', Icons.help_outline, AppColors.textMuted),
          };
    final detailColor = expired ? AppColors.textMuted : AppColors.textSecondary;
    final enabled = interview.canStartAt(now);
    final status = Container(
      key: ValueKey('home-interview-status-${interview.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label, style: TextStyle(color: color, fontSize: 12)),
          ),
        ],
      ),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: .16),
            color.withValues(alpha: .07),
            AppColors.canvas,
          ],
          stops: const [0, .3, .55],
        ),
      ),
      child: Material(
        color: AppColors.canvas.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('home-interview-job-${interview.id}'),
          onTap: widget.onViewJob,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Tooltip(
                      message: widget.onViewCandidate == null
                          ? '候选人信息暂不可用'
                          : '查看候选人详情',
                      child: Semantics(
                        button: widget.onViewCandidate != null,
                        label: '查看${interview.candidate}的详情',
                        child: GestureDetector(
                          key: ValueKey(
                            'home-interview-candidate-${interview.id}',
                          ),
                          behavior: HitTestBehavior.opaque,
                          // Always consume avatar taps; never fall through to the job card.
                          onTap: () => widget.onViewCandidate?.call(),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: expired
                                    ? AppColors.background
                                    : AppColors.interactiveSoft,
                                child: Icon(
                                  Icons.person_outline,
                                  color: expired
                                      ? AppColors.textMuted
                                      : AppColors.interactive,
                                  size: 21,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        interview.candidate,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: expired
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: status,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  interview.position,
                  style: TextStyle(
                    color: expired ? AppColors.textMuted : AppColors.brand,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final details = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detail(
                          Icons.badge_outlined,
                          '面试官',
                          homeText(interview.raw['interviewerName'], '未提供'),
                          textColor: detailColor,
                        ),
                        _detail(
                          Icons.access_time_rounded,
                          '开始时间',
                          HomeInterview.formatServerTime(interview.startTime)
                              .substring(0, 16),
                          textColor: detailColor,
                        ),
                        _detail(
                          Icons.event_available_outlined,
                          '结束时间',
                          interview.endTime == null
                              ? '未提供'
                              : HomeInterview.formatServerTime(
                                  interview.endTime!,
                                ).substring(0, 16),
                          textColor: detailColor,
                        ),
                      ],
                    );
                    final button = GestureDetector(
                      key: ValueKey('home-interview-action-${interview.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: enabled ? null : _showStartHint,
                      child: AbsorbPointer(
                        absorbing: !enabled,
                        child: OutlinedButton(
                          key: ValueKey('home-interview-${interview.id}'),
                          onPressed: enabled
                              ? () {
                                  if (interview.canStartAt(_now)) {
                                    widget.onOpen();
                                  } else {
                                    _showStartHint();
                                  }
                                }
                              : null,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            foregroundColor: AppColors.interactive,
                            side: BorderSide(
                              color: enabled
                                  ? AppColors.interactive
                                  : AppColors.hairline,
                            ),
                          ),
                          child: const Text('开始面试'),
                        ),
                      ),
                    );
                    final actions = Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (widget.onReschedule != null ||
                            widget.rescheduleSource != null)
                          OutlinedButton(
                            key: ValueKey(
                              'job-interview-reschedule-${interview.id}',
                            ),
                            onPressed: _rescheduling
                                ? null
                                : widget.onReschedule ?? _reschedule,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            child: const Text('改期'),
                          ),
                        button,
                      ],
                    );
                    final scale = MediaQuery.textScalerOf(context).scale(1);
                    if (constraints.maxWidth >= 300 * scale) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: details),
                          const SizedBox(width: 8),
                          if (widget.onReschedule == null &&
                              widget.rescheduleSource == null)
                            button
                          else
                            Flexible(child: actions),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        details,
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child:
                              widget.onReschedule == null &&
                                  widget.rescheduleSource == null
                              ? button
                              : actions,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
