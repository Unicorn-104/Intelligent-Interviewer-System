import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/skeleton_list.dart';

/// 保留旧页面入口，企业管理概览同时复用于“我的”主页。
class EnterpriseSettingsPage extends StatelessWidget {
  const EnterpriseSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('企业设置')),
    body: const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: EnterpriseManagementPanel(),
    ),
  );
}

/// 只读复用既有企业设置接口，详细管理能力仍在 Web 端。
class EnterpriseManagementPanel extends StatefulWidget {
  const EnterpriseManagementPanel({super.key});

  @override
  State<EnterpriseManagementPanel> createState() =>
      _EnterpriseManagementPanelState();
}

class _EnterpriseManagementPanelState extends State<EnterpriseManagementPanel> {
  static const _sections = {
    '部门管理': '/system/enterprise/settings/depts',
    '成员管理': '/system/enterprise/settings/members',
    '通知模板': '/system/enterprise/settings/templates',
    '集成配置': '/system/enterprise/settings/integrations',
  };
  static const _storage = FlutterSecureStorage();
  final _client = ApiClient();
  bool _loading = true;
  String? _error;
  Map<String, int?>? _counts;

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
      final token = await _storage.read(key: 'enterprise_access_token');
      if (token == null || token.isEmpty) {
        throw const ApiException('登录已失效，请重新登录');
      }
      final result = <String, int?>{};
      for (final entry in _sections.entries) {
        if (!mounted) return;
        try {
          final response = await _client.get(entry.value, token: token);
          final rows = response['data'] ?? response['rows'];
          if (rows is! List) throw const ApiException('企业设置响应格式不正确');
          result[entry.key] = rows.length;
        } on ApiException catch (error) {
          if (error.isUnauthorized) rethrow;
          result[entry.key] = null;
        }
      }
      if (mounted) setState(() => _counts = result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '企业设置加载失败，请重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('profile-enterprise-management'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('企业管理', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      if (_loading)
        const SizedBox(height: 240, child: SkeletonList(rows: 4))
      else ...[
        if (_error != null || _counts!.values.any((count) => count == null))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _error ?? '部分管理接口暂不可用，请稍后重试或在 Web 端查看',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextButton.icon(
                  key: const Key('profile-management-retry'),
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        for (final name in _sections.keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                key: ValueKey('profile-management-$name'),
                leading: Icon(switch (name) {
                  '部门管理' => Icons.apartment_outlined,
                  '成员管理' => Icons.people_outline,
                  '通知模板' => Icons.notifications_outlined,
                  _ => Icons.settings_input_component_outlined,
                }, color: AppColors.interactive),
                title: Text(name),
                subtitle: Text(
                  _error != null || _counts?[name] == null
                      ? '暂不可用，请在 Web 端查看'
                      : '当前记录：${_counts![name]} 条',
                ),
              ),
            ),
          ),
        Text(
          'App 内详细管理功能开发中，请在 Web 端操作',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ],
  );
}
