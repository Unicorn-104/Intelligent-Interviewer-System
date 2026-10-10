import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/radar_chart.dart';
import '../../../widgets/skeleton_list.dart';
import 'mock_screening.dart';
import 'recommendation_report_page.dart';

/// 模块二：AI 初筛与短名单 - 候选人评分明细页（P2）。
///
/// 依据《业务功能分析》UC-05 步骤3-4：
/// 多维度语义匹配（技能标签重合度 30% / 项目经验相关性 30% /
/// 教育背景匹配度 20% / 行业/领域经验匹配 20%）加权汇总为百分制综合评分。
/// 数据来源：本地 Mock 数据（mock_screening.dart），
/// TODO: P7阶段替换为真实接口（lib/api/screening_api.dart 的 getScreeningResults）。
class CandidateScoreDetailPage extends StatefulWidget {
  const CandidateScoreDetailPage({super.key, required this.candidate});

  final Map<String, dynamic> candidate;

  @override
  State<CandidateScoreDetailPage> createState() =>
      _CandidateScoreDetailPageState();
}

class _CandidateScoreDetailPageState extends State<CandidateScoreDetailPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 模拟加载评分明细。
  /// TODO: P7阶段替换为真实接口（screening_api.getScreeningResults 的维度明细）。
  Future<void> _load() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final candidate = widget.candidate;
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(title: Text('${candidate['name']} - 评分明细')),
        body: _loading
            ? const SkeletonList(rows: 3)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    // 总分卡片
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            ScoreRing(
                              score: candidate['totalScore'] as double,
                              size: 88,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '综合匹配度 #${candidate['rank']}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${candidate['education']} · ${candidate['years']}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '短名单 Top ${candidate['rank'] <= 3 ? '3（已触发 LLM 深度分析）' : 'N'}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
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
                    const SectionTitle('四维能力雷达'),
                    // 雷达图卡片
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: _buildRadar(candidate)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SectionTitle('维度明细与权重'),
                    // 加权维度条
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: _buildDimBars(candidate)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // AI 推荐报告入口
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              RecommendationReportPage(candidate: candidate),
                        ),
                      ),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('查看 AI 推荐报告'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildRadar(Map<String, dynamic> candidate) {
    final dims = candidate['dims'] as Map<String, dynamic>;
    const labels = ['技能匹配', '项目相关', '教育背景', '行业经验'];
    final values = labels.map((short) {
      final key = switch (short) {
        '技能匹配' => '技能匹配度',
        '项目相关' => '项目相关性',
        '教育背景' => '教育背景',
        _ => '行业经验',
      };
      return (dims[key] as double);
    }).toList();
    return RadarChart(values: values, labels: labels);
  }

  List<Widget> _buildDimBars(Map<String, dynamic> candidate) {
    final dims = candidate['dims'] as Map<String, dynamic>;
    return screeningWeights.entries.map((entry) {
      final weight = (entry.value * 100).toStringAsFixed(0);
      final score = dims[entry.key] as double;
      final color = score >= 85
          ? AppColors.green
          : score >= 70
          ? AppColors.interactive
          : AppColors.orange;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${entry.key}（权重 $weight%）',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  score.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 8,
                backgroundColor: AppColors.hairline,
                color: color,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
