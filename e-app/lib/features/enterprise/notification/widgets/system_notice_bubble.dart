import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../models/message_view_data.dart';
import 'chat_message_time.dart';
import 'system_message_icon.dart';
import 'system_notice_highlights.dart';

/// 系统消息流与单条详情共用通知气泡，不截断正文。
class SystemNoticeBubble extends StatelessWidget {
  const SystemNoticeBubble({
    super.key,
    required this.message,
    this.showTitle = true,
    this.onTap,
    this.onDetails,
    this.bodyKey,
    this.timeKey,
  });

  final SystemMessage message;
  final bool showTitle;
  final VoidCallback? onTap, onDetails;
  final Key? bodyKey, timeKey;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 4),
        child: SystemMessageIcon(size: 34),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              key: bodyKey,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                  bottomLeft: Radius.circular(3),
                ),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showTitle) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  message.title,
                                  style: const TextStyle(
                                    color: AppColors.brand,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (!message.isRead) ...[
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(top: 7),
                                  child: Semantics(
                                    label: '未读通知',
                                    child: const Icon(
                                      Icons.circle,
                                      color: AppColors.error,
                                      size: 7,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 5),
                        ],
                        if (onTap == null)
                          SelectableText.rich(
                            TextSpan(
                              children: systemNoticeSpans(message.content),
                            ),
                            style: const TextStyle(
                              color: AppColors.body,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          )
                        else
                          Text.rich(
                            TextSpan(
                              children: systemNoticeSpans(message.content),
                            ),
                            style: const TextStyle(
                              color: AppColors.body,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        if (onDetails != null) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              key: ValueKey(
                                'system-notice-details-${message.id}',
                              ),
                              onPressed: onDetails,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.interactive,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 2,
                                ),
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                '› 查看详情',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (message.time != null) ...[
              const SizedBox(height: 4),
              Tooltip(
                message: fullChatTimestamp(message.time!),
                child: Text(
                  chatTimestamp(message.time!),
                  key: timeKey,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class SystemNoticeFooter extends StatelessWidget {
  const SystemNoticeFooter({super.key});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.canvas,
      border: Border(top: BorderSide(color: AppColors.hairline)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline,
              color: SystemMessageIcon.accent,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '系统通知无需回复',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
