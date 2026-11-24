import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../auth/domain/auth_session.dart';
import '../data/ai_api.dart';

class AiLongTermMemoriesSheet extends StatefulWidget {
  const AiLongTermMemoriesSheet({
    super.key,
    required this.session,
    required this.api,
    required this.editingAllowed,
  });
  final AuthSession session;
  final AiApi api;
  final bool editingAllowed;
  @override
  State<AiLongTermMemoriesSheet> createState() =>
      _AiLongTermMemoriesSheetState();
}

class _AiLongTermMemoriesSheetState extends State<AiLongTermMemoriesSheet> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true, _settingsLoading = true, _saving = false;
  bool _enabled = false;
  int _revision = 0;
  String? _error, _settingsError, _busyId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _load();
  }

  String _message(Object error, String fallback) =>
      error is ApiException ? error.message : fallback;

  Future<void> _loadSettings() async {
    setState(() {
      _settingsLoading = true;
      _settingsError = null;
    });
    try {
      final settings = await widget.api.memorySettings(widget.session.token);
      if (!mounted) return;
      setState(() {
        _enabled = settings['enabled'] == true;
        _revision = (settings['revision'] as num).toInt();
      });
    } catch (error) {
      if (mounted) {
        setState(() => _settingsError = _message(error, '记忆设置加载失败，请重试'));
      }
    } finally {
      if (mounted) setState(() => _settingsLoading = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.api.longTermMemories(widget.session.token);
      if (mounted) setState(() => _items = List.of(items));
    } catch (error) {
      if (mounted) setState(() => _error = _message(error, '记忆加载失败，请重试'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    if (_saving || _busyId != null) return;
    setState(() {
      _saving = true;
      _settingsError = null;
    });
    try {
      final settings = await widget.api.setMemoryEnabled(
        widget.session.token,
        enabled,
        _revision,
      );
      if (!mounted) return;
      setState(() {
        _enabled = settings['enabled'] == true;
        _revision = (settings['revision'] as num).toInt();
      });
    } catch (error) {
      if (!mounted) return;
      final message = _message(error, '记忆设置保存失败，请重试');
      await _loadSettings();
      if (mounted) setState(() => _settingsError = message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    if (id == null || _busyId != null || _saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条记忆？'),
        content: const Text('删除后不会再用于后续 AI 对话，原聊天记录仍保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busyId = id;
      _error = null;
    });
    try {
      await widget.api.deleteLongTermMemory(widget.session.token, id);
      if (mounted) {
        setState(
          () => _items = _items.where((row) => row['id'] != id).toList(),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error, '记忆删除失败，请重试'));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('记忆')),
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '记忆',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                if (_saving || _settingsLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const SizedBox(width: 8),
                Switch(
                  value: _enabled,
                  onChanged:
                      _settingsLoading ||
                          _saving ||
                          _settingsError != null ||
                          _busyId != null ||
                          !widget.editingAllowed
                      ? null
                      : _setEnabled,
                ),
              ],
            ),
          ),
          if (!_settingsLoading && _settingsError == null && !_enabled)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                '记忆已关闭，已保存的内容仍可查看和删除。',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          if (_settingsError != null) _errorRow(_settingsError!, _loadSettings),
          if (!widget.editingAllowed)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('回答生成期间暂不能修改记忆，请完成或停止回答后重试。'),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text('已存储的记忆', style: TextStyle(color: AppColors.bodySoft)),
          ),
          if (_error != null) _errorRow(_error!, _load),
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _items.isEmpty
                ? const SizedBox.shrink()
                : _items.isEmpty
                ? const Center(child: Text('暂无已存储的记忆'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) =>
                          const Divider(color: AppColors.hairline),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: SelectableText(
                            item['content']?.toString() ?? '',
                          ),
                          trailing: _busyId == item['id']
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : IconButton(
                                  tooltip: '删除记忆',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed:
                                      widget.editingAllowed &&
                                          !_saving &&
                                          _busyId == null &&
                                          !_loading
                                      ? () => _delete(item)
                                      : null,
                                ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    ),
  );

  Widget _errorRow(String message, VoidCallback retry) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(message, style: const TextStyle(color: AppColors.red)),
        ),
        TextButton(
          onPressed: _saving || _busyId != null ? null : retry,
          child: const Text('重试'),
        ),
      ],
    ),
  );
}
