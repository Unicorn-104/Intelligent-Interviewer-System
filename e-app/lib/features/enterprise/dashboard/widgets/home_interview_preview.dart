import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../home_models.dart';

/// Home-only presentation; the full interview list keeps its existing row.
class HomeInterviewPreview extends StatelessWidget {
  const HomeInterviewPreview({
    super.key,
    required this.interview,
    required this.onOpen,
  });

  final HomeInterview interview;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color, background) = switch (interview.status) {
      0 => ('待确认', Icons.schedule, AppColors.warning, AppColors.warningSoft),
      1 => (
        '已确认',
        Icons.check_circle_outline,
        AppColors.interactive,
        AppColors.interactiveSoft,
      ),
      2 => (
        '已取消',
        Icons.cancel_outlined,
        AppColors.textMuted,
        AppColors.background,
      ),
      3 => (
        '已完成',
        Icons.task_alt_rounded,
        AppColors.success,
        AppColors.success.withValues(alpha: .08),
      ),
      _ => (
        '状态未知',
        Icons.help_outline_rounded,
        AppColors.textMuted,
        AppColors.background,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.canvas,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final status = Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(child: Icon(icon, size: 14, color: color)),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
          );
          final identity = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExcludeSemantics(
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.interactiveSoft,
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.interactive,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      interview.candidate,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      interview.position,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final time = Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  interview.timeLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          );
          final button = OutlinedButton(
            key: ValueKey('home-interview-${interview.id}'),
            onPressed: onOpen,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.interactive,
              side: const BorderSide(color: AppColors.interactive),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('查看面试'),
          );
          final scale = MediaQuery.textScalerOf(context).scale(1);
          if (constraints.maxWidth >= 480 * scale) {
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 16),
                Flexible(child: time),
                const SizedBox(width: 16),
                status,
                const SizedBox(width: 12),
                button,
              ],
            );
          }
          if (constraints.maxWidth >= 300 * scale) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      identity,
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 52),
                        child: time,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [status, const SizedBox(height: 8), button],
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (constraints.maxWidth >= 300 * scale)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 8),
                    status,
                  ],
                )
              else ...[
                identity,
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: status,
                ),
              ],
              const SizedBox(height: 12),
              if (constraints.maxWidth >= 280 * scale)
                Row(
                  children: [
                    Expanded(child: time),
                    const SizedBox(width: 8),
                    button,
                  ],
                )
              else ...[
                time,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: button),
              ],
            ],
          );
        },
      ),
    );
  }
}
