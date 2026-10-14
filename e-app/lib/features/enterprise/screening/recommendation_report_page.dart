import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/skeleton_list.dart';

/// 模块二：AI 初筛与短名单 - AI 推荐报告页（P2）。
///
/// 依据《业务功能分析》UC-05 步骤6-7：
/// Top 3 触发 LLM 深度分析（核心优势/潜在风险/待面试验证点），
/// 汇总规则评分与 LLM 评价，生成可解释性推荐卡片
/// （匹配依据原文引用 + 面试建议）。
/// 数据来源：本地 Mock 数据（mock_screening.dart 的 report 字段），
/// TODO: P7阶段替换为真实接口（lib/api/screening_api.dart 的 getRecommendationReport）。
class RecommendationReportPage extends StatefulWidget {
  const RecommendationReportPage({super.key, required this.candidate});

  final Map<String, dynamic> candidate;

  @override
  State<RecommendationReportPage> createState() =>
      _RecommendationReportPageState();
}

class _RecommendationReportPageState extends State<RecommendationReportPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 模拟加载 AI 推荐报告。
  /// TODO: P7阶段替换为真实接口（screening_api.getRecommendationReport）。
  Future<void> _load() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final candidate = widget.candidate;
    final report = (candidate['report'] as Map<String, dynamic>?) ?? const {};
    final top3 = candidate['top3'] == true;
    final quotes =
        (report['quotes'] as List?)?.cast<String>() ?? const <String>[];
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(title: Text('${candidate['name']} - AI 推荐报告')),
        body: _loading
            ? const SkeletonList(rows: 3)
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (top3)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: AppColors.interactive,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '已由 LLM 模拟资深面试官视角深度分析',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.interactive),
                          ),
                        ],
                      ),
                    ),
                  _ReportSection(
                    title: '匹配点（核心优势）',
                    icon: Icons.thumb_up_alt_outlined,
                    color: AppColors.green,
                    items:
                        (report['strengths'] as List?)?.cast<String>() ??
                        const <String>[],
                  ),
                  _ReportSection(
                    title: '风险点',
                    icon: Icons.warning_amber_outlined,
                    color: AppColors.orange,
                    items:
                        (report['risks'] as List?)?.cast<String>() ??
                        const <String>[],
                  ),
                  _ReportSection(
                    title: '待核实点（面试验证）',
                    icon: Icons.help_outline,
                    color: AppColors.purple,
                    items:
                        (report['toVerify'] as List?)?.cast<String>() ??
                        const <String>[],
                  ),
                  if (quotes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '匹配依据（原文引用）',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: AppColors.brand,
                                      fontSize: 14,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              ...quotes.map(
                                (q) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '“$q”',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '面试建议',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: AppColors.brand,
                                    fontSize: 14,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${report['interviewAdvice'] ?? ''}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Text(
                    '$title（${items.length}）',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.brand,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
