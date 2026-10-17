import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 横向筛选标签组（P2 新增通用组件，供筛选/短名单等页面复用）。
///
/// [labels] 第一个元素固定为"全部"，selectedIndex=0 表示未筛选。
class FilterChips extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return Material(
            color: selected ? AppColors.primarySoft : AppColors.canvas,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: selected ? AppColors.interactive : AppColors.hairline),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onChanged(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                child: Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: 13,
                    color: selected ? AppColors.interactive : AppColors.bodySoft,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
