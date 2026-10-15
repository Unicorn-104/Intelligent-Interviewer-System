import 'package:flutter/material.dart';

import '../../../api/message_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';

/// 公告列表和已读状态均来自服务端；列表接口没有置顶字段。
class NoticePage extends StatefulWidget {
  const NoticePage({super.key});

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage> {
  List<Map<String, dynamic>> _notices = const [];
  int _unreadCount = 0;
  bool _loading = true;
  bool _markingAll = false;
  String? _error;
  final Set<int> _marking = {};
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await listTopNotices();
      final rows = result['data'];
      if (rows is! List) throw const ApiException('公告响应格式不正确');
      final notices = rows
          .whereType<Map>()
          .map(
            (row) => <String, dynamic>{
              'id': int.tryParse('${row['noticeId']}'),
              'title': _text(row['noticeTitle'], '未命名公告'),
              'content': _text(row['noticeContent'], '暂无正文'),
              'read': row['isRead'] == true,
              'publishTime': _text(row['createTime'], '发布时间未提供'),
            },
          )
          .toList();
      if (!mounted || request != _request) return;
      setState(() {
        _notices = notices;
        // 解包 Map 中的 unreadCount 来源于后端响应顶层，不从列表推算。
        _unreadCount = int.tryParse('${result['unreadCount']}') ?? 0;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() => _error = _friendly(error));
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> notice) async {
    final id = notice['id'] as int?;
    if (notice['read'] == true ||
        _markingAll ||
        id == null ||
        _marking.contains(id)) {
      return;
    }
    setState(() => _marking.add(id));
    try {
      await markNoticeRead(id);
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendly(error))));
    } finally {
      if (mounted) setState(() => _marking.remove(id));
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll || _marking.isNotEmpty) return;
    setState(() => _markingAll = true);
    try {
      // 仅标记当前列表中实际返回的公告，成功后重新获取服务端未读数。
      for (final notice in _notices.where((row) => row['read'] != true)) {
        final id = notice['id'] as int?;
        if (id != null) await markNoticeRead(id);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendly(error))));
      }
    } finally {
      if (mounted) {
        await _load();
        if (mounted) setState(() => _markingAll = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_loading || _error != null ? '公告' : '公告 · 未读 $_unreadCount'),
      actions: [
        if (!_loading && _error == null && _unreadCount > 0)
          TextButton.icon(
            onPressed: _markingAll || _marking.isNotEmpty ? null : _markAllRead,
            icon: const Icon(Icons.done_all, size: 18),
            label: Text(_markingAll ? '处理中…' : '全部已读'),
          ),
      ],
    ),
    body: _body(),
  );

  Widget _body() {
    if (_loading) return const SkeletonList(rows: 3);
    if (_error != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '公告加载失败',
        message: _error!,
        actionLabel: '重试',
        onAction: _load,
      );
    }
    if (_notices.isEmpty) {
      return PageMessage(
        icon: Icons.notifications_none,
        title: '暂无公告',
        message: '当前没有可显示的公告',
        actionLabel: '刷新',
        onAction: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        itemCount: _notices.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final notice = _notices[index];
          final read = notice['read'] == true;
          final id = notice['id'] as int?;
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: id == null || _markingAll || _marking.contains(id)
                  ? null
                  : () => _markRead(notice),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${notice['title']}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          read ? '已读' : '未读',
                          style: TextStyle(
                            fontSize: 12,
                            color: read ? AppColors.muted : AppColors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${notice['content']}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${notice['publishTime']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _text(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String _friendly(Object error) =>
      error is ApiException ? error.message : '请求失败，请重试';
}
