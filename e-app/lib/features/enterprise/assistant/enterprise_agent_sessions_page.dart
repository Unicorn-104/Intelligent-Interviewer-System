import 'package:flutter/material.dart';

import '../../../api/enterprise_memory_api.dart';
import '../../../theme/app_theme.dart';
import 'enterprise_ai_data_source.dart';

/// Agent 对话管理：按会话重置上下文或删除历史对话。
class EnterpriseAgentSessionsPage extends StatefulWidget {
  const EnterpriseAgentSessionsPage({super.key});

  @override
  State<EnterpriseAgentSessionsPage> createState() =>
      _EnterpriseAgentSessionsPageState();
}

class _EnterpriseAgentSessionsPageState
    extends State<EnterpriseAgentSessionsPage> {
  final _source = EnterpriseAiDataSource();
  final _sessions = <EnterpriseAiSession>[];
  bool _loading = true;
  bool _moreLoading = false;
  int? _busyId;
  int? _next;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_moreLoading || _next == null)) return;
    setState(() {
      if (more) {
        _moreLoading = true;
      } else {
        _loading = true;
      }
    });
    try {
      final data = await _source.sessions(before: more ? _next : null);
      if (!mounted) return;
      setState(() {
        if (!more) _sessions.clear();
        final ids = _sessions.map((row) => row.id).toSet();
        _sessions.addAll(data.items.where((row) => !ids.contains(row.id)));
        _next = data.next;
      });
    } catch (error) {
      if (mounted) showCompactError(context, _message(error));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _moreLoading = false;
        });
      }
    }
  }

  Future<void> _resetContext(EnterpriseAiSession session) async {
    final confirmed = await _confirm(
      title: '重置对话上下文',
      content:
          '将清除“${session.title}”的会话摘要，后续回答不再引用此对话已有消息。'
          '聊天记录和长期记忆都会保留。',
      confirmText: '重置',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyId = session.id);
    try {
      final memory = await getEnterpriseMemory();
      await changeEnterpriseMemory(
        action: 'reset_context',
        revision: memory.revision,
        sessionId: session.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(compactSnackBar('该对话上下文已重置'));
      }
    } catch (error) {
      if (mounted) showCompactError(context, _message(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(EnterpriseAiSession session) async {
    final confirmed = await _confirm(
      title: '删除历史对话',
      content: '确定删除“${session.title}”吗？聊天记录、会话摘要和上下文围栏将被删除，且无法恢复。',
      confirmText: '删除',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyId = session.id);
    try {
      await _source.delete(session.id);
      if (mounted) {
        setState(() => _sessions.removeWhere((row) => row.id == session.id));
        ScaffoldMessenger.of(context).showSnackBar(compactSnackBar('对话已删除'));
      }
    } catch (error) {
      if (mounted) showCompactError(context, _message(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _message(Object error) {
    final text = EnterpriseAiDataSource.errorMessage(error);
    if (text.contains('登录')) return '登录已过期，请重新登录';
    if (text.contains('不存在') || text.contains('尚未部署')) return '对话接口未部署';
    if (text.contains('权限') || text.contains('绑定企业')) return '无企业权限';
    return text.length > 18 ? '对话操作失败，请稍后重试' : text;
  }

  Future<bool?> _confirm({
    required String title,
    required String content,
    required String confirmText,
    bool destructive = false,
  }) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: AppColors.error)
              : null,
          child: Text(confirmText),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text(
        '对话与上下文',
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
                Text(
                  '历史对话（${_sessions.length}）',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                if (_sessions.isEmpty)
                  _empty()
                else
                  _card([
                    for (var index = 0; index < _sessions.length; index++) ...[
                      if (index > 0) _divider,
                      _sessionRow(_sessions[index]),
                    ],
                  ]),
                if (_next != null)
                  Center(
                    child: TextButton(
                      onPressed: _moreLoading ? null : () => _load(more: true),
                      child: Text(
                        _moreLoading ? '加载中…' : '加载更多',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
  );

  Widget _sessionRow(EnterpriseAiSession session) {
    final active = session.activeRunId != null;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
      minVerticalPadding: 8,
      visualDensity: VisualDensity.compact,
      leading: const Icon(
        Icons.forum_outlined,
        size: 18,
        color: AppColors.interactive,
      ),
      title: Text(
        session.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      subtitle: Text(
        active
            ? '回答生成中'
            : session.updatedAt == null
            ? '可重置上下文或删除'
            : _shortTime(session.updatedAt!),
        maxLines: 1,
        style: TextStyle(
          fontSize: 10.5,
          color: active ? AppColors.warning : AppColors.textMuted,
        ),
      ),
      trailing: _busyId == session.id
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : PopupMenuButton<String>(
              enabled: !active && _busyId == null,
              tooltip: '对话操作',
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              onSelected: (action) {
                if (action == 'reset') {
                  _resetContext(session);
                } else if (action == 'delete') {
                  _delete(session);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'reset', child: Text('重置上下文')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('删除对话', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
    );
  }

  Widget _empty() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 28),
    child: Column(
      children: [
        Icon(Icons.forum_outlined, size: 28, color: AppColors.textMuted),
        SizedBox(height: 10),
        Text('暂无历史对话', style: TextStyle(fontSize: 14, color: AppColors.body)),
        SizedBox(height: 4),
        Text(
          '使用 AI 招聘助手后显示',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
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

  static BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.hairline),
  );

  static String _shortTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
  }
}
