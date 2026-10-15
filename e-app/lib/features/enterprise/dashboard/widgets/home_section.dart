import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class HomeSection extends StatelessWidget {
  const HomeSection({
    super.key,
    required this.title,
    required this.child,
    this.onMore,
    this.subtitle,
    this.wrapInCard = true,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onMore;
  final bool wrapInCard;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (onMore != null)
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              onPressed: onMore,
              child: const Text('更多'),
            ),
        ],
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(
          subtitle!,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
      const SizedBox(height: 12),
      if (wrapInCard)
        Card(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        )
      else
        child,
    ],
  );
}

/// A visible placeholder with one accessible description for the whole block.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key, this.rows = 3});
  final int rows;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '正在加载…',
    child: ExcludeSemantics(
      child: Column(
        children: [
          for (var index = 0; index < rows; index++) ...[
            if (index > 0) const SizedBox(height: 16),
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.hairline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(widthFactor: .65, child: _line(14)),
                      const SizedBox(height: 8),
                      FractionallySizedBox(widthFactor: .9, child: _line(10)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('正在加载…', style: TextStyle(color: AppColors.muted)),
          ),
        ],
      ),
    ),
  );

  static Widget _line(double height) => Container(
    height: height,
    decoration: BoxDecoration(
      color: AppColors.hairline,
      borderRadius: BorderRadius.circular(4),
    ),
  );
}
