import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 标注演示数据：整页可通过包裹 Scaffold 使用；局部数据可放在卡片中。
class DemoDataBadge extends StatelessWidget {
  const DemoDataBadge({super.key, required this.child, this.compact = false});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: child),
          const SizedBox(width: 6),
          const _Badge(),
        ],
      );
    }
    return Banner(
      message: '演示数据',
      location: BannerLocation.topStart,
      color: AppColors.orange,
      child: child,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.warningSoft,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Text(
      '演示数据',
      style: TextStyle(fontSize: 10, color: AppColors.orange),
    ),
  );
}
