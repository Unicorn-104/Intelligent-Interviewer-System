import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../models/chat_context.dart';

/// Outside the message list: scrolling history never hides the application context.
class ChatJobCard extends StatelessWidget {
  const ChatJobCard({
    super.key,
    required this.loading,
    this.job,
    this.error,
    this.jobCount = 0,
    this.compact = false,
    required this.onRetry,
    required this.onSelect,
    required this.onOpen,
  });
  final bool loading, compact;
  final ChatJob? job;
  final String? error;
  final int jobCount;
  final VoidCallback onRetry, onSelect, onOpen;

  @override
  Widget build(BuildContext context) {
    final current = job;
    final headline = loading
        ? '正在读取应聘岗位…'
        : error != null
        ? '岗位资料暂不可用'
        : current?.title ?? (jobCount > 1 ? '应聘多个岗位，请选择' : '暂无关联应聘岗位');
    final subtitle = error != null
        ? '点击重试，不影响继续聊天'
        : current != null
        ? current.requirements
        : jobCount > 1
        ? '选择岗位后查看对应的招聘要求'
        : loading
        ? ''
        : '未找到当前企业的应聘记录，点击重新读取';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Material(
        color: AppColors.canvas,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('chat-job-card'),
          onTap: loading
              ? null
              : error != null
              ? onRetry
              : current != null
              ? onOpen
              : jobCount > 1
              ? onSelect
              : onRetry,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!compact)
                  Row(
                    children: [
                      const Icon(
                        Icons.work_outline,
                        size: 15,
                        color: AppColors.interactive,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          '应聘岗位',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (jobCount > 1 && !loading && error == null)
                        TextButton(
                          key: const Key('chat-select-job'),
                          onPressed: onSelect,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text('切换 ($jobCount)'),
                        ),
                    ],
                  ),
                if (!compact) const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        headline,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (compact && jobCount > 1)
                      IconButton(
                        key: const Key('chat-select-job'),
                        tooltip: '切换应聘岗位',
                        onPressed: loading || error != null ? null : onSelect,
                        icon: const Icon(
                          Icons.unfold_more,
                          color: AppColors.interactive,
                        ),
                      ),
                    if (current != null || jobCount > 1 || error != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        error == null ? Icons.chevron_right : Icons.refresh,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ],
                ),
                if (current != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    compact && current.requirements.isNotEmpty
                        ? '${current.salary} · ${current.requirements}'
                        : current.salary,
                    maxLines: compact ? 1 : null,
                    overflow: compact ? TextOverflow.ellipsis : null,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.interactive,
                    ),
                  ),
                ],
                if (subtitle.isNotEmpty && !compact) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
