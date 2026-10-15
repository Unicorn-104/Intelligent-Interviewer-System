import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import 'mock_notification.dart';

/// 模块六：反馈与通知 - 满意度调研结果页（P5）。
///
/// 依据《业务功能分析》UC-17（候选人体验调研与数据分析）：
/// 面试后自动发送满意度问卷，采集候选人对流程便捷度、
/// 面试官专业度、系统易用性等方面的评分与文字反馈。
/// 数据来源：本地 Mock 数据（mock_notification.dart），
/// TODO: P7阶段替换为真实接口（lib/api/survey_api.dart 的 getSurveyResults）。
class SurveyResultPage extends StatefulWidget {
  const SurveyResultPage({super.key});

  @override
  State<SurveyResultPage> createState() => _SurveyResultPageState();
}

class _SurveyResultPageState extends State<SurveyResultPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 模拟加载调研结果汇总。
  /// TODO: P7阶段替换为真实接口（survey_api.getSurveyResults）。
  Future<void> _load() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(title: const Text('满意度调研')),
        body: _loading
            ? const SkeletonList(rows: 4)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 16),
                    const SectionTitle('各维度评分'),
                    _buildDimRings(),
                    const SizedBox(height: 16),
                    const SectionTitle('评分分布'),
                    _buildDistributionChart(),
                    const SizedBox(height: 16),
                    const SectionTitle('文字反馈'),
                    ..._buildFeedbacks(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final summary = mockSurveySummary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${summary['avgScore']}',
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    color: AppColors.green,
                  ),
                ),
                Text(
                  '平均满意度 / 5.0 分',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '回收问卷 ${summary['responseCount']} 份',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '面试结束后 24 小时自动发送满意度问卷（UC-17），采集候选人体验评分与文字反馈',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 各维度环形评分（UC-17 三个维度，满分 5 分制归一为百分环）。
  Widget _buildDimRings() {
    final dims = (mockSurveySummary['dims'] as List)
        .cast<Map<String, dynamic>>();
    return Row(
      children: [
        for (final dim in dims) ...[
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  children: [
                    _DimRing(score: dim['score'] as double),
                    const SizedBox(height: 8),
                    Text(
                      '${dim['name']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dim['score']} / 5.0',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.interactive,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (dim != dims.last) const SizedBox(width: 10),
        ],
      ],
    );
  }

  /// 评分分布柱状图（CustomPaint 手绘，1-5 星分布）。
  Widget _buildDistributionChart() {
    final distribution = (mockSurveySummary['distribution'] as List)
        .cast<int>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 140,
              width: double.infinity,
              child: CustomPaint(
                painter: _DistributionPainter(
                  counts: distribution,
                  barColor: AppColors.interactive,
                  axisColor: AppColors.hairline,
                  labelColor: AppColors.muted,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '共 ${distribution.reduce((a, b) => a + b)} 条评分（1-5 星分布）',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFeedbacks() {
    return [
      for (final feedback in mockSurveyFeedbacks)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${feedback['candidateName']} · ${feedback['positionName']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      ...List.generate(
                        5,
                        (i) => Icon(
                          i < (feedback['rating'] as int)
                              ? Icons.star
                              : Icons.star_border,
                          size: 14,
                          color: AppColors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${feedback['content']}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${feedback['date']}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
  }
}

/// 维度环形评分（满分 5 分制，本地小组件，与 P2 的 ScoreRing 场景不同）。
class _DimRing extends StatelessWidget {
  const _DimRing({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: CircularProgressIndicator(
              value: score / 5,
              strokeWidth: 6,
              backgroundColor: AppColors.hairline,
              color: AppColors.green,
            ),
          ),
          Text(
            score.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }
}

/// 评分分布柱状图绘制器（手写 CustomPaint，避免引入第三方图表库）。
class _DistributionPainter extends CustomPainter {
  const _DistributionPainter({
    required this.counts,
    required this.barColor,
    required this.axisColor,
    required this.labelColor,
  });

  final List<int> counts;
  final Color barColor;
  final Color axisColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 26.0;
    const bottomPad = 22.0;
    final chartWidth = size.width - leftPad;
    final chartHeight = size.height - bottomPad;
    final maxCount = counts.reduce((a, b) => a > b ? a : b).toDouble();

    // 基线
    final baseline = Offset(leftPad, chartHeight);
    canvas.drawLine(
      baseline,
      Offset(size.width, chartHeight),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1,
    );

    final slot = chartWidth / counts.length;
    final barWidth = slot * 0.5;
    for (var i = 0; i < counts.length; i++) {
      final barHeight = counts[i] / maxCount * (chartHeight - 8);
      final rect = Rect.fromLTWH(
        leftPad + slot * i + (slot - barWidth) / 2,
        chartHeight - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        Paint()
          ..color = barColor.withValues(
            alpha: counts[i] == maxCount ? 1.0 : 0.45,
          ),
      );
      // 柱顶数值
      final tp = TextPainter(
        text: TextSpan(
          text: '${counts[i]}',
          style: TextStyle(fontSize: 10, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          leftPad + slot * i + (slot - tp.width) / 2,
          chartHeight - barHeight - tp.height - 3,
        ),
      );
      // 底部星级标签
      final starTp = TextPainter(
        text: TextSpan(
          text: '${i + 1}★',
          style: TextStyle(fontSize: 10, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      starTp.paint(
        canvas,
        Offset(leftPad + slot * i + (slot - starTp.width) / 2, chartHeight + 5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DistributionPainter oldDelegate) =>
      oldDelegate.counts != counts;
}
