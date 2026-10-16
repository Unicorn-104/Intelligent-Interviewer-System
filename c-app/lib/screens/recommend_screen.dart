import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../features/auth/domain/auth_session.dart';
import '../features/jobs/data/job_api.dart';
import '../features/resume/domain/app_resume.dart';
import '../models/job.dart';
import '../theme/app_theme.dart';
import '../widgets/job_card.dart';
import 'search_screen.dart';

class RecommendJobsScreen extends StatefulWidget {
  const RecommendJobsScreen({
    super.key,
    required this.session,
    required this.resume,
  });

  final AuthSession session;
  final AppResume resume;

  @override
  State<RecommendJobsScreen> createState() => _RecommendJobsScreenState();
}

class _RecommendJobsScreenState extends State<RecommendJobsScreen> {
  late final ApiClient _client;
  late final JobApi _api;
  List<Job> _jobs = [];
  bool _loading = true;
  String? _error;
  int? _applyingId;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _api = JobApi(_client);
    _load();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.recommendJobs(
        widget.session.token,
        resumeId: widget.resume.resumeId!,
      );
      if (mounted) setState(() => _jobs = data);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _apply(Job job) async {
    if (_applyingId != null) return false;
    setState(() => _applyingId = job.positionId);
    try {
      await _api.apply(widget.session.token, job.positionId);
      if (mounted) {
        setState(() {
          _jobs = [
            for (final item in _jobs)
              item.positionId == job.positionId
                  ? item.copyWith(applied: true)
                  : item,
          ];
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('投递成功')));
      }
      return true;
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return false;
    } finally {
      if (mounted) setState(() => _applyingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 推荐岗位'),
        actions: [
          IconButton(
            tooltip: '筛选全部岗位',
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    SearchScreen(session: widget.session, openFilters: true),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              '基于简历「${widget.resume.resumeName}」的智能匹配',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (widget.resume.jobDirection.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '求职方向：${widget.resume.jobDirection}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _EmptyState(text: _error!, action: '重新推荐', onTap: _load)
            else if (_jobs.isEmpty)
              const _EmptyState(text: '暂无可推荐岗位，请完善简历信息后重试')
            else
              ..._jobs.map(
                (job) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      JobCard(
                        session: widget.session,
                        job: job,
                        onApply: _apply,
                        applying: _applyingId == job.positionId,
                      ),
                      if (job.reason != null) _ReasonCard(text: job.reason!),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReasonCard extends StatelessWidget {
  const _ReasonCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome,
            size: 14,
            color: AppColors.interactive,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '推荐理由：$text',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text, this.action, this.onTap});

  final String text;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            size: 42,
            color: AppColors.muted,
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (action != null)
            TextButton(onPressed: onTap, child: Text(action!)),
        ],
      ),
    );
  }
}
