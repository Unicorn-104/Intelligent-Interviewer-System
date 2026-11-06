import 'package:flutter/material.dart';

import '../../../../core/constants/application_status.dart';
import '../../../../theme/app_theme.dart';
import '../models/talent_detail_view_data.dart';

class TalentStatusBadge extends StatelessWidget {
  const TalentStatusBadge({super.key, required this.status, this.currentStage});

  final Object? status;

  /// 后端当前节点文案（字段来源：currentStage / currentNodeLabel），
  /// 仅在「招聘中」时作为旁注展示，不写库。
  final String? currentStage;

  static (IconData, Color) visualFor(Object? status) {
    final item = ApplicationStatus.byCode(status);
    return item == null
        ? (Icons.help_outline, AppColors.muted)
        : (item.icon, item.color);
  }

  @override
  Widget build(BuildContext context) {
    final item = ApplicationStatus.byCode(status);
    final (icon, color) = item == null ? visualFor(status) : (item.icon, item.color);
    final label = talentStatus(status);
    return Semantics(
      label: '候选人投递状态：$label',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
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
          // 招聘中旁注当前环节（展示用，不写库）。
          if (item == ApplicationStatus.inProgress &&
              (currentStage?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(width: 6),
            ApplicationStageSuffix(
              appStatus: status,
              currentStage: currentStage,
            ),
          ],
        ],
      ),
    );
  }
}
