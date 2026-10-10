import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/filter_chips.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import 'mock_schedule.dart';

/// 模块三：智能预约调度 - 自助改期记录与审批页（P3）。
///
/// 依据《业务功能分析》UC-09（候选人自助改期）：
/// 候选人调整时间时，原时段自动释放并回退至可用池，
/// 系统重新推荐可选时段，形成闭环；HR 对改期申请进行审批。
/// 数据来源：本地 Mock 数据（mock_schedule.dart 的 mockReschedules），
/// TODO: P7阶段替换为真实接口（lib/api/schedule_api.dart 的 rescheduleInterview）。
class RescheduleReviewPage extends StatefulWidget {
  const RescheduleReviewPage({super.key});

  @override
  State<RescheduleReviewPage> createState() => _RescheduleReviewPageState();
}

class _RescheduleReviewPageState extends State<RescheduleReviewPage> {
  List<Map<String, dynamic>>? _records;
  bool _loading = true;
  int _filterIndex = 0; // 0=全部 1=待审批 2=已通过 3=已驳回

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 模拟加载改期记录。
  /// TODO: P7阶段替换为真实接口（schedule_api.rescheduleInterview 的查询侧）。
  Future<void> _load() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final statusFilter = switch (_filterIndex) {
      1 => 'pending',
      2 => 'approved',
      3 => 'rejected',
      _ => null,
    };
    setState(() {
      _records = mockReschedules
          .where((r) => statusFilter == null || r['status'] == statusFilter)
          .toList();
      _loading = false;
    });
  }

  /// 模拟审批（通过/驳回）。原时段自动释放回退可用池（UC-09）。
  /// TODO: P7阶段替换为真实接口（schedule_api.rescheduleInterview 的审批侧）。
  Future<void> _audit(Map<String, dynamic> record, String result) async {
    final messenger = ScaffoldMessenger.of(context);
    final label = result == 'approved' ? '通过' : '驳回';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认$label'),
        content: Text(
          '${result == 'approved' ? '通过后原时段将自动释放回退可用池，新时段生效（模拟）' : '驳回后候选人需重新选择时段（模拟）'}\n'
          '「${record['candidateName']}」${record['originalSlot']} → ${record['newSlot']}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('确认$label'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => record['status'] = result);
    messenger.showSnackBar(SnackBar(content: Text('改期申请已$label（模拟）')));
  }

  @override
  Widget build(BuildContext context) {
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(title: const Text('自助改期审批')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: FilterChips(
                labels: const ['全部', '待审批', '已通过', '已驳回'],
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
    final records = _records ?? const <Map<String, dynamic>>[];
    if (records.isEmpty) {
      return const PageMessage(
        icon: Icons.event_repeat_outlined,
        title: '暂无改期申请',
        message: '候选人自助改期后，申请将在此处展示供审批',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: records.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) => _RecordCard(
          record: records[index],
          onAudit: (result) => _audit(records[index], result),
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.onAudit});

  final Map<String, dynamic> record;
  final ValueChanged<String> onAudit;

  @override
  Widget build(BuildContext context) {
    final status = record['status'] as String;
    final (statusLabel, statusColor) = switch (status) {
      'approved' => ('已通过', AppColors.green),
      'rejected' => ('已驳回', AppColors.red),
      _ => ('待审批', AppColors.orange),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${record['candidateName']} · ${record['positionName']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status == 'pending'
                        ? AppColors.warningSoft
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(fontSize: 12, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SlotLine(
              label: '原时段',
              value: '${record['originalSlot']}',
              color: AppColors.muted,
            ),
            const SizedBox(height: 6),
            _SlotLine(
              label: '新时段',
              value: '${record['newSlot']}',
              color: AppColors.interactive,
            ),
            const SizedBox(height: 8),
            Text(
              '原因：${record['reason']}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '申请于 ${record['requestedAt']} · 面试官 ${record['interviewerName']}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => onAudit('rejected'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      side: const BorderSide(color: AppColors.muted),
                      foregroundColor: AppColors.muted,
                    ),
                    child: const Text('驳回'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () => onAudit('approved'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text('通过'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SlotLine extends StatelessWidget {
  const _SlotLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Icon(Icons.schedule, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
