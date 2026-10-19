import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../theme/app_theme.dart';
import '../../auth/domain/auth_session.dart';
import '../data/interview_api.dart';
import '../domain/interview_schedule.dart';
import 'interview_calendar.dart';
import 'interview_controller.dart';
import 'interview_detail_screen.dart';

class InterviewScreen extends StatefulWidget {
  const InterviewScreen({super.key, required this.session});
  final AuthSession session;

  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  late final ApiClient _client;
  late final InterviewController _controller;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _controller = InterviewController(
      InterviewApi(_client),
      widget.session.token,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _open(InterviewSchedule item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            InterviewDetailScreen(session: widget.session, appointment: item),
      ),
    );
    if (mounted) await _controller.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('面试日程')),
    body: RefreshIndicator(
      onRefresh: _controller.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [InterviewCalendar(controller: _controller, onOpen: _open)],
      ),
    ),
  );
}
