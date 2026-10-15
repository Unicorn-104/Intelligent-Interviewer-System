import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/filter_chips.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import 'mock_screening.dart';
import 'screening_results_page.dart';

/// 模块二：AI 初筛与短名单 - 筛选任务列表/触发页（P2）。
///
/// 依据《业务功能分析》UC-05 步骤1：系统定时/手动触发筛选任务，
/// 从人才库加载待匹配候选人列表及对应岗位画像。
/// 数据来源：本地 Mock 数据（mock_screening.dart），
/// TODO: P7阶段替换为真实接口（lib/api/screening_api.dart 的
/// createScreeningTask / listScreeningTasks）。
class ScreeningTaskListPage extends StatefulWidget {
  const ScreeningTaskListPage({super.key});

  @override
  State<ScreeningTaskListPage> createState() => _ScreeningTaskListPageState();
}

class _ScreeningTaskListPageState extends State<ScreeningTaskListPage> {
  List<Map<String, dynamic>>? _tasks;
  bool _loading = true;
  int _filterIndex = 0; // 0=全部 1=进行中 2=已完成 3=失败

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 模拟加载筛选任务列表。
  /// TODO: P7阶段替换为真实接口（screening_api.listScreeningTasks）。
  Future<void> _load() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      final statusFilter = switch (_filterIndex) {
        1 => 'running',
        2 => 'done',
        3 => 'failed',
        _ => null,
      };
      _tasks = mockScreeningTasks
          .where(
            (task) => statusFilter == null || task['status'] == statusFilter,
          )
          .toList();
      _loading = false;
    });
  }

  /// 模拟触发筛选任务（选择岗位后创建，进入"进行中"状态）。
  /// TODO: P7阶段替换为真实接口（screening_api.createScreeningTask）。
  Future<void> _triggerTask() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                '选择岗位发起筛选',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final job in const [
              '高级 Flutter 开发工程师',
              'Java 后端开发工程师',
              'AI 产品经理',
              '算法工程师（NLP）',
            ])
              ListTile(
                leading: const Icon(
                  Icons.work_outline,
                  color: AppColors.interactive,
                ),
                title: Text(job),
                onTap: () => Navigator.pop(context, job),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      mockScreeningTasks.add({
        'taskId': 900 + mockScreeningTasks.length,
        'positionName': selected,
        'candidateCount': 20 + mockScreeningTasks.length * 7,
        'passedCount': 0,
        'topN': 20,
        'status': 'running',
        'createdAt': '刚刚',
        'completedAt': null,
        'progress': 0.12,
      });
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已触发「$selected」筛选任务（模拟）')));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('筛选任务'),
          actions: [
            TextButton.icon(
              onPressed: _triggerTask,
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: const Text('触发筛选'),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: FilterChips(
                labels: const ['全部', '进行中', '已完成', '失败'],
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
    final tasks = _tasks ?? const <Map<String, dynamic>>[];
    if (tasks.isEmpty) {
      return PageMessage(
        icon: Icons.filter_alt_off_outlined,
        title: '暂无筛选任务',
        message: '点击右上角"触发筛选"发起 AI 初筛（硬性过滤 + 多维度匹配）',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: tasks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) =>
            _TaskCard(task: tasks[index], onOpen: _openTask),
      ),
    );
  }

  void _openTask(Map<String, dynamic> task) {
    if (task['status'] != 'done') return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScreeningResultsPage(task: task)),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onOpen});

  final Map<String, dynamic> task;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    final status = task['status'] as String;
    final done = status == 'done';
    final (statusLabel, statusColor, statusBg) = switch (status) {
      'done' => ('已完成', AppColors.green, AppColors.primarySoft),
      'running' => ('进行中', AppColors.interactive, AppColors.primarySoft),
      _ => ('失败', AppColors.red, AppColors.background),
    };
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: done ? () => onOpen(task) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${task['positionName']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(fontSize: 12, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '候选人池 ${task['candidateCount']} 人'
                '${done ? ' · 硬性过滤后 ${task['passedCount']} 人' : ''}'
                ' · 短名单 Top ${task['topN']}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (status == 'running') ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: task['progress'] as double,
                    minHeight: 6,
                    backgroundColor: AppColors.hairline,
                    color: AppColors.interactive,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI 匹配计算中…（模拟）',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (status == 'failed') ...[
                const SizedBox(height: 8),
                Text(
                  '原因：AI 服务调用超时（模拟）',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.red),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 0,
                children: [
                  Text(
                    '创建于 ${task['createdAt']}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (done)
                    TextButton(
                      onPressed: () => onOpen(task),
                      child: const Text('查看结果'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
