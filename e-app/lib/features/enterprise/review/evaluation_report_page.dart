import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/radar_chart.dart';
import '../interview/mock_execution.dart';

/// 模块五：面试执行与级联评估 - 评估报告查看页（P4）。
///
/// 依据《业务功能分析》UC-12 步骤5-7：
/// 五维能力评分卡（技术理论/动手实践/逻辑思维/沟通表达/文化匹配度）
/// + 200-300 字结构化评语（概述/核心优势/待改进项/录用建议）
/// + 完整面试回放链接推送至 HR 终审工作台。
/// 数据来源：本地 Mock 数据（mock_execution.dart 的 mockPendingReviews），
/// TODO: P7阶段替换为真实接口（lib/api/interview_room_api.dart 的 getSessionResult）。
class EvaluationReportPage extends StatelessWidget {
  const EvaluationReportPage({super.key, required this.review});

  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final dims = review['dims'] as Map<String, dynamic>;
    final comment = review['comment'] as Map<String, dynamic>;
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(title: Text('${review['candidateName']} - 评估报告')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // 总分卡片（复用 ScoreRing）
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ScoreRing(score: review['totalScore'] as double, size: 84),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${review['positionName']} · ${review['round']}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '综合能力评分',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '录用建议：${comment['suggestion']}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SectionTitle('五维能力评分卡'),
            // 五维雷达图（复用 P2 的 RadarChart）
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: RadarChart(
                    values: mockEvaluationDims
                        .map((d) => (dims[d] as double))
                        .toList(),
                    labels: mockEvaluationDims,
                    size: 250,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SectionTitle('维度明细'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final dim in mockEvaluationDims)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    dim,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                                Text(
                                  (dims[dim] as double).toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.interactive,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: (dims[dim] as double) / 100,
                                minHeight: 8,
                                backgroundColor: AppColors.hairline,
                                color: AppColors.interactive,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SectionTitle('结构化评语'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${comment['overview']}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '核心优势',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final item
                        in (comment['strengths'] as List).cast<String>())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 5),
                              child: Icon(
                                Icons.circle,
                                size: 5,
                                color: AppColors.green,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      '待改进项',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final item
                        in (comment['improvements'] as List).cast<String>())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 5),
                              child: Icon(
                                Icons.circle,
                                size: 5,
                                color: AppColors.orange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 完整回放链接（UC-12 步骤7：推送至终审工作台）
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('打开完整面试回放：${comment['recordingUrl']}（模拟）'),
                ),
              ),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('查看完整面试回放'),
            ),
          ],
        ),
      ),
    );
  }
}
