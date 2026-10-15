import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../home_models.dart';

class HomeInterviewRow extends StatelessWidget {
  const HomeInterviewRow({
    super.key,
    required this.interview,
    required this.onOpen,
  });
  final HomeInterview interview;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                interview.candidate,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                interview.statusLabel,
                style: const TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            interview.position,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            interview.timeLabel,
            style: const TextStyle(
              color: AppColors.brand,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
      final button = OutlinedButton(
        key: ValueKey('home-interview-${interview.id}'),
        onPressed: onOpen,
        child: const Text('查看面试'),
      );
      if (constraints.maxWidth < 340) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            content,
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: button),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: content),
          const SizedBox(width: 12),
          button,
        ],
      );
    },
  );
}
