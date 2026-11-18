import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../models/talent_detail_view_data.dart';
import 'talent_match_analysis_section.dart';

/// HR 人工评分独立展示：仅人工分/备注/时间，不渲染六维雷达图，与 AI 分析完全分离。
class TalentManualScoreSection extends StatelessWidget {
  const TalentManualScoreSection({
    super.key,
    required this.result,
    this.embedded = false,
  });

  /// 岗位筛选结果整行，人工数据位于其 manualAnalysis 字段
  final Map<String, dynamic>? result;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final Object? manual = result?['manualAnalysis'];
    final hasManual = manual is Map && manual['source'] == 'manual';
    if (!hasManual) return const SizedBox.shrink();

    final num? score = talentNumber(
      manual['adjustedTotalScore'] ?? manual['totalScore'],
    );
    final String note = talentText(manual['recommendation'], '');

    return TalentSectionFrame(
      title: 'HR 人工评分',
      embedded: embedded,
      loading: false,
      empty: false,
      onRetry: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'HR 人工评分',
                  style: TextStyle(fontSize: 11, color: AppColors.brand),
                ),
              ),
              const Spacer(),
              Text(
                score == null ? '—' : score.toStringAsFixed(1),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            TalentExpandableText(text: note, maxLines: 3),
          ],
          if (manual['generatedAt'] != null) ...[
            const SizedBox(height: 6),
            Text(
              '评分时间：${talentText(manual['generatedAt'])}',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
