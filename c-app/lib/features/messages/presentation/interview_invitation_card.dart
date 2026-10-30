import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../domain/interview_invitation.dart';

class InterviewInvitationCard extends StatelessWidget {
  const InterviewInvitationCard({
    super.key,
    required this.invitation,
    required this.onTap,
  });
  final InterviewInvitation invitation;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '查看面试邀请',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.video_camera_front_outlined,
                    color: AppColors.interactive,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '面试邀请',
                    style: TextStyle(
                      color: AppColors.brand,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              invitation.title,
              style: const TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              invitation.description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.bodySoft,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Row(
              children: [
                Expanded(
                  child: Text(
                    '查看安排 · 进入面试',
                    style: TextStyle(
                      color: AppColors.interactive,
                      fontSize: 13,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.interactive,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
