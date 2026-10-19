import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../models/talent_detail_view_data.dart';

class TalentStatusBadge extends StatelessWidget {
  const TalentStatusBadge({super.key, required this.status});

  final Object? status;

  static (IconData, Color) visualFor(Object? status) =>
      switch (int.tryParse('$status')) {
        0 => (Icons.person_add_alt_1, AppColors.muted),
        1 => (Icons.check_circle_outline, AppColors.success),
        2 => (Icons.arrow_forward, AppColors.interactive),
        3 => (Icons.cancel_outlined, AppColors.error),
        4 => (Icons.check_circle, AppColors.success),
        5 => (Icons.verified, AppColors.success),
        6 => (Icons.logout, AppColors.muted),
        7 => (Icons.people_outline, AppColors.interactive),
        8 => (Icons.block, AppColors.error),
        9 => (Icons.pause_circle_outline, AppColors.warning),
        _ => (Icons.help_outline, AppColors.muted),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = visualFor(status);
    final label = talentStatus(status);
    return Semantics(
      label: '候选人状态：$label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
