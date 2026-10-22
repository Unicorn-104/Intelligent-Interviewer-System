import 'package:flutter/material.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/domain/auth_session.dart';
import '../../../theme/app_theme.dart';
import '../data/ai_api.dart';
import '../domain/ai_models.dart';

/// History is an optional drawer; opening the assistant no longer depends on it.
class AiSessionsPanel extends StatefulWidget {
  static const draftId = '__new_conversation__';
  const AiSessionsPanel({
    super.key,
    required this.session,
    required this.api,
    required this.onSelected,
    this.onDeleted,
    this.selectedId,
  });
  final AuthSession session;
  final AiApi api;
  final ValueChanged<AiSession> onSelected;
  final ValueChanged<String>? onDeleted;
  final String? selectedId;
  @override
  State<AiSessionsPanel> createState() => _AiSessionsPanelState();
}

class _AiSessionsPanelState extends State<AiSessionsPanel> {
  List<AiSession> _sessions = [];
  bool _loading = true;
  String? _error;
  String? _next;
  bool _renaming = false;
  bool _managing = false;
  final Set<String> _checked = <String>{};
  List<AiSession> get _visibleSessions => [
    if (widget.selectedId == null)
      AiSession(AiSessionsPanel.draftId, '新对话', createdAt: DateTime.now()),
    ..._sessions,
  ];
  bool _selected(AiSession session) =>
      session.id == (widget.selectedId ?? AiSessionsPanel.draftId);
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (more && _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.sessions(
        widget.session.token,
        before: more ? _next : null,
      );
      if (!mounted) return;
      final items = (data['items'] as List)
          .map(
            (item) =>
                AiSession.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      setState(() {
        _sessions = more ? [..._sessions, ...items] : items;
        _next = data['nextCursor'] as String?;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : '历史会话加载失败，请重试');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rename(AiSession session) async {
    final input = TextEditingController(text: session.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名对话'),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(hintText: '输入对话标题'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
    if (!mounted || title == null) return;
    if (title.trim().isEmpty) {
      setState(() => _error = '会话标题不能为空');
      return;
    }
    setState(() {
      _renaming = true;
      _error = null;
    });
    try {
      final result = await widget.api.renameSession(
        widget.session.token,
        session.id,
        title.trim(),
      );
      if (!mounted) return;
      setState(() {
        _sessions = _sessions
            .map(
              (item) => item.id == session.id
                  ? AiSession(
                      item.id,
                      result['title'] as String,
                      createdAt: item.createdAt,
                      pinned: item.pinned,
                    )
                  : item,
            )
            .toList();
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException ? error.message : '重命名失败，请重试',
        );
      }
    } finally {
      if (mounted) setState(() => _renaming = false);
    }
  }

  Future<void> _pin(AiSession session) async {
    try {
      final result = await widget.api.pinSession(
        widget.session.token,
        session.id,
        !session.pinned,
      );
      if (!mounted) return;
      final pinned = result['pinned'] == true;
      setState(() {
        _sessions = _sessions
            .map(
              (item) => item.id == session.id
                  ? AiSession(
                      item.id,
                      item.title,
                      createdAt: item.createdAt,
                      pinned: pinned,
                    )
                  : item,
            )
            .toList();
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException ? error.message : '置顶操作失败，请重试',
        );
      }
    }
  }

  Future<void> _deleteOne(AiSession session) async {
    final confirmed = await _confirmDelete('确定删除“${session.title}”吗？删除后无法恢复。');
    if (confirmed) await _deleteSessions([session.id]);
  }

  Future<void> _deleteChecked() async {
    if (_checked.isEmpty) return;
    final confirmed = await _confirmDelete(
      '确定删除已选的 ${_checked.length} 个对话吗？删除后无法恢复。',
    );
    if (confirmed) await _deleteSessions(_checked.toList());
  }

  Future<bool> _confirmDelete(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除对话'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('删除'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _deleteSessions(List<String> ids) async {
    if (!mounted) return;
    setState(() => _renaming = true);
    try {
      if (ids.length == 1) {
        await widget.api.deleteSession(widget.session.token, ids.single);
      } else {
        await widget.api.deleteSessions(widget.session.token, ids);
      }
      if (!mounted) return;
      final deletedCurrent = ids.contains(widget.selectedId);
      setState(() {
        _sessions.removeWhere((item) => ids.contains(item.id));
        _checked.removeAll(ids);
        _renaming = false;
        _managing = false;
      });
      if (deletedCurrent) widget.onDeleted?.call(widget.selectedId!);
    } catch (error) {
      if (mounted) {
        setState(() {
          _renaming = false;
          _error = error is ApiException ? error.message : '删除失败，请重试';
        });
      }
    }
  }

  String _group(AiSession session) {
    final date = session.createdAt?.toLocal();
    if (date == null) return '更早';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (!day.isBefore(today)) return '今天';
    if (!day.isBefore(DateTime(today.year, today.month, today.day - 7))) {
      return '最近一周';
    }
    return '更早';
  }

  Widget _sessionTile(AiSession session) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Material(
      color: _selected(session) ? const Color(0xFFF6F6F6) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        selected: _selected(session),
        selectedColor: AppColors.ink,
        contentPadding: const EdgeInsets.only(left: 10, right: 2),
        leading: _managing && session.id != AiSessionsPanel.draftId
            ? Checkbox(
                value: _checked.contains(session.id),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _checked.add(session.id);
                  } else {
                    _checked.remove(session.id);
                  }
                }),
              )
            : null,
        title: Text(
          session.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        trailing:
            !_managing &&
                _selected(session) &&
                session.id != AiSessionsPanel.draftId
            ? PopupMenuButton<String>(
                tooltip: '会话操作',
                enabled: !_loading && !_renaming,
                icon: const Icon(
                  Icons.more_vert,
                  size: 19,
                  color: AppColors.muted,
                ),
                onSelected: (value) {
                  if (value == 'pin') {
                    _pin(session);
                  } else if (value == 'rename') {
                    _rename(session);
                  } else if (value == 'manage') {
                    setState(() {
                      _managing = true;
                      _checked
                        ..clear()
                        ..add(session.id);
                    });
                  } else if (value == 'delete') {
                    _deleteOne(session);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(session.pinned ? '取消置顶' : '置顶'),
                  ),
                  const PopupMenuItem(value: 'rename', child: Text('修改标题')),
                  const PopupMenuItem(value: 'manage', child: Text('批量管理')),
                  const PopupMenuItem(value: 'delete', child: Text('删除对话')),
                ],
              )
            : null,
        onTap: _renaming
            ? null
            : _managing
            ? () => setState(() {
                if (session.id == AiSessionsPanel.draftId) return;
                if (_checked.contains(session.id)) {
                  _checked.remove(session.id);
                } else {
                  _checked.add(session.id);
                }
              })
            : () => widget.onSelected(session),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.canvas,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _managing ? '选择对话' : '对话历史',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              if (_managing)
                TextButton(
                  onPressed: () => setState(() {
                    _managing = false;
                    _checked.clear();
                  }),
                  child: const Text('完成'),
                ),
              IconButton(
                tooltip: '关闭对话历史',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
        ),
        if (_renaming) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('重新加载')),
              ],
            ),
          ),
        Expanded(
          child: _loading && _sessions.isEmpty && widget.selectedId != null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (_visibleSessions.isEmpty && _error == null)
                        const Padding(
                          padding: EdgeInsets.all(AppSpacing.xxl),
                          child: Text(
                            '暂无历史会话，直接输入即可开始聊天',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (_visibleSessions.any(
                        (session) => session.pinned,
                      )) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(8, 20, 8, 6),
                          child: Text(
                            '置顶',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        for (final session in _visibleSessions.where(
                          (session) => session.pinned,
                        ))
                          _sessionTile(session),
                      ],
                      for (final group in ['今天', '最近一周', '更早'])
                        if (_visibleSessions.any(
                          (session) =>
                              !session.pinned && _group(session) == group,
                        )) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 20, 8, 6),
                            child: Text(
                              group,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          for (final session in _visibleSessions.where(
                            (session) =>
                                !session.pinned && _group(session) == group,
                          ))
                            _sessionTile(session),
                        ],
                      if (_next != null)
                        TextButton(
                          onPressed: _loading ? null : () => _load(more: true),
                          child: const Text('加载更多'),
                        ),
                    ],
                  ),
                ),
        ),
        if (_managing)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _checked.isEmpty || _renaming
                      ? null
                      : _deleteChecked,
                  icon: const Icon(Icons.delete_outline),
                  label: Text('删除已选 (${_checked.length})'),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
