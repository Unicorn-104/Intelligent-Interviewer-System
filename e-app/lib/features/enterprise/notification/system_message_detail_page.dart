import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import 'models/message_view_data.dart';
import 'widgets/system_notice_bubble.dart';

class SystemMessageDetailPage extends StatelessWidget {
  const SystemMessageDetailPage({super.key, required this.message});
  final SystemMessage message;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('system-message-detail-page'),
    backgroundColor: AppColors.background,
    appBar: AppBar(
      leading: const BackButton(),
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      toolbarHeight: 64,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.brand,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
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
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        SystemNoticeBubble(
          message: message,
          showTitle: false,
          bodyKey: const Key('system-notice-bubble'),
          timeKey: const Key('system-notice-time'),
        ),
      ],
    ),
    bottomNavigationBar: const SystemNoticeFooter(),
  );
}
