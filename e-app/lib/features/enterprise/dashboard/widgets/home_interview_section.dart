import 'package:flutter/material.dart';

import '../../talent/data/talent_detail_data_source.dart';
import '../home_models.dart';
import 'home_interview_preview.dart';

class HomeInterviewRow extends StatelessWidget {
  const HomeInterviewRow({
    super.key,
    required this.interview,
    required this.onOpen,
    this.now,
    this.onViewJob,
    this.onViewCandidate,
    this.rescheduleSource,
    this.onRescheduled,
  });

  final HomeInterview interview;
  final VoidCallback onOpen;
  final VoidCallback? onViewJob;
  final VoidCallback? onViewCandidate;
  final DateTime Function()? now;
  final TalentDetailDataSource? rescheduleSource;
  final Future<void> Function()? onRescheduled;

  @override
  Widget build(BuildContext context) => HomeInterviewPreview(
    interview: interview,
    onOpen: onOpen,
    now: now,
    rescheduleSource: rescheduleSource,
    onRescheduled: onRescheduled,
    onViewJob: onViewJob,
    onViewCandidate: onViewCandidate,
  );
}
