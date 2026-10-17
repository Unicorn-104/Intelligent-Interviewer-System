import 'package:flutter/material.dart';

import '../features/enterprise/enterprise_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/page_states.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.repository, required this.displayName, required this.onOpenJobs});

  final EnterpriseRepository repository;
  final String displayName;
  final VoidCallback onOpenJobs;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await widget.repository.dashboard();
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null && _error == null) return const PageLoading();
    if (_error != null) {
      return PageMessage(icon: Icons.cloud_off_outlined, title: '招聘总览加载失败', message: _error!, onAction: _load);
    }
    final data = _data!;
    final stats = Map<String, dynamic>.from(data['stats'] as Map? ?? const {});
    final funnel = Map<String, dynamic>.from(data['funnel'] as Map? ?? const {});
    final todos = _maps(data['todos']);
    final timeline = _maps(data['timeline']);
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? '早上好' : hour < 18 ? '下午好' : '晚上好';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text('$greeting，${widget.displayName}', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          const Text('掌握招聘进度，及时处理关键任务', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _StatCard(label: '在招岗位', value: stats['activePositions'], icon: Icons.work_outline, color: AppColors.interactive),
              _StatCard(label: '候选简历', value: stats['resumeCount'], icon: Icons.description_outlined, color: AppColors.purple),
              _StatCard(label: '待处理面试', value: stats['pendingInterviews'], icon: Icons.schedule_outlined, color: AppColors.orange),
              _StatCard(label: '本周已完成', value: stats['weeklyCompleted'], icon: Icons.task_alt_outlined, color: AppColors.green),
            ],
          ),
          const SizedBox(height: 20),
          const SectionTitle('招聘漏斗 · 近 30 天'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _FunnelRow('简历投递', funnel['applied'], AppColors.interactive),
                  _FunnelRow('初筛通过', funnel['screened'], AppColors.purple),
                  _FunnelRow('面试中', funnel['interviewing'], AppColors.orange),
                  _FunnelRow('已录用', funnel['hired'], AppColors.green),
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('录用转化率'), Text('${funnel['conversion'] ?? 0}%', style: const TextStyle(color: AppColors.interactive, fontWeight: FontWeight.w600))]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SectionTitle('待办事项', trailing: Text('${todos.length} 项', style: Theme.of(context).textTheme.bodySmall)),
          if (todos.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('当前没有待办事项')))
          else
            ...todos.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: AppColors.primarySoft, child: Icon(Icons.notifications_active_outlined, color: AppColors.interactive)),
                  title: Text('${item['title'] ?? '待办'}'),
                  subtitle: Text('${item['meta'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: item['go']?.toString().contains('jobs') == true ? widget.onOpenJobs : null,
                ),
              ),
            )),
          const SizedBox(height: 10),
          const SectionTitle('最近动态'),
          Card(
            child: timeline.isEmpty
                ? const Padding(padding: EdgeInsets.all(20), child: Text('暂无动态'))
                : Column(children: timeline.map((item) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.circle, size: 10, color: AppColors.interactive),
                    title: Text('${item['text'] ?? ''}'),
                    trailing: Text('${item['time'] ?? ''}', style: Theme.of(context).textTheme.bodySmall),
                  )).toList()),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _maps(Object? value) => value is List
      ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
      : const [];
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final Object? value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(icon, color: color),
            Text('${value ?? '-'}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.brand)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
}

class _FunnelRow extends StatelessWidget {
  const _FunnelRow(this.label, this.value, this.color);
  final String label;
  final Object? value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 10), Expanded(child: Text(label)), Text('${value ?? 0}', style: const TextStyle(fontWeight: FontWeight.w600))]),
      );
}
