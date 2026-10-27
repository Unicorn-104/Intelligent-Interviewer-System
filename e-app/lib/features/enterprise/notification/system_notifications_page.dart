import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/skeleton_list.dart';
import 'data/message_data_source.dart';
import 'models/message_view_data.dart';
import 'system_message_detail_page.dart';
import 'system_notice_destination.dart';
import 'widgets/system_notice_bubble.dart';
import '../schedule/data/reschedule_review_data_source.dart';
import '../schedule/reschedule_review_page.dart';

class SystemNotificationsPage extends StatefulWidget {
  const SystemNotificationsPage({super.key, required this.source});
  final MessageDataSource source;
  @override
  State<SystemNotificationsPage> createState() =>
      _SystemNotificationsPageState();
}

class _SystemNotificationsPageState extends State<SystemNotificationsPage>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _active = true, _fetching = false;
  List<SystemMessage> _items = [];
  bool _loading = true, _more = false, _loadingMore = false, _action = false;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_active && !_action && ModalRoute.of(context)?.isCurrent == true) {
        _load(silent: true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active && !_action) _load(silent: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load({bool more = false, bool silent = false}) async {
    if (_fetching || _loadingMore || (more && (!_more || _loading))) return;
    _fetching = true;
    final request = ++_request;
    setState(() {
      if (more) {
        _loadingMore = true;
      } else if (!silent) {
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
      _fetching = false;
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
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SystemMessageDetailPage(message: item.read),
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

  Future<void> _openRelated(SystemMessage item) async {
    if (_action) return;
    if (item.rescheduleRequestId != null) {
      await _open(item);
      return;
    }
    final target = item.raw['targetUrl']?.toString() ?? '';
    if (!target.startsWith('/enterprise/system-events/')) {
      await _open(item);
      return;
    }
    setState(() => _action = true);
    try {
      final destination = SystemNoticeDestination(
        await widget.source.loadNotificationDestination(item.id),
      );
      if (destination.id('messageId') != item.id) {
        throw const FormatException('通知详情不匹配');
      }
      if (!mounted) return;
      if (!item.isRead) await widget.source.readNotification(item.id);
      if (!mounted) return;
      setState(
        () => _items = _items
            .map((row) => row.id == item.id ? row.read : row)
            .toList(),
      );
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => destination.page(widget.source)),
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
    backgroundColor: AppColors.background,
    appBar: AppBar(
      leading: const BackButton(),
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      toolbarHeight: 64,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '系统消息',
            style: TextStyle(
              color: AppColors.brand,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2),
          Text(
            '系统通知',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: const SystemNoticeFooter(),
    body: _loading
        ? const SkeletonList(rows: 4)
        : RefreshIndicator(
            onRefresh: () => _load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                        Text('暂无系统消息'),
                        SizedBox(height: 8),
                        Text(
                          '面试状态、简历投递和报告通知将在这里显示',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                for (final item in _items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: SystemNoticeBubble(
                      key: ValueKey('system-message-${item.id}'),
                      bodyKey: ValueKey('system-notice-body-${item.id}'),
                      timeKey: ValueKey('system-notice-time-${item.id}'),
                      message: item,
                      onTap: _action ? null : () => _open(item),
                      onDetails: _action ? null : () => _openRelated(item),
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
