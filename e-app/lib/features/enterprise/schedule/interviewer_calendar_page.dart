import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import 'mock_schedule.dart';

/// 模块三：智能预约调度 - 面试官日历忙闲页（P3）。
///
/// 依据《业务功能分析》UC-08（面试官日历同步与冲突检测）：
/// 系统通过 API 对接企业日历实时拉取面试官忙闲状态，
/// 结合时间窗口匹配算法自动计算最优面试时间建议。
/// 数据来源：本地 Mock 数据（mock_schedule.dart 的 mockInterviewers），
/// TODO: P7阶段替换为真实接口（lib/api/schedule_api.dart 的
/// getInterviewerAvailability）。
class InterviewerCalendarPage extends StatefulWidget {
  const InterviewerCalendarPage({super.key});

  @override
  State<InterviewerCalendarPage> createState() =>
      _InterviewerCalendarPageState();
}

class _InterviewerCalendarPageState extends State<InterviewerCalendarPage> {
  Map<String, dynamic>? _interviewer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  /// 模拟加载面试官日历忙闲（切换面试官时重新加载）。
  /// TODO: P7阶段替换为真实接口（schedule_api.getInterviewerAvailability）。
  Future<void> _load(int index) async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _interviewer = mockInterviewers[index];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(title: const Text('面试官日历')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  for (var i = 0; i < mockInterviewers.length; i++) ...[
                    _InterviewerChip(
                      name: '${mockInterviewers[i]['name']}',
                      title: '${mockInterviewers[i]['title']}',
                      selected:
                          _interviewer != null &&
                          _interviewer!['interviewerId'] ==
                              mockInterviewers[i]['interviewerId'],
                      onTap: () => _load(i),
                    ),
                    if (i != mockInterviewers.length - 1)
                      const SizedBox(width: 10),
                  ],
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
    final interviewer = _interviewer;
    if (interviewer == null) {
      return const PageMessage(
        icon: Icons.calendar_today_outlined,
        title: '暂无日历数据',
        message: '请选择面试官查看忙闲状态',
      );
    }
    final busy = (interviewer['busy'] as List).cast<String>();
    final occupied = (interviewer['occupied'] as List).cast<String>();
    // 9:00-18:00 每半小时一个时间片
    final slots = <String>[];
    for (var h = 9; h < 18; h++) {
      slots.add('${h.toString().padLeft(2, '0')}:00');
      slots.add('${h.toString().padLeft(2, '0')}:30');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${interviewer['name']} · ${interviewer['title']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '2026-10-09 今天',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _Legend(),
                const SizedBox(height: 12),
                ...slots.map(
                  (slot) => _SlotRow(
                    time: slot,
                    kind: _slotKind(slot, busy, occupied),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '说明：系统将依据忙闲状态，去除已占用时段，按面试时长切割时间片生成 3-5 个最优建议时段（UC-08，模拟）',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _slotKind(String slot, List<String> busy, List<String> occupied) {
    if (occupied.any((range) => _inRange(slot, range))) return 'occupied';
    if (busy.any((range) => _inRange(slot, range))) return 'busy';
    return 'free';
  }

  bool _inRange(String slot, String range) {
    final parts = range.split('-');
    return slot.compareTo(parts[0]) >= 0 && slot.compareTo(parts[1]) < 0;
  }
}

class _InterviewerChip extends StatelessWidget {
  const _InterviewerChip({
    required this.name,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? AppColors.interactive : AppColors.hairline,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.interactive : AppColors.body,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? AppColors.interactive : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label) => Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    return Row(
      children: [
        item(AppColors.primarySoft, '空闲'),
        const SizedBox(width: 14),
        item(AppColors.warningSoft, '会议/忙'),
        const SizedBox(width: 14),
        item(AppColors.orange, '已约面试'),
      ],
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.time, required this.kind});

  final String time;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final (bg, label) = switch (kind) {
      'occupied' => (AppColors.orange.withValues(alpha: 0.15), '已约面试'),
      'busy' => (AppColors.warningSoft, '会议/忙'),
      _ => (AppColors.primarySoft, '空闲'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(time, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: kind == 'occupied'
                      ? AppColors.orange
                      : AppColors.bodySoft,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
