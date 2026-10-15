import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/radar_chart.dart';
import '../../../widgets/skeleton_list.dart';
import 'mock_screening.dart';

/// 模块二：AI 初筛与短名单 - HR 复核页（P2）。
///
/// 依据《业务功能分析》UC-06（短名单 HR 复核）：
/// HR 对 AI 生成的短名单逐人复核，可确认通过、调整评分或移出短名单；
/// 复核确认后短名单流入模块三（智能预约调度）。
/// 数据来源：本地 Mock 数据（mock_screening.dart，仅本地状态变更），
/// TODO: P7阶段替换为真实接口（lib/api/screening_api.dart 的 reviewScreeningResult）。
class ShortlistReviewPage extends StatefulWidget {
  const ShortlistReviewPage({super.key});

  @override
  State<ShortlistReviewPage> createState() => _ShortlistReviewPageState();
}

class _ShortlistReviewPageState extends State<ShortlistReviewPage> {
  List<Map<String, dynamic>>? _list;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 模拟加载待复核短名单。
  /// TODO: P7阶段替换为真实接口（screening_api.getShortlist）。
  Future<void> _load() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _list = List<Map<String, dynamic>>.from(mockScreeningResults);
      _loading = false;
    });
  }

  int get _confirmedCount =>
      (_list ?? const []).where((c) => c['reviewStatus'] == 'confirmed').length;

  /// 模拟复核确认。
  /// TODO: P7阶段替换为真实接口（screening_api.reviewScreeningResult）。
  Future<void> _confirm(Map<String, dynamic> candidate) async {
    setState(() => candidate['reviewStatus'] = 'confirmed');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已确认「${candidate['name']}」通过初筛（模拟），将流入面试邀约')),
    );
  }

  /// 模拟调整评分。
  /// TODO: P7阶段替换为真实接口（screening_api.reviewScreeningResult，approved=true + adjustNote）。
  Future<void> _adjustScore(Map<String, dynamic> candidate) async {
    final adjusted = await showDialog<double>(
      context: context,
      builder: (context) =>
          _AdjustScoreDialog(initial: candidate['totalScore'] as double),
    );
    if (adjusted == null || !mounted) return;
    setState(() {
      candidate['totalScore'] = double.parse(adjusted.toStringAsFixed(1));
      candidate['reviewStatus'] = 'confirmed';
    });
  }

  /// 模拟移出短名单。
  /// TODO: P7阶段替换为真实接口（screening_api.reviewScreeningResult，approved=false）。
  Future<void> _remove(Map<String, dynamic> candidate) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移出短名单'),
        content: Text('确定将「${candidate['name']}」移出短名单吗？（模拟操作，仅更新本地数据）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移出'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(
      () => _list?.removeWhere(
        (c) => c['candidateId'] == candidate['candidateId'],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(title: const Text('短名单复核')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_loading)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    Icon(
                      _confirmedCount == (_list?.length ?? 0) &&
                              (_list?.isNotEmpty ?? false)
                          ? Icons.verified_outlined
                          : Icons.fact_check_outlined,
                      size: 18,
                      color: AppColors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '已确认 $_confirmedCount/${_list?.length ?? 0}，确认后流入面试邀约（模块三）',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.green),
                    ),
                  ],
                ),
              ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const SkeletonList(rows: 5);
    final list = _list ?? const <Map<String, dynamic>>[];
    if (list.isEmpty) {
      return const PageMessage(
        icon: Icons.done_all,
        title: '短名单已清空',
        message: '所有候选人均已完成复核',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) => _ReviewCard(
          candidate: list[index],
          onConfirm: () => _confirm(list[index]),
          onAdjust: () => _adjustScore(list[index]),
          onRemove: () => _remove(list[index]),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.candidate,
    required this.onConfirm,
    required this.onAdjust,
    required this.onRemove,
  });

  final Map<String, dynamic> candidate;
  final VoidCallback onConfirm;
  final VoidCallback onAdjust;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final confirmed = candidate['reviewStatus'] == 'confirmed';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '${candidate['name']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 6),
                      if (confirmed)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '已确认',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.green,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                ScoreRing(score: candidate['totalScore'] as double, size: 52),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '#${candidate['rank']} · ${candidate['education']} · ${candidate['years']}'
              '${candidate['top3'] == true ? ' · AI 深度分析' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            if (confirmed)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '已复核，等待流入面试邀约',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: onRemove, child: const Text('移出')),
                  const SizedBox(width: 4),
                  OutlinedButton(
                    onPressed: onAdjust,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text('调整评分'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onConfirm,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text('确认通过'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 调整评分对话框（模拟，Slider 拖动后确认）。
class _AdjustScoreDialog extends StatefulWidget {
  const _AdjustScoreDialog({required this.initial});

  final double initial;

  @override
  State<_AdjustScoreDialog> createState() => _AdjustScoreDialogState();
}

class _AdjustScoreDialogState extends State<_AdjustScoreDialog> {
  late double _score = widget.initial;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('调整匹配度评分'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('当前：${_score.toStringAsFixed(1)} 分（模拟调整，仅更新本地数据）'),
          Slider(
            value: _score,
            min: 0,
            max: 100,
            divisions: 200,
            label: _score.toStringAsFixed(1),
            onChanged: (value) => setState(() => _score = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _score),
          child: const Text('确认调整'),
        ),
      ],
    );
  }
}
