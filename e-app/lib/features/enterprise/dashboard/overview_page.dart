import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';

/// 企业端概览数据来自 /system/dashboard/overview，通知及公告由上级 Tab 提供。
class OverviewPage extends StatefulWidget {
  const OverviewPage({
    super.key,
    this.onOpenTodo,
    this.onOpenNotifications,
    this.onOpenAnnouncements,
  });

  final ValueChanged<String?>? onOpenTodo;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenAnnouncements;

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'enterprise_access_token';

  final _client = ApiClient();
  Map<String, dynamic>? _overview;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null || token.isEmpty) {
        throw const ApiException('登录状态已失效，请重新登录');
      }
      final response = await _client.get(
        '/system/dashboard/overview',
        token: token,
      );
      final data = response['data'];
      if (data is! Map || data['stats'] is! Map || data['todos'] is! List) {
        throw const ApiException('概览数据暂不可用，请重试');
      }
      if (!mounted) return;
      setState(() => _overview = Map<String, dynamic>.from(data));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(
        () =>
            _error = error.isUnauthorized ? '登录状态已失效，请退出后重新登录' : error.message,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '概览加载失败，请重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonList(rows: 4);
    if (_error != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '概览加载失败',
        message: _error!,
        actionLabel: '重试',
        onAction: _load,
      );
    }
    final data = _overview!;
    final stats = Map<String, dynamic>.from(data['stats'] as Map);
    final todos = (data['todos'] as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Text('招聘概览', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 640 ? 4 : 2;
              final width =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatCard(
                    '在招岗位',
                    stats['activePositions'],
                    Icons.work_outline,
                    width: width,
                    color: AppColors.interactive,
                  ),
                  _StatCard(
                    '候选简历',
                    stats['resumeCount'],
                    Icons.description_outlined,
                    width: width,
                    color: AppColors.purple,
                  ),
                  _StatCard(
                    '待处理面试',
                    stats['pendingInterviews'],
                    Icons.schedule_outlined,
                    width: width,
                    color: AppColors.orange,
                  ),
                  _StatCard(
                    '本周已完成',
                    stats['weeklyCompleted'],
                    Icons.task_alt_outlined,
                    width: width,
                    color: AppColors.green,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text('待办事项', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (todos.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('当前暂无待办事项'),
              ),
            )
          else
            for (final todo in todos)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.task_alt_outlined,
                      color: _toneColor(todo['tone']),
                    ),
                    title: Text(_label(todo['title'], '未命名待办')),
                    subtitle: Text(
                      _label(todo['meta'], '查看待办详情'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      final go = todo['go']?.toString();
                      if (widget.onOpenTodo == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请在企业端主页打开待办事项')),
                        );
                      } else {
                        widget.onOpenTodo!(go);
                      }
                    },
                  ),
                ),
              ),
          const SizedBox(height: 14),
          Text('消息入口', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: widget.onOpenNotifications,
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('通知（演示数据）'),
              ),
              OutlinedButton.icon(
                onPressed: widget.onOpenAnnouncements,
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('公告（演示数据）'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _label(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static Color _toneColor(Object? tone) => switch (tone) {
    'blue' => AppColors.interactive,
    'cyan' => AppColors.green,
    'orange' => AppColors.orange,
    _ => AppColors.bodySoft,
  };
}

class _StatCard extends StatelessWidget {
  const _StatCard(
    this.label,
    this.value,
    this.icon, {
    required this.width,
    required this.color,
  });

  final String label;
  final Object? value;
  final IconData icon;
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(
              value?.toString() ?? '—',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
