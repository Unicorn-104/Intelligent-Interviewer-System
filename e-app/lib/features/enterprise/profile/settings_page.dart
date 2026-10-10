import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';

/// 只读展示服务端已有的企业设置；不在 App 内虚构编辑能力。
class EnterpriseSettingsPage extends StatefulWidget {
  const EnterpriseSettingsPage({super.key});

  @override
  State<EnterpriseSettingsPage> createState() => _EnterpriseSettingsPageState();
}

class _EnterpriseSettingsPageState extends State<EnterpriseSettingsPage> {
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
      for (final entry in {
        '部门': '/system/enterprise/settings/depts',
        '成员': '/system/enterprise/settings/members',
        '通知模板': '/system/enterprise/settings/templates',
        '集成配置': '/system/enterprise/settings/integrations',
      }.entries) {
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('企业设置')),
    body: _buildBody(),
  );

  Widget _buildBody() {
    if (_loading) return const SkeletonList(rows: 4);
    if (_error != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '企业设置加载失败',
        message: _error!,
        actionLabel: '重试',
        onAction: _load,
      );
    }
    final data = _counts!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text('企业设置概览', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (data.values.any((count) => count == null)) ...[
            Text(
              '部分设置接口暂不可用，请稍后重试或在 Web 端查看',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
          for (final entry in data.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: Icon(switch (entry.key) {
                    '部门' => Icons.apartment_outlined,
                    '成员' => Icons.people_outline,
                    '通知模板' => Icons.notifications_outlined,
                    _ => Icons.settings_input_component_outlined,
                  }, color: AppColors.interactive),
                  title: Text(entry.key),
                  subtitle: Text(
                    entry.value == null
                        ? '暂不可用，请在 Web 端查看'
                        : '当前记录：${entry.value} 条',
                  ),
                ),
              ),
            ),
          Text('详细配置请在 Web 端操作', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
