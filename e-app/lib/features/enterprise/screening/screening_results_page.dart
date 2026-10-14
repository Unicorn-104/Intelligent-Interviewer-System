import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/radar_chart.dart';
import '../../../widgets/skeleton_list.dart';
import 'candidate_score_detail_page.dart';
import 'greeting_page.dart';
import 'mock_screening.dart';

/// 模块二：AI 初筛与短名单 - 匹配度评分与短名单页（P2）。
///
/// 依据《业务功能分析》UC-05 步骤3-5：
/// 各维度加权汇总生成百分制综合评分，按降序排序截取 Top N 短名单；
/// Top 3 触发 LLM 深度分析并生成个性化招呼语（步骤6-8）。
/// 数据来源：本地 Mock 数据（mock_screening.dart），
/// TODO: P7阶段替换为真实接口（lib/api/screening_api.dart 的
/// getScreeningResults / getShortlist / getGreetingMessage）。
class ScreeningResultsPage extends StatefulWidget {
  const ScreeningResultsPage({super.key, required this.task});

  final Map<String, dynamic> task;

  @override
  State<ScreeningResultsPage> createState() => _ScreeningResultsPageState();
}

class _ScreeningResultsPageState extends State<ScreeningResultsPage> {
  List<Map<String, dynamic>>? _results;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 模拟加载匹配度评分与短名单（降序）。
  /// TODO: P7阶段替换为真实接口（screening_api.getScreeningResults）。
  Future<void> _load() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final sorted = List<Map<String, dynamic>>.from(mockScreeningResults)
      ..sort(
        (a, b) =>
            (b['totalScore'] as double).compareTo(a['totalScore'] as double),
      );
    setState(() {
      _results = sorted;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(title: Text('${widget.task['positionName']} - 短名单')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '匹配度评分排行（Top ${widget.task['topN']}）',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GreetingPage()),
            ),
            icon: const Icon(Icons.waving_hand_outlined, size: 18),
            label: const Text('Top 3 招呼语'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const SkeletonList(rows: 5);
    final results = _results ?? const <Map<String, dynamic>>[];
    if (results.isEmpty) {
      return const PageMessage(
        icon: Icons.scoreboard_outlined,
        title: '暂无评分数据',
        message: '筛选任务完成后将展示候选人的匹配度评分与短名单',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: results.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) => _ScoreCard(
          result: results[index],
          onOpen: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CandidateScoreDetailPage(candidate: results[index]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.result, required this.onOpen});

  final Map<String, dynamic> result;
  final VoidCallback onOpen;

  static const _dimLabels = ['技能', '项目', '教育', '行业'];

  @override
  Widget build(BuildContext context) {
    final dims = (result['dims'] as Map<String, dynamic>);
    final total = result['totalScore'] as double;
    final top3 = result['top3'] == true;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: result['rank'] <= 3
                          ? AppColors.warningSoft
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '#${result['rank']}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: result['rank'] <= 3
                            ? AppColors.orange
                            : AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${result['name']}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (top3) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'AI 深度分析',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.interactive,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${result['education']} · ${result['years']}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  ScoreRing(score: total),
                ],
              ),
              const SizedBox(height: 12),
              // 四维得分迷你条
              Row(
                children: [
                  for (final label in _dimLabels) ...[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 3),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: (dims[_dimKeys(label)] as double) / 100,
                              minHeight: 4,
                              backgroundColor: AppColors.hairline,
                              color: AppColors.interactive,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: onOpen, child: const Text('评分明细与报告')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _dimKeys(String short) => switch (short) {
    '技能' => '技能匹配度',
    '项目' => '项目相关性',
    '教育' => '教育背景',
    _ => '行业经验',
  };
}
