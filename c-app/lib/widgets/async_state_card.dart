import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AsyncStateCard extends StatelessWidget {
  const AsyncStateCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
    this.onRetry,
    this.actionLabel = '重新加载',
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}
