import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/filter_chips.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import 'mock_notification.dart';

/// 模块六：反馈与通知 - 通知发送日志页（P5）。
///
/// 依据《业务功能分析》UC-16（全流程状态通知与模板化管理）E2：
/// HR 按候选人、场景、时间范围检索通知发送记录，
/// 查看各渠道送达率、打开率（邮件）、点击率（链接）等统计指标。
/// 数据来源：本地 Mock 数据（mock_notification.dart），
/// TODO: P7阶段替换为真实接口（lib/api/notification_api.dart 的
/// listNotificationLogs / getNotificationStats）。
class NotificationLogPage extends StatefulWidget {
  const NotificationLogPage({super.key});

  @override
  State<NotificationLogPage> createState() => _NotificationLogPageState();
}

class _NotificationLogPageState extends State<NotificationLogPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>>? _logs;
  bool _loading = true;
  int _sceneIndex = 0; // 0=全部场景

  static const _scenes = ['全部场景', '简历投递成功', '面试邀约', '面试提醒', '评估完成', '初筛淘汰'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 模拟日志检索（候选人关键词 + 场景筛选）。
  /// TODO: P7阶段替换为真实接口（notification_api.listNotificationLogs）。
  Future<void> _load() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final keyword = _search.text.trim();
    final scene = _sceneIndex == 0 ? null : _scenes[_sceneIndex];
    setState(() {
      _logs = mockNotificationLogs.where((log) {
        final matchKeyword =
            keyword.isEmpty || '${log['candidateName']}'.contains(keyword);
        final matchScene = scene == null || log['scene'] == scene;
        return matchKeyword && matchScene;
      }).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(title: const Text('通知发送日志')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatCards(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _load(),
                    decoration: const InputDecoration(
                      hintText: '按候选人姓名检索',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilterChips(
                    labels: _scenes,
                    selectedIndex: _sceneIndex,
                    onChanged: (index) {
                      setState(() => _sceneIndex = index);
                      _load();
                    },
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

  /// 送达率/打开率/点击率统计卡片（UC-16 E2）。
  Widget _buildStatCards() {
    final stats = mockNotificationStats;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          _StatCard(
            label: '送达率',
            value: '${stats['deliveryRate']}%',
            color: AppColors.green,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: '打开率',
            value: '${stats['openRate']}%',
            color: AppColors.interactive,
          ),
          const SizedBox(width: 10),
          _StatCard(
            label: '点击率',
            value: '${stats['clickRate']}%',
            color: AppColors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const SkeletonList(rows: 4);
    final logs = _logs ?? const <Map<String, dynamic>>[];
    if (logs.isEmpty) {
      return PageMessage(
        icon: Icons.notifications_off_outlined,
        title: '暂无发送记录',
        message: _search.text.isNotEmpty || _sceneIndex != 0
            ? '没有符合当前检索条件的发送日志'
            : '累计发送通知 ${mockNotificationStats['totalSent']} 条，暂无匹配记录',
        actionLabel: _search.text.isNotEmpty || _sceneIndex != 0
            ? '清除条件'
            : null,
        onAction: _search.text.isNotEmpty || _sceneIndex != 0
            ? () {
                _search.clear();
                setState(() => _sceneIndex = 0);
                _load();
              }
            : null,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: logs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) => _LogCard(log: logs[index]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log});

  final Map<String, dynamic> log;

  @override
  Widget build(BuildContext context) {
    final success = log['status'] == 'success';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${log['candidateName']} · ${log['scene']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Icon(
                  success ? Icons.check_circle_outline : Icons.error_outline,
                  size: 16,
                  color: success ? AppColors.green : AppColors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  success ? '送达' : '失败已降级',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: success ? AppColors.green : AppColors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${log['channel']}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.interactive,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '发送于 ${log['sentAt']}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  success
                      ? '打开${log['opened'] == true ? '✓' : '✗'} · 点击${log['clicked'] == true ? '✓' : '✗'}'
                      : '已切换短信重发',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: success ? AppColors.muted : AppColors.orange,
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
