import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/job.dart';
import '../../../screens/job_detail_screen.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/async_state_card.dart';
import '../../auth/domain/auth_session.dart';
import '../data/job_api.dart';
import '../data/job_favorite_api.dart';
import 'job_favorites_controller.dart';

class JobFavoritesScreen extends StatefulWidget {
  const JobFavoritesScreen({
    super.key,
    required this.session,
    this.showAppBar = true,
    this.api,
  });
  final AuthSession session;
  final bool showAppBar;
  final JobFavoriteApi? api;

  @override
  State<JobFavoritesScreen> createState() => _JobFavoritesScreenState();
}

class _JobFavoritesScreenState extends State<JobFavoritesScreen> {
  final _client = ApiClient();
  late final JobFavoritesController _controller;

  @override
  void initState() {
    super.initState();
    _controller = JobFavoritesController(
      widget.api ?? JobFavoriteApi(_client),
      widget.session.token,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _open(Job job) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => JobDetailScreen(
          job: job,
          session: widget.session,
          onApply: _apply,
          favoriteApi: widget.api,
        ),
      ),
    );
    if (mounted) await _controller.load();
  }

  Future<bool> _apply(Job job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认投递'),
        content: Text('将默认简历投递给「${job.company}」的“${job.title}”岗位？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('暂不投递'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认投递'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return false;
    try {
      await JobApi(_client).apply(widget.session.token, job.positionId);
      if (mounted) _showMessage('投递成功');
      return true;
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
      return false;
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _remove(Job job) async {
    final message = await _controller.remove(job);
    if (mounted && message != null) _showMessage(message);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.showAppBar ? AppBar(title: const Text('收藏的职位')) : null,
    body: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => RefreshIndicator(
        onRefresh: _controller.load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_controller.loading) const LinearProgressIndicator(),
            if (_controller.loaded &&
                !_controller.loading &&
                _controller.error == null &&
                _controller.items.isEmpty)
              const AsyncStateCard(
                icon: Icons.bookmark_border,
                title: '还没有收藏职位',
                message: '点击职位详情右上角的书签，即可收藏心仪职位。',
              ),
            for (final job in _controller.items) ...[
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _controller.removingId == null
                      ? () => _open(job)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                job.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: '取消收藏 ${job.title}',
                              onPressed: _controller.removingId == null
                                  ? () => _remove(job)
                                  : null,
                              icon: _controller.removingId == job.positionId
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.bookmark,
                                      color: AppColors.interactive,
                                    ),
                            ),
                          ],
                        ),
                        Text(
                          job.salary,
                          style: const TextStyle(
                            color: AppColors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(job.company),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${job.city} · ${job.experience} · ${job.educationLabel}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (!job.available || job.applied) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            !job.available ? '暂不可投递' : '已投递',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_controller.error case final error?)
              AsyncStateCard(
                icon: Icons.wifi_off,
                title: '收藏加载失败',
                message: error,
                onRetry: () => _controller.load(more: _controller.failedMore),
              ),
            if (_controller.hasNext && _controller.error == null)
              OutlinedButton(
                onPressed: _controller.loading || _controller.removingId != null
                    ? null
                    : () => _controller.load(more: true),
                child: const Text('加载更多'),
              ),
          ],
        ),
      ),
    ),
  );
}
