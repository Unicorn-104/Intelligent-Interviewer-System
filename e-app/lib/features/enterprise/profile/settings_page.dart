import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import 'company_info_page.dart';

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
  Widget build(BuildContext context) => Container(
    key: const Key('profile-enterprise-management'),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '企业管理',
          style: TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '企业协作，让招聘更有序',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _companyInfoEntry(),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else ...[
          Row(
            key: const Key('profile-management-row'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final name in _sections.keys)
                Expanded(child: _managementEntry(name)),
            ],
          ),
          if (_error != null ||
              _counts!.values.any((count) => count == null)) ...[
            const SizedBox(height: 12),
            Text(
              _error ?? '部分管理数据暂不可用，请稍后重试或在 Web 端查看',
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('profile-management-retry'),
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重新加载'),
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'App 内详细管理功能开发中，请在 Web 端操作',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ],
    ),
  );

  Future<void> _openCompanyInfo() async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const CompanyInfoPage()));
  }

  Widget _companyInfoEntry() => Material(
    color: AppColors.primarySoft,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      key: const Key('profile-company-info'),
      borderRadius: BorderRadius.circular(8),
      onTap: _openCompanyInfo,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.business_outlined,
                color: AppColors.interactive,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '企业信息',
                    style: TextStyle(
                      color: AppColors.body,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '查看与编辑求职者可见的企业资料',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
          ],
        ),
      ),
    ),
  );

  Widget _managementEntry(String name) => InkWell(
    key: ValueKey('profile-management-$name'),
    borderRadius: BorderRadius.circular(8),
    onTap: () =>
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$name功能开发中，请在 Web 端操作'))),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              switch (name) {
                '部门管理' => Icons.apartment_outlined,
                '成员管理' => Icons.people_outline,
                '通知模板' => Icons.notifications_outlined,
                _ => Icons.tune_rounded,
              },
              color: AppColors.interactive,
              size: 26,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.body),
          ),
          const SizedBox(height: 4),
          Text(
            _error != null || _counts?[name] == null
                ? 'Web 端查看'
                : '${_counts![name]} 条记录',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}
