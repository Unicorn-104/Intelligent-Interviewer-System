import 'package:flutter/material.dart';

import '../../../api/enterprise_memory_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';

/// 长期记忆管理页：开关 + 已保存记忆列表，与求职者端「记忆」页保持一致。
class EnterpriseMemoryPage extends StatefulWidget {
  const EnterpriseMemoryPage({super.key});

  @override
  State<EnterpriseMemoryPage> createState() => _EnterpriseMemoryPageState();
}

class _EnterpriseMemoryPageState extends State<EnterpriseMemoryPage> {
  EnterpriseMemory? _memory;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final memory = await getEnterpriseMemory();
      if (mounted) setState(() => _memory = memory);
    } catch (error) {
      if (mounted) showCompactError(context, _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _change({
    required String action,
    String? key,
    bool? enabled,
  }) async {
    final current = _memory;
    if (current == null || _saving) return;
    setState(() => _saving = true);
    try {
      final saved = await changeEnterpriseMemory(
        action: action,
        revision: current.revision,
        key: key,
        enabled: enabled,
      );
      if (mounted) {
        setState(() => _memory = saved);
      }
    } catch (error) {
      if (mounted) {
        showCompactError(context, _friendlyError(error));
        if (error is ApiException && error.message.contains('changed')) {
          await _load();
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空记忆'),
        content: const Text('将删除全部招聘偏好，且不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _change(action: 'clear');
  }

  @override
  Widget build(BuildContext context) {
    final memory = _memory;
    final items = memory?.items ?? const <EnterpriseMemoryItem>[];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '长期记忆',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.brand,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _toggleRow(memory),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '已存储的记忆',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (items.isNotEmpty)
                        TextButton(
                          onPressed: _saving ? null : _clearAll,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          child: const Text('清空'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (memory == null)
                    _retry()
                  else if (items.isEmpty)
                    _empty()
                  else
                    _card([
                      for (var index = 0; index < items.length; index++) ...[
                        if (index > 0) _divider,
                        _memoryRow(items[index]),
                      ],
                    ]),
                ],
              ),
            ),
    );
  }

  Widget _toggleRow(EnterpriseMemory? memory) => Container(
    decoration: _cardDecoration(),
    child: SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      dense: true,
      visualDensity: VisualDensity.compact,
      value: memory?.enabled ?? false,
      onChanged: memory == null || _saving
          ? null
          : (value) => _change(action: 'settings', enabled: value),
      title: const Text(
        '长期记忆',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      subtitle: Text(
        memory?.enabled == true ? '已开启，跨对话参考偏好' : '已关闭',
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
      activeThumbColor: AppColors.interactive,
      activeTrackColor: AppColors.primarySoft,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );

  Widget _memoryRow(EnterpriseMemoryItem item) => ListTile(
    contentPadding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
    minVerticalPadding: 8,
    visualDensity: VisualDensity.compact,
    title: Text(
      item.value,
      style: const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.35),
    ),
    subtitle: Text(
      '${item.label}${item.updatedAt == null ? '' : ' · ${_shortTime(item.updatedAt!)}'}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
    ),
    trailing: IconButton(
      onPressed: _saving
          ? null
          : () => _change(action: 'forget', key: item.key),
      icon: const Icon(
        Icons.delete_outline,
        size: 18,
        color: AppColors.textMuted,
      ),
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      tooltip: '删除',
    ),
  );

  Widget _empty() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 28),
    child: Column(
      children: [
        Icon(Icons.psychology_outlined, size: 28, color: AppColors.textMuted),
        SizedBox(height: 10),
        Text('还没有记忆', style: TextStyle(fontSize: 14, color: AppColors.body)),
        SizedBox(height: 4),
        Text(
          '对话后会保存明确的招聘偏好',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    ),
  );

  Widget _retry() => Center(
    child: TextButton.icon(
      onPressed: _loading ? null : _load,
      icon: const Icon(Icons.refresh, size: 16),
      label: const Text('重新加载', style: TextStyle(fontSize: 12)),
    ),
  );

  Widget _card(List<Widget> children) => Container(
    decoration: _cardDecoration(),
    child: Column(children: children),
  );

  Widget get _divider => const Divider(
    height: 1,
    indent: 12,
    endIndent: 12,
    color: AppColors.hairline,
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.hairline),
  );

  String _shortTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
  }

  String _friendlyError(Object error) {
    if (error is ApiException) {
      final message = error.message;
      if (message.contains('No static resource')) return '记忆接口未部署';
      if (message.contains('migration')) return '记忆未初始化';
      if (message.contains('disabled')) return '记忆未开启';
      if (message.contains('changed')) return '记忆已更新，请重试';
      if (message.contains('invalid')) return '参数错误';
      return message;
    }
    return '操作失败，请重试';
  }
}
