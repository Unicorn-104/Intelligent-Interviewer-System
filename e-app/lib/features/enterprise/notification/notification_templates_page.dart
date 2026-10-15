import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import 'mock_templates.dart';

/// 模块六：反馈与通知 - 通知模板管理页（P1 基础版）。
///
/// 依据《业务功能分析》UC-16（全流程状态通知与模板化管理）E1：
/// HR 可新增/修改通知模板，支持多语言版本；模板修改后实时生效。
/// 数据来源：本地 Mock 数据（mock_templates.dart），
/// TODO: P7阶段替换为真实接口（lib/api/notification_api.dart）。
class NotificationTemplatesPage extends StatefulWidget {
  const NotificationTemplatesPage({super.key});

  @override
  State<NotificationTemplatesPage> createState() =>
      _NotificationTemplatesPageState();
}

class _NotificationTemplatesPageState extends State<NotificationTemplatesPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>>? _templates;
  bool _loading = true;

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

  /// 模拟加载通知模板列表。
  /// TODO: P7阶段替换为真实接口（notification_api.listNotificationTemplates）。
  Future<void> _load() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final keyword = _search.text.trim();
    setState(() {
      _templates = mockNotificationTemplates
          .where(
            (t) =>
                keyword.isEmpty ||
                '${t['name']}${t['scene']}'.contains(keyword),
          )
          .toList();
      _loading = false;
    });
  }

  /// 模拟启用/停用模板。
  /// TODO: P7阶段替换为真实接口（notification_api.editNotificationTemplate）。
  Future<void> _toggleEnabled(Map<String, dynamic> template) async {
    final target = template['enabled'] == true ? '停用' : '启用';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认$target'),
        content: Text('确定要$target模板「${template['name']}」吗？（模拟操作，仅更新本地数据）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      template['enabled'] = !(template['enabled'] == true);
    });
  }

  /// 模拟新增模板（底部表单）。
  /// TODO: P7阶段替换为真实接口（notification_api.addNotificationTemplate）。
  Future<void> _openCreate() async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final scene = TextEditingController();
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('新增通知模板', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: '模板名称'),
                validator: (v) => (v == null || v.isEmpty) ? '请输入模板名称' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: scene,
                decoration: const InputDecoration(labelText: '通知场景（如：面试邀约）'),
                validator: (v) => (v == null || v.isEmpty) ? '请输入通知场景' : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    setState(() {
                      mockNotificationTemplates.add({
                        'tplId': 900 + mockNotificationTemplates.length,
                        'name': name.text.trim(),
                        'scene': scene.text.trim(),
                        'channels': ['邮件'],
                        'languages': ['中文'],
                        'enabled': true,
                        'updatedAt': '刚刚',
                        'placeholders': ['{{candidateName}}'],
                      });
                    });
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
    if (created == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('通知模板'),
          actions: [
            TextButton.icon(
              onPressed: _openCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增'),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                decoration: const InputDecoration(
                  hintText: '搜索模板名称或场景',
                  prefixIcon: Icon(Icons.search),
                ),
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
    final templates = _templates ?? const <Map<String, dynamic>>[];
    if (templates.isEmpty) {
      return PageMessage(
        icon: Icons.notifications_none,
        title: '暂无通知模板',
        message: _search.text.isNotEmpty ? '没有符合搜索条件的模板' : '点击右上角"新增"创建第一个模板',
        actionLabel: _search.text.isNotEmpty ? '清除搜索' : null,
        onAction: _search.text.isNotEmpty
            ? () {
                _search.clear();
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
        itemCount: templates.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) => _TemplateCard(
          template: templates[index],
          onToggle: () => _toggleEnabled(templates[index]),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onToggle});

  final Map<String, dynamic> template;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final enabled = template['enabled'] == true;
    final channels = (template['channels'] as List).cast<String>();
    final languages = (template['languages'] as List).cast<String>();
    final placeholders = (template['placeholders'] as List).cast<String>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${template['name']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: enabled
                        ? AppColors.primarySoft
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    enabled ? '启用中' : '已停用',
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled ? AppColors.green : AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '场景：${template['scene']}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: channels
                  .map(
                    (c) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        c,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.interactive,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),
            Text(
              '语言版本：${languages.join(' / ')} · 更新于 ${template['updatedAt']}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              '占位符：${placeholders.join('  ')}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: onToggle,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    side: BorderSide(
                      color: enabled ? AppColors.muted : AppColors.green,
                    ),
                    foregroundColor: enabled
                        ? AppColors.muted
                        : AppColors.green,
                  ),
                  child: Text(enabled ? '停用' : '启用'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
