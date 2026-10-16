import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

enum JobSortDimension {
  latestApply('最新投递', 'latestApplyTime'),
  published('岗位发布时间', 'publishTime'),
  applicants('投递人数', 'applicantCount');

  const JobSortDimension(this.label, this.field);
  final String label;
  final String field;

  String directionLabel(bool ascending) => this == applicants
      ? (ascending ? '少到多' : '多到少')
      : (ascending ? '旧到新' : '新到旧');
}

typedef JobSortSelection = ({JobSortDimension dimension, bool ascending});

class JobSortSheet extends StatelessWidget {
  const JobSortSheet({
    super.key,
    required this.dimension,
    required this.ascending,
  });

  final JobSortDimension dimension;
  final bool ascending;

  void _select(BuildContext context, JobSortDimension option, bool asc) =>
      Navigator.of(context)
          .pop<JobSortSelection>((dimension: option, ascending: asc));

  Widget _direction(BuildContext context, JobSortDimension option, bool asc) {
    final selected = option == dimension && asc == ascending;
    return Semantics(
      selected: selected,
      child: Tooltip(
        message: '${option.label} · ${option.directionLabel(asc)}',
        child: OutlinedButton(
          key: ValueKey('jobs-sort-${option.name}-${asc ? 'asc' : 'desc'}'),
          onPressed: () => _select(context, option, asc),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(44, 46),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            foregroundColor: selected
                ? AppColors.interactive
                : AppColors.textMuted,
            backgroundColor: selected
                ? AppColors.interactiveSoft
                : AppColors.canvas,
            side: BorderSide(
              color: selected ? AppColors.interactive : AppColors.hairline,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(asc ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
              const SizedBox(height: 2),
              Text(
                option.directionLabel(asc),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '岗位排序',
                    style: TextStyle(
                      color: AppColors.brand,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('jobs-sort-close'),
                  tooltip: '关闭排序',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final option in JobSortDimension.values) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: option == dimension
                      ? AppColors.interactiveSoft
                      : AppColors.canvas,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        key: ValueKey('jobs-sort-dimension-${option.name}'),
                        onTap: () => _select(context, option, false),
                        borderRadius: BorderRadius.circular(4),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 46),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              option.label,
                              style: TextStyle(
                                color: option == dimension
                                    ? AppColors.interactive
                                    : AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: option == dimension
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _direction(context, option, true),
                    const SizedBox(width: 8),
                    _direction(context, option, false),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              '仅排序已加载的岗位；缺失值始终排在最后',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}
