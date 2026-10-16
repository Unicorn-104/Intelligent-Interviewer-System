import 'package:flutter/material.dart';

import '../models/job.dart';
import '../core/network/api_client.dart';
import '../features/auth/domain/auth_session.dart';
import '../features/companies/presentation/company_screen.dart';
import '../features/jobs/data/job_favorite_api.dart';
import '../features/jobs/presentation/job_favorite_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/async_state_card.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({
    super.key,
    required this.job,
    required this.session,
    this.onApply,
    this.favoriteApi,
  });

  final Job job;
  final AuthSession session;
  final Future<bool> Function(Job job)? onApply;
  final JobFavoriteApi? favoriteApi;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool _applying = false;
  bool _applied = false;
  final _client = ApiClient();
  late final JobFavoriteController _favorite;

  Job get job => widget.job;

  @override
  void initState() {
    super.initState();
    _applied = job.applied;
    _favorite = JobFavoriteController(
      widget.favoriteApi ?? JobFavoriteApi(_client),
      widget.session.token,
      job.positionId,
    )..load();
  }

  @override
  void dispose() {
    _favorite.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _favorite,
    builder: (context, _) => _buildPage(context),
  );

  Widget _buildPage(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('职位详情'),
        actions: [
          IconButton(
            tooltip: !_favorite.loaded
                ? '重试加载收藏状态'
                : _favorite.favorited
                ? '取消收藏职位'
                : '收藏职位',
            isSelected: _favorite.loaded && _favorite.favorited,
            onPressed: _favorite.loading || _favorite.saving
                ? null
                : !_favorite.loaded
                ? _favorite.load
                : _toggleFavorite,
            selectedIcon: const Icon(
              Icons.bookmark,
              color: AppColors.interactive,
            ),
            icon: _favorite.loading || _favorite.saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bookmark_border),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          if (_favorite.error case final error?)
            AsyncStateCard(
              title: '收藏状态加载失败',
              message: error,
              onRetry: _favorite.load,
            ),
          if (!job.available)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                '该职位暂不可投递',
                style: TextStyle(color: AppColors.bodySoft),
              ),
            ),
          Text(job.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            job.salary,
            style: const TextStyle(
              color: AppColors.orange,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text('${job.city} · ${job.experience} · ${job.educationLabel}'),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.interactive),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 匹配度 ${job.matchLabel}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.interactive,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job.matchAvailable
                            ? '简历与岗位要求契合度较高，建议投递。AI 结果仅供参考。'
                            : '暂未提供匹配评估，请结合岗位要求判断是否投递。',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text('职位描述', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            job.description?.isNotEmpty == true
                ? job.description!
                : '岗位职责和详细说明由招聘企业持续完善，请以招聘方最新信息为准。',
          ),
          const SizedBox(height: 24),
          Text('任职要求', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            job.tags.isEmpty
                ? '具体任职要求请与招聘方进一步确认。'
                : job.tags.map((tag) => '• 熟悉或掌握 $tag').join('\n'),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              onTap: job.companyId != null && job.companyId! > 0
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CompanyScreen(
                          session: widget.session,
                          companyId: job.companyId!,
                        ),
                      ),
                    )
                  : null,
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: job.accent,
                child: Text(
                  job.company.isEmpty ? '企' : job.company.substring(0, 1),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(job.company),
              subtitle: Text(job.companyVerified ? '认证企业' : '企业信息待认证'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: FilledButton(
          onPressed:
              _applied || _applying || !job.available || widget.onApply == null
              ? null
              : _apply,
          child: _applying
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _applied
                      ? '已投递'
                      : !job.available
                      ? '暂不可投递'
                      : '立即投递',
                ),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    final message = await _favorite.toggle();
    if (mounted && message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    final success = await widget.onApply!(job);
    if (!mounted) return;
    setState(() {
      _applying = false;
      if (success) _applied = true;
    });
  }
}
