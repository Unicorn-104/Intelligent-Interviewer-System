import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/skeleton_list.dart';
import 'data/message_data_source.dart';
import 'models/message_view_data.dart';
import '../schedule/data/reschedule_review_data_source.dart';
import '../schedule/reschedule_review_page.dart';

class SystemNotificationsPage extends StatefulWidget {
  const SystemNotificationsPage({super.key, required this.source});
  final MessageDataSource source;
  @override
  State<SystemNotificationsPage> createState() =>
      _SystemNotificationsPageState();
}

class _SystemNotificationsPageState extends State<SystemNotificationsPage> {
  List<SystemMessage> _items = [];
  bool _loading = true, _more = false, _loadingMore = false, _action = false;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_loadingMore || (more && (!_more || _loading))) return;
    final request = ++_request;
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
      }
      _error = null;
    });
    try {
      final rows = await widget.source.loadNotifications(
        beforeId: more && _items.isNotEmpty ? _items.last.id : null,
      );
      if (!mounted || request != _request) return;
      final combined = <int, SystemMessage>{
        if (more)
          for (final item in _items) item.id: item,
        for (final item in rows.items) item.id: item,
      };
      if (more && rows.hasMore && combined.length == _items.length) {
        throw const FormatException('通知分页未更新，请刷新');
      }
      setState(() {
        _items = combined.values.toList();
        _more = rows.hasMore;
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = messageError(error));
      }
    } finally {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _open(SystemMessage item) async {
    if (_action) return;
    setState(() => _action = true);
    try {
      if (!item.isRead) {
        await widget.source.readNotification(item.id);
      }
      if (!mounted) return;
      setState(
        () => _items = _items
            .map((row) => row.id == item.id ? row.read : row)
            .toList(),
      );
      final requestId = item.rescheduleRequestId;
      if (requestId != null) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => RescheduleReviewPage(
              initialRequestId: requestId,
              source: RescheduleReviewDataSource(client: widget.source.client),
            ),
          ),
        );
        if (mounted) await _load();
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.canvas,
        builder: (context) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                '${messageDate(item.time)} ${messageClock(item.time)}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(item.content),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(messageError(error))));
      }
    } finally {
      if (mounted) setState(() => _action = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('系统通知')),
    body: _loading
        ? const SkeletonList(rows: 4)
        : RefreshIndicator(
            onRefresh: () => _load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                  TextButton(
                    onPressed: () => _load(),
                    child: const Text('重试加载通知'),
                  ),
                ],
                if (_items.isEmpty && _error == null)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 44,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 12),
                        Text('暂无系统通知'),
                      ],
                    ),
                  ),
                for (final item in _items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        key: ValueKey('system-message-${item.id}'),
                        onTap: _action ? null : () => _open(item),
                        leading: Icon(
                          item.isRead
                              ? Icons.notifications_none
                              : Icons.notifications_active_outlined,
                          color: item.isRead
                              ? AppColors.textMuted
                              : AppColors.interactive,
                        ),
                        title: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.brand,
                            fontWeight: item.isRead
                                ? FontWeight.w400
                                : FontWeight.w600,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                messageDate(item.time),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: item.isRead
                            ? null
                            : const Icon(
                                Icons.circle,
                                color: AppColors.error,
                                size: 8,
                              ),
                      ),
                    ),
                  ),
                if (_more)
                  TextButton(
                    onPressed: _loadingMore ? null : () => _load(more: true),
                    child: Text(_loadingMore ? '加载中…' : '加载更多通知'),
                  ),
              ],
            ),
          ),
  );
}
