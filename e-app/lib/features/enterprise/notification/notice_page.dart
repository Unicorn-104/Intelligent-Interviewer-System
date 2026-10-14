import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import 'mock_notification.dart';

/// 模块六：反馈与通知 - 公告页（P5）。
///
/// 依据接口盘点：复用 /system/notice/* 接口占位（listTop 置顶公告 +
/// 列表 + 已读/未读 + 全部已读）。
/// 数据来源：本地 Mock 数据（mock_notification.dart 的 mockNotices），
/// TODO: P7阶段替换为真实接口（lib/api/message_api.dart 的
/// listTopNotices / markNoticeRead）。
class NoticePage extends StatefulWidget {
  const NoticePage({super.key});

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage> {
  List<Map<String, dynamic>>? _notices;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 模拟加载公告（置顶 + 普通）。
  /// TODO: P7阶段替换为真实接口（message_api.listTopNotices 等）。
  Future<void> _load() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _notices = List.of(mockNotices);
      _loading = false;
    });
  }

  int get _unreadCount =>
      (_notices ?? const []).where((n) => n['read'] == false).length;

  /// 模拟标记已读。
  /// TODO: P7阶段替换为真实接口（message_api.markNoticeRead）。
  void _markRead(Map<String, dynamic> notice) {
    setState(() => notice['read'] = true);
  }

  /// 模拟全部已读。
  Future<void> _markAllRead() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      for (final notice in _notices ?? const <Map<String, dynamic>>[]) {
        notice['read'] = true;
      }
    });
    messenger.showSnackBar(const SnackBar(content: Text('全部公告已标记为已读（模拟）')));
  }

  @override
  Widget build(BuildContext context) {
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('公告'),
          actions: [
            if (_unreadCount > 0)
              TextButton.icon(
                onPressed: _markAllRead,
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('全部已读'),
              ),
          ],
        ),
        body: _loading
            ? const SkeletonList(rows: 4)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    if (_notices?.any((n) => n['pinned'] == true) ?? false) ...[
                      const SectionTitle('置顶公告'),
                      for (final notice
                          in (_notices ?? const <Map<String, dynamic>>[]).where(
                            (n) => n['pinned'] == true,
                          ))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _NoticeCard(
                            notice: notice,
                            onTap: () => _markRead(notice),
                          ),
                        ),
                      const SizedBox(height: 6),
                    ],
                    const SectionTitle('全部公告'),
                    for (final notice
                        in (_notices ?? const <Map<String, dynamic>>[]).where(
                          (n) => n['pinned'] != true,
                        ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _NoticeCard(
                          notice: notice,
                          onTap: () => _markRead(notice),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, required this.onTap});

  final Map<String, dynamic> notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final read = notice['read'] == true;
    final pinned = notice['pinned'] == true;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!read)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6, right: 10),
                  decoration: const BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (pinned) ...[
                          Icon(
                            Icons.push_pin,
                            size: 14,
                            color: AppColors.orange,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            '${notice['title']}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: read
                                      ? FontWeight.w500
                                      : FontWeight.w600,
                                  color: read
                                      ? AppColors.bodySoft
                                      : AppColors.body,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${notice['content']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${notice['publishTime']}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
