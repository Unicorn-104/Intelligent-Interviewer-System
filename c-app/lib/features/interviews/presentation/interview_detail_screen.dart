import 'package:flutter/material.dart';

import '../../../core/formatters/backend_date.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/async_state_card.dart';
import '../../auth/domain/auth_session.dart';
import '../data/interview_api.dart';
import '../domain/interview_schedule.dart';

class InterviewDetailScreen extends StatefulWidget {
  const InterviewDetailScreen({
    super.key,
    required this.session,
    required this.appointment,
    this.api,
  });
  final AuthSession session;
  final InterviewSchedule appointment;
  final InterviewApi? api;

  @override
  State<InterviewDetailScreen> createState() => _InterviewDetailScreenState();
}

class _InterviewDetailScreenState extends State<InterviewDetailScreen> {
  ApiClient? _ownedClient;
  late final InterviewApi _api;
  late Future<InterviewDetail?> _future;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? InterviewApi(_ownedClient = ApiClient());
    _future = _load();
  }

  Future<InterviewDetail?> _load() async {
    final id = widget.appointment.sessionId;
    return id == null ? null : _api.detail(widget.session.token, id);
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      /* FutureBuilder displays the error. */
    }
  }

  @override
  void dispose() {
    _ownedClient?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('面试详情')),
    body: FutureBuilder<InterviewDetail?>(
      future: _future,
      builder: (context, snapshot) {
        final appointment = widget.appointment;
        final detail = snapshot.data;
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail?.positionTitle ?? appointment.positionTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(detail?.companyName ?? appointment.companyName),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '开始时间：${displayBackendDate(detail?.appointmentStartAt ?? appointment.startAt)}',
                      ),
                      Text(
                        '结束时间：${displayBackendDate(detail?.appointmentEndAt ?? appointment.endAt)}',
                      ),
                      Text('日程状态：${appointment.statusText}'),
                      Text(
                        '面试模式：${interviewModeLabel(detail?.mode ?? appointment.mode)}',
                      ),
                      if (detail?.roundNo != null ||
                          detail?.totalRounds != null)
                        Text(
                          '第 ${detail?.roundNo ?? 1} 轮 / 共 ${detail?.totalRounds ?? 1} 轮',
                        ),
                      if (detail?.interviewerName?.isNotEmpty == true)
                        Text('面试官：${detail!.interviewerName}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.hasError)
                AsyncStateCard(
                  title: '面试详情加载失败',
                  message: snapshot.error is ApiException
                      ? (snapshot.error as ApiException).message
                      : '暂时无法读取详情，请重试',
                  onRetry: _reload,
                )
              else if (appointment.sessionId == null)
                const AsyncStateCard(
                  title: '面试场次待确认',
                  message: '目前可查看预约时间，场次详情待企业确认。',
                ),
            ],
          ),
        );
      },
    ),
  );
}
