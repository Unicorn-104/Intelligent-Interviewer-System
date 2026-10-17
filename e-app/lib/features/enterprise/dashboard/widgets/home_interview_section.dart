import 'package:flutter/material.dart';

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
  });

  final HomeInterview interview;
  final VoidCallback onOpen;
  final VoidCallback? onViewJob;
  final VoidCallback? onViewCandidate;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) => HomeInterviewPreview(
    interview: interview,
    onOpen: onOpen,
    now: now,
    onViewJob: onViewJob,
    onViewCandidate: onViewCandidate,
  );
}
