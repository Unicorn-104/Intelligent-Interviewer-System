import 'package:flutter/material.dart';

import '../features/auth/auth_controller.dart';
import '../features/enterprise/enterprise_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/page_states.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.repository, required this.auth});
  final EnterpriseRepository repository;
  final AuthController auth;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.repository.profile();
      if (mounted) setState(() { _profile = data; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_profile == null && _error == null) return const PageLoading();
    if (_error != null) return PageMessage(icon: Icons.cloud_off_outlined, title: '个人信息加载失败', message: _error!, onAction: _load);
    final source = Map<String, dynamic>.from(_profile?['user'] as Map? ?? _profile ?? const {});
    final roles = widget.auth.user['roles'];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                CircleAvatar(radius: 32, backgroundColor: AppColors.primarySoft, child: Text(widget.auth.displayName.characters.first, style: const TextStyle(fontSize: 22, color: AppColors.interactive, fontWeight: FontWeight.w600))),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.auth.displayName, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 5),
                  Text('${source['email'] ?? source['phonenumber'] ?? source['userName'] ?? '企业招聘账号'}', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  const Text('企业招聘成员', style: TextStyle(color: AppColors.interactive, fontSize: 12)),
                ])),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('账号与企业'),
          Card(
            child: Column(children: [
              ListTile(leading: const Icon(Icons.badge_outlined), title: const Text('账号角色'), subtitle: Text(roles is List ? roles.map((e) => '$e').join('、') : 'HR')),
              const Divider(height: 1, indent: 56),
              ListTile(leading: const Icon(Icons.business_outlined), title: const Text('企业与部门'), subtitle: Text('${source['dept']?['deptName'] ?? source['deptName'] ?? '以后台绑定信息为准'}')),
            ]),
          ),
          const SizedBox(height: 20),
          const SectionTitle('工作设置'),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.apartment_outlined),
                title: const Text('企业设置'),
                subtitle: const Text('部门、成员、模板与集成'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(repository: widget.repository))),
              ),
              const Divider(height: 1, indent: 56),
              const ListTile(leading: Icon(Icons.notifications_outlined), title: Text('消息通知'), subtitle: Text('会话和面试提醒由系统通知配置控制'), trailing: Icon(Icons.chevron_right)),
              const Divider(height: 1, indent: 56),
              const ListTile(leading: Icon(Icons.security_outlined), title: Text('账号安全'), subtitle: Text('修改密码和登录设备管理'), trailing: Icon(Icons.chevron_right)),
              const Divider(height: 1, indent: 56),
              const ListTile(leading: Icon(Icons.help_outline), title: Text('帮助与反馈'), trailing: Icon(Icons.chevron_right)),
            ]),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: widget.auth.busy ? null : () async {
              final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('退出登录'), content: const Text('确定退出当前企业账号吗？'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('退出'))]));
              if (confirmed == true) await widget.auth.logout();
            },
            child: const Text('退出登录', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}
