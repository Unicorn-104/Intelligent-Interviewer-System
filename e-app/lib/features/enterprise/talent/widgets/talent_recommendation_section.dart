import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../models/talent_detail_view_data.dart';
import 'talent_match_analysis_section.dart';

class TalentRecommendationSection extends StatelessWidget {
  const TalentRecommendationSection({
    super.key,
    required this.state,
    required this.onRetry,
    this.embedded = false,
  });
  final TalentSectionState<Map<String, dynamic>> state;
  final VoidCallback onRetry;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final report = state.data;
    final reason = report?['source'] == 'llm'
        ? talentText(report?['recommendation'], '')
        : '';
    final warnings = report?['sourceWarnings'];
    return TalentSectionFrame(
      title: '推荐理由',
      ai: !embedded,
      embedded: embedded,
      loading: state.loading,
      error: state.error,
      empty: reason.isEmpty,
      emptyText: '暂无推荐理由',
      onRetry: onRetry,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TalentExpandableText(text: reason, maxLines: 4),
          if (warnings is List && warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            TalentExpandableText(
              text: warnings.map((value) => '$value').join('；'),
              maxLines: 2,
            ),
          ],
          if (report?['generatedAt'] != null) ...[
            const SizedBox(height: 8),
            Text(
              talentText(report?['generatedAt']),
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
