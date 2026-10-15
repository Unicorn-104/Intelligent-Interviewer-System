import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 加载骨架屏：列表页在模拟加载期间展示的占位卡片组（P1 新增通用组件）。
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.rows = 4, this.showHeader = false});

  final int rows;
  final bool showHeader;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 1,
      ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        itemCount: widget.rows,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => const _SkeletonCard(),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _Box(height: 16, widthFactor: 0.55)),
                _Box(height: 14, width: 52),
              ],
            ),
            const SizedBox(height: 12),
            const _Box(height: 12, widthFactor: 0.9),
            const SizedBox(height: 8),
            const _Box(height: 12, widthFactor: 0.65),
            const SizedBox(height: 14),
            Row(
              children: const [
                _Box(height: 22, width: 64),
                SizedBox(width: 8),
                _Box(height: 22, width: 64),
                SizedBox(width: 8),
                _Box(height: 22, width: 56),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.height, this.width, this.widthFactor});

  final double height;
  final double? width;
  final double? widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.hairline,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
