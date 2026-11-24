import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../features/auth/domain/auth_session.dart';
import '../features/companies/presentation/company_screen.dart';
import '../features/interviews/presentation/interview_screen.dart';
import '../features/messages/data/message_api.dart';
import '../features/messages/domain/app_message.dart';
import '../features/messages/presentation/shared_job_detail_screen.dart';
import '../theme/app_theme.dart';

class MessageDetailScreen extends StatefulWidget {
  const MessageDetailScreen({
    super.key,
    required this.message,
    required this.session,
    this.messageApi,
  });
  final AppMessage message;
  final AuthSession session;
  final MessageApi? messageApi;
  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  ApiClient? _client;
  late final MessageApi _api;
  List<AppMessage> _items = [];
  bool _loading = false, _hasMore = false;
  String? _error;
  final Set<int> _pendingReads = {};
  bool get _company => widget.message.category == AppMessageCategory.company;

  @override
  void initState() {
    super.initState();
    _api = widget.messageApi ?? MessageApi(_client = ApiClient());
    _load();
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _api.fetchEvents(
        widget.session.token,
        widget.message,
        beforeId: more && _items.isNotEmpty ? _items.last.sourceId : null,
      );
      if (!mounted) return;
      final known = more
          ? _items.map((item) => item.sourceId).toSet()
          : <int>{};
      setState(() {
        _items = [
          if (more) ..._items,
          ...page.items.where((item) => known.add(item.sourceId)),
        ];
        _hasMore = page.hasMore;
      });
      // 完整加载后才确认已读，失败时保留记录并允许重试。
      _pendingReads.addAll(
        page.items
            .where((item) => item.unreadCount > 0)
            .map((item) => item.sourceId),
      );
      while (_pendingReads.isNotEmpty && mounted) {
        final ids = _pendingReads.take(100).toList();
        await _api.markEventsRead(widget.session.token, widget.message, ids);
        _pendingReads.removeAll(ids);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.message.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (_company && widget.message.threadId != null)
          IconButton(
            tooltip: '企业主页',
            icon: const Icon(Icons.business_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CompanyScreen(
                  session: widget.session,
                  companyId: widget.message.threadId!,
                ),
              ),
            ),
          ),
      ],
    ),
    body: Column(
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Text(_error!, style: Theme.of(context).textTheme.bodySmall),
                TextButton(
                  onPressed: _loading ? null : () => _load(),
                  child: const Text('重新加载'),
                ),
              ],
            ),
          ),
        Expanded(
          child: _loading && _items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
              ? Center(child: Text(_company ? '暂无企业动态，发布新岗位后会显示在这里' : '暂无通知记录'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    itemCount: _items.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) => _hasMore && index == 0
                        ? TextButton(
                            onPressed: _loading
                                ? null
                                : () => _load(more: true),
                            child: Text(_loading ? '正在加载…' : '加载更早记录'),
                          )
                        : _eventCard(
                            _items[_items.length -
                                1 -
                                index +
                                (_hasMore ? 1 : 0)],
                          ),
                  ),
                ),
        ),
      ],
    ),
  );

  Widget _eventCard(AppMessage item) {
    final uri = Uri.tryParse(item.targetUrl ?? '');
    final positionId =
        uri != null &&
            !uri.hasScheme &&
            !uri.hasAuthority &&
            uri.path == '/companies/${widget.message.threadId}'
        ? int.tryParse(uri.queryParameters['positionId'] ?? '')
        : null;
    return Container(
      key: ValueKey('event-${item.sourceId}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatTime(item.occurredAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(item.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(item.content, style: Theme.of(context).textTheme.bodyMedium),
          if (_company && positionId != null && positionId > 0)
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SharedJobDetailScreen(
                    session: widget.session,
                    positionId: positionId,
                  ),
                ),
              ),
              icon: const Icon(Icons.arrow_forward, size: 17),
              label: const Text('查看岗位'),
            ),
          if (widget.message.threadType == 'INTERVIEW')
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => InterviewScreen(session: widget.session),
                ),
              ),
              icon: const Icon(Icons.calendar_month_outlined, size: 17),
              label: const Text('查看面试日程'),
            ),
        ],
      ),
    );
  }
}

String _formatTime(DateTime date) =>
    '${date.year}年${date.month}月${date.day}日 '
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
