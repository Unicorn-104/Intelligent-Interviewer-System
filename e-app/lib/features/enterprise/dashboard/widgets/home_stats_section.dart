import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../home_models.dart';

class HomeStatsSection extends StatelessWidget {
  const HomeStatsSection({super.key, required this.stats});
  final HomeStats stats;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (index, entry) in stats.values.indexed) ...[
        if (index > 0)
          const SizedBox(
            height: 40,
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.hairline,
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Builder(
              builder: (context) {
                final (icon, color) = switch (entry.$1) {
                  '在招岗位' => (Icons.work_outline_rounded, AppColors.interactive),
                  '待面试' => (Icons.event_available_outlined, AppColors.warning),
                  '待终审' => (Icons.fact_check_outlined, AppColors.accentPurple),
                  _ => (Icons.task_alt_rounded, AppColors.success),
                };
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ExcludeSemantics(
                            child: Icon(icon, color: color, size: 16),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.$2 ?? '—'}',
                            key: ValueKey('home-stat-${entry.$1}'),
                            style: TextStyle(
                              color: color,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        entry.$1,
                        maxLines: 1,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    ],
  );
}
