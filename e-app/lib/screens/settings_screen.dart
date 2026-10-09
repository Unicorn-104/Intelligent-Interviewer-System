import 'package:flutter/material.dart';

import '../features/enterprise/enterprise_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/page_states.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.repository});
  final EnterpriseRepository repository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, List<Map<String, dynamic>>>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.repository.enterpriseSettings();
      if (mounted) setState(() { _data = data; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('企业设置')),
        body: _body(),
      );

  Widget _body() {
    if (_data == null && _error == null) return const PageLoading();
    if (_error != null) return PageMessage(icon: Icons.cloud_off_outlined, title: '企业设置加载失败', message: _error!, onAction: _load);
    final departments = _data!['departments']!;
    final members = _data!['members']!;
    final templates = _data!['templates']!;
    final integrations = _data!['integrations']!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _summaryCard('组织与成员', Icons.apartment_outlined, [
            _metric('部门', departments.length),
            _metric('成员', members.length),
          ]),
          const SizedBox(height: 16),
          const SectionTitle('部门'),
          _itemsCard(departments, empty: '暂无部门', title: (row) => '${row['name'] ?? row['deptName'] ?? '未命名部门'}', subtitle: (row) => '${row['memberCount'] ?? 0} 名成员'),
          const SizedBox(height: 16),
          const SectionTitle('招聘流程模板'),
          _itemsCard(templates, empty: '暂无流程模板', title: (row) => '${row['name'] ?? row['templateName'] ?? '未命名模板'}', subtitle: (row) => '${row['version'] ?? row['statusText'] ?? '可用'}'),
          const SizedBox(height: 16),
          const SectionTitle('外部集成'),
          _itemsCard(integrations, empty: '暂无外部集成', title: (row) => '${row['provider'] ?? row['name'] ?? '集成服务'}', subtitle: (row) => _enabled(row) ? '已启用' : '未启用'),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, IconData icon, List<Widget> metrics) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon, color: AppColors.interactive), const SizedBox(width: 10), Text(title, style: Theme.of(context).textTheme.titleMedium)]),
            const SizedBox(height: 18),
            Row(children: metrics),
          ]),
        ),
      );

  Widget _metric(String label, int value) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$value', style: const TextStyle(fontSize: 24, color: AppColors.brand, fontWeight: FontWeight.w600)), Text(label, style: Theme.of(context).textTheme.bodySmall)]));

  Widget _itemsCard(
    List<Map<String, dynamic>> rows, {
    required String empty,
    required String Function(Map<String, dynamic>) title,
    required String Function(Map<String, dynamic>) subtitle,
  }) => Card(
        child: rows.isEmpty
            ? Padding(padding: const EdgeInsets.all(18), child: Text(empty))
            : Column(children: rows.take(8).map((row) => ListTile(title: Text(title(row)), subtitle: Text(subtitle(row)), trailing: const Icon(Icons.chevron_right))).toList()),
      );

  bool _enabled(Map<String, dynamic> row) => row['enabled'] == true || '${row['enabled']}' == '1' || '${row['status']}' == '1';
}
