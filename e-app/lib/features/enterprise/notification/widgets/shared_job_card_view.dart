import 'package:flutter/material.dart';

import '../models/shared_job_card.dart';

class SharedJobCardView extends StatelessWidget {
  const SharedJobCardView({
    super.key,
    required this.card,
    this.onTap,
    this.candidate = false,
  });
  final SharedJobCard card;
  final VoidCallback? onTap;
  final bool candidate;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              card.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF172B4D),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              card.salary,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2B7FFF),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              [
                card.text('city', '城市不限'),
                card.text('experience', '经验不限'),
                card.education,
              ].join(' · '),
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7A90)),
            ),
            const SizedBox(height: 5),
            Text(
              card.text('company', '企业信息待完善'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7A90)),
            ),
            const Divider(height: 18),
            Text(
              candidate ? '查看岗位 · 前往投递' : '已分享岗位 · 求职者可查看并投递',
              style: const TextStyle(fontSize: 12, color: Color(0xFF179E89)),
            ),
          ],
        ),
      ),
    ),
  );
}
