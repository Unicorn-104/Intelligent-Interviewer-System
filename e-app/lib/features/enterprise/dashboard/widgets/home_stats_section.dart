import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../home_models.dart';

class HomeStatsSection extends StatelessWidget {
  const HomeStatsSection({super.key, required this.stats});
  final HomeStats stats;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 560 ? 4 : 2;
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 24,
        children: [
          for (final entry in stats.values)
            SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.$2 ?? '—'}',
                    key: ValueKey('home-stat-${entry.$1}'),
                    style: const TextStyle(
                      color: AppColors.brand,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.$1,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
