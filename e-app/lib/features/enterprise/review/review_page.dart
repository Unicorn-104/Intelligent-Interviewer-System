import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/filter_chips.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/radar_chart.dart';
import '../../../widgets/skeleton_list.dart';
import '../interview/mock_execution.dart';
import 'evaluation_report_page.dart';

/// 模块五：面试执行与级联评估 - HR 终审页（P4，替换 P0 占位页）。
///
/// 依据《业务功能分析》UC-12 步骤8-10 与 UC-15：
/// - 确认通过：终面 → 自动触发 Offer 发送；非终面 → 级联自动创建下一轮预约任务
/// - 调整后通过：HR 修改五维评分后确认
/// - 驳回（淘汰）：候选人状态更新为"已淘汰-面试未通过"，
///   简历自动归档至人才库并发送"感谢参与"邮件（记录淘汰原因）
/// 数据来源：本地 Mock 数据（mock_execution.dart 的 mockPendingReviews），
/// TODO: P7阶段替换为真实接口（lib/api/review_api.dart 的
/// listPendingReviews / confirmReview / adjustReview / rejectReview）。
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  List<Map<String, dynamic>>? _reviews;
  bool _loading = true;
  int _filterIndex = 0; // 0=待终审 1=已通过 2=已驳回

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 模拟加载待终审列表。
  /// TODO: P7阶段替换为真实接口（review_api.listPendingReviews）。
  Future<void> _load() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final statusFilter = switch (_filterIndex) {
      1 => 'confirmed',
      2 => 'rejected',
      _ => 'pending',
    };
    setState(() {
      _reviews = mockPendingReviews
          .where((r) => r['status'] == statusFilter)
          .toList();
      _loading = false;
    });
  }

  /// 确认通过（UC-12 步骤8-9：终面→Offer；非终面→级联下一轮 UC-15）。
  /// TODO: P7阶段替换为真实接口（review_api.confirmReview）。
  Future<void> _confirm(Map<String, dynamic> review) async {
    final messenger = ScaffoldMessenger.of(context);
    final isFinal = review['isFinal'] == true;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          isFinal ? Icons.description_outlined : Icons.account_tree_outlined,
          color: AppColors.green,
        ),
        title: Text(isFinal ? '已触发 Offer 发送流程' : '已自动创建下一轮预约任务'),
        content: Text(
          isFinal
              ? '「${review['candidateName']}」终面审核通过，系统已自动生成录用意向书'
                    '（岗位、薪资区间、入职时间）并通过邮件/短信发送，请前往 Offer 管理查看。'
              : '「${review['candidateName']}」为${review['round']}（非终面），'
                    '系统已自动触发级联流转（UC-15）：创建下一轮面试预约任务，'
                    '将本轮面试纪要（重点关注项）传递至模块三智能预约调度，'
                    '并已向候选人发送下一轮面试邀请。',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => review['status'] = 'confirmed');
    messenger.showSnackBar(
      SnackBar(content: Text('已确认通过「${review['candidateName']}」（模拟）')),
    );
  }

  /// 调整后通过（UC-12 步骤8：HR 手动修改评分后确认）。
  /// TODO: P7阶段替换为真实接口（review_api.adjustReview）。
  Future<void> _adjust(Map<String, dynamic> review) async {
    final messenger = ScaffoldMessenger.of(context);
    final dims = Map<String, double>.from(
      (review['dims'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as double)),
      ),
    );
    final adjusted = await showDialog<Map<String, double>>(
      context: context,
      builder: (context) => _AdjustScoreDialog(
        candidateName: '${review['candidateName']}',
        dims: dims,
      ),
    );
    if (adjusted == null || !mounted) return;
    setState(() {
      review['dims'] = adjusted;
      review['totalScore'] = double.parse(
        (adjusted.values.reduce((a, b) => a + b) / adjusted.length)
            .toStringAsFixed(1),
      );
      review['status'] = 'confirmed';
    });
    messenger.showSnackBar(const SnackBar(content: Text('评分已调整并确认通过（模拟）')));
  }

  /// 驳回淘汰（UC-12 步骤10：归档人才库 + 感谢信）。
  /// TODO: P7阶段替换为真实接口（review_api.rejectReview）。
  Future<void> _reject(Map<String, dynamic> review) async {
    final messenger = ScaffoldMessenger.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('驳回「${review['candidateName']}」'),
        content: const TextField(
          maxLines: 2,
          decoration: InputDecoration(
            labelText: '淘汰原因（供后续分析）',
            hintText: '如：技术深度未达岗位要求',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, 'reject'),
            child: const Text('确认驳回'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    setState(() => review['status'] = 'rejected');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.archive_outlined, color: AppColors.muted),
        title: const Text('已完成淘汰归档'),
        content: const Text(
          '候选人状态已更新为"已淘汰-面试未通过"；\n'
          '简历已自动归档至人才库（保留历史记录）；\n'
          '有温度的"感谢参与"邮件已发送。',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    messenger.showSnackBar(
      SnackBar(content: Text('已驳回「${review['candidateName']}」（模拟）')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(title: const Text('HR 终审')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: FilterChips(
                labels: const ['待终审', '已通过', '已驳回'],
                selectedIndex: _filterIndex,
                onChanged: (index) {
                  setState(() => _filterIndex = index);
                  _load();
                },
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const SkeletonList(rows: 4);
    final reviews = _reviews ?? const <Map<String, dynamic>>[];
    if (reviews.isEmpty) {
      return const PageMessage(
        icon: Icons.task_alt,
        title: '暂无待终审记录',
        message: '面试结束后，评分卡、评语与回放链接将推送至此处供 HR 终审',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: reviews.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) => _ReviewCard(
          review: reviews[index],
          onOpenReport: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EvaluationReportPage(review: reviews[index]),
            ),
          ),
          onConfirm: () => _confirm(reviews[index]),
          onAdjust: () => _adjust(reviews[index]),
          onReject: () => _reject(reviews[index]),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.onOpenReport,
    required this.onConfirm,
    required this.onAdjust,
    required this.onReject,
  });

  final Map<String, dynamic> review;
  final VoidCallback onOpenReport;
  final VoidCallback onConfirm;
  final VoidCallback onAdjust;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final status = review['status'] as String;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${review['candidateName']}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${review['round']}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${review['positionName']}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                ScoreRing(score: review['totalScore'] as double, size: 56),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '录用建议：${(review['comment'] as Map)['suggestion']}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            if (status == 'pending')
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 6,
                children: [
                  TextButton(
                    onPressed: onOpenReport,
                    child: const Text('查看报告'),
                  ),
                  TextButton(
                    onPressed: onReject,
                    style: TextButton.styleFrom(foregroundColor: AppColors.red),
                    child: const Text('驳回淘汰'),
                  ),
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
              )
            else
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 6,
                children: [
                  TextButton(
                    onPressed: onOpenReport,
                    child: const Text('查看报告'),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: status == 'confirmed'
                          ? AppColors.primarySoft
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status == 'confirmed' ? '已通过 · 已触发流转' : '已驳回 · 已归档人才库',
                      style: TextStyle(
                        fontSize: 12,
                        color: status == 'confirmed'
                            ? AppColors.green
                            : AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 调整五维评分对话框（UC-12 步骤8：调整后通过）。
class _AdjustScoreDialog extends StatefulWidget {
  const _AdjustScoreDialog({required this.candidateName, required this.dims});

  final String candidateName;
  final Map<String, double> dims;

  @override
  State<_AdjustScoreDialog> createState() => _AdjustScoreDialogState();
}

class _AdjustScoreDialogState extends State<_AdjustScoreDialog> {
  late final Map<String, double> _values = Map.of(widget.dims);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('调整「${widget.candidateName}」的评分'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in _values.entries)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        entry.value.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.interactive,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: entry.value,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    onChanged: (v) => setState(() => _values[entry.key] = v),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _values),
          child: const Text('确认调整'),
        ),
      ],
    );
  }
}
