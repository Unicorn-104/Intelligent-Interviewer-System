import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../home_models.dart';

class HomeApplicationRow extends StatelessWidget {
  const HomeApplicationRow({
    super.key,
    required this.application,
    required this.onOpen,
  });
  final HomeApplication application;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('home-job-${application.positionId}'),
    borderRadius: BorderRadius.circular(8),
    onTap: application.positionId == null ? null : onOpen,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  application.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${application.department} · ${application.city}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                Text(
                  '累计投递 ${application.applicants ?? '—'}',
                  style: const TextStyle(
                    color: AppColors.interactive,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (application.positionId == null)
                  const Text(
                    '岗位编号暂不可用',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    ),
  );
}
