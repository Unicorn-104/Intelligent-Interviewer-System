import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../models/talent_detail_view_data.dart';
import 'talent_match_analysis_section.dart';

class TalentRecommendationSection extends StatelessWidget {
  const TalentRecommendationSection({
    super.key,
    required this.state,
    required this.onRetry,
  });
  final TalentSectionState<Map<String, dynamic>> state;
  final VoidCallback onRetry;

  List<String> _points(Object? raw) {
    if (raw is List) {
      return raw.map(talentReportValue).toList();
    }
    if (raw is Map) {
      return raw.entries
          .map((entry) => '${entry.key}：${talentReportValue(entry.value)}')
          .toList();
    }
    return [talentReportValue(raw)];
  }

  @override
  Widget build(BuildContext context) {
    final report = state.data;
    return TalentSectionFrame(
      title: '已有推荐报告',
      ai: true,
      loading: state.loading,
      error: state.error,
      empty: report == null || report.isEmpty,
      emptyText: '暂无候选人推荐报告',
      onRetry: onRetry,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '候选人已有报告，未提供岗位归属信息',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (report != null && report.containsKey('matchPoints')) ...[
            const SizedBox(height: 8),
            const Text(
              '匹配要点',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_points(report['matchPoints']).isEmpty)
              const Text(
                '暂无匹配要点',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            for (final point in _points(report['matchPoints']))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: AppColors.interactive,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: TalentExpandableText(text: point, maxLines: 2),
                    ),
                  ],
                ),
              ),
          ],
          if (report != null && report.containsKey('content'))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TalentExpandableText(
                text: '报告正文：${talentReportValue(report['content'])}',
                maxLines: 4,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (report != null && report.containsKey('status'))
                Text(
                  '报告状态：${talentReportValue(report['status'])}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              if (report != null && report.containsKey('sentAt'))
                Text(
                  '发送时间：${talentReportValue(report['sentAt'])}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '接口未提供稳定的风险点或待核实点字段',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
