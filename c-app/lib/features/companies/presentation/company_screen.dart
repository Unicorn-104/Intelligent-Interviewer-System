import '../../jobs/presentation/application_resume_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/domain/auth_session.dart';
import '../../jobs/data/job_api.dart';
import '../../profile/presentation/profile_avatar.dart';
import '../../../models/job.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/async_state_card.dart';
import '../../../widgets/job_card.dart';
import '../data/company_api.dart';
import '../domain/company.dart';
import 'company_controller.dart';

class CompanyScreen extends StatefulWidget {
  const CompanyScreen({
    super.key,
    required this.session,
    required this.companyId,
    this.api,
  });
  final AuthSession session;
  final int companyId;
  final CompanyApi? api;

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  late final ApiClient _client;
  late final CompanyController _controller;
  int? _applyingId;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _controller = CompanyController(
      widget.api ?? CompanyApi(_client),
      widget.session.token,
      widget.companyId,
    )..refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _toggleFollow() async {
    final message = await _controller.toggleFollow();
    if (mounted && message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<bool> _apply(Job job) async {
    if (_applyingId != null) return false;
    final resumeId = await chooseApplicationResume(
      context,
      token: widget.session.token,
      job: job,
    );
    if (!mounted || resumeId == null) return false;
    setState(() => _applyingId = job.positionId);
    try {
      await JobApi(
        _client,
      ).apply(widget.session.token, job.positionId, resumeId: resumeId);
      if (!mounted) return false;
      _controller.markApplied(job.positionId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投递成功')));
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final company = _controller.company;
      return Scaffold(
        appBar: AppBar(title: const Text('企业主页')),
        body: RefreshIndicator(
          onRefresh: _controller.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              if (_controller.loading) const LinearProgressIndicator(),
              if (_controller.error case final error?)
                AsyncStateCard(
                  icon: Icons.business_outlined,
                  title: '企业信息加载失败',
                  message: error,
                  onRetry: _controller.refresh,
                ),
              if (company != null) ...[
                _CompanyHeader(company: company),
                const SizedBox(height: AppSpacing.xxl),
                _InfoCard(title: '企业介绍', content: company.intro ?? '企业暂未填写介绍'),
                const SizedBox(height: AppSpacing.lg),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '企业信息',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _InfoRow(label: '所在城市', value: company.city),
                        _InfoRow(label: '所属行业', value: company.industry),
                        _InfoRow(label: '企业规模', value: company.size),
                        _InfoRow(label: '企业地址', value: company.address),
                        _InfoRow(label: '企业官网', value: company.website),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  '在招职位（${_controller.total}）',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                if (!_controller.loading &&
                    _controller.jobs.isEmpty &&
                    _controller.jobsError == null)
                  const AsyncStateCard(
                    icon: Icons.work_outline,
                    title: '暂时没有在招职位',
                    message: '收藏企业后，新岗位将在消息中提醒。',
                  ),
                for (final job in _controller.jobs) ...[
                  JobCard(
                    job: job,
                    session: widget.session,
                    onApply: _apply,
                    applying: _applyingId == job.positionId,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (_controller.jobsError case final error?)
                  AsyncStateCard(
                    icon: Icons.wifi_off,
                    title: '职位加载失败',
                    message: error,
                    onRetry: _controller.failedLoadMore
                        ? _controller.loadMore
                        : _controller.refresh,
                  ),
                if (_controller.hasNext && _controller.jobsError == null)
                  OutlinedButton(
                    onPressed: _controller.loading || _controller.loadingMore
                        ? null
                        : _controller.loadMore,
                    child: Text(_controller.loadingMore ? '正在加载…' : '加载更多职位'),
                  ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: company == null
            ? null
            : SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _controller.loading || _controller.saving
                            ? null
                            : _toggleFollow,
                        icon: Icon(
                          company.followed
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                        ),
                        label: Text(
                          _controller.saving
                              ? '正在更新…'
                              : company.followed
                              ? '已收藏'
                              : '收藏企业',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '收藏后，新岗位将在消息中提醒',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
      );
    },
  );
}

class _CompanyHeader extends StatelessWidget {
  const _CompanyHeader({required this.company});
  final Company company;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileAvatar(
            avatar: company.logoUrl,
            name: company.name,
            radius: 26,
            backgroundColor: AppColors.primarySoft,
            foregroundColor: AppColors.brand,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  company.verified ? '认证企业' : '企业暂未认证',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  [
                    company.industry,
                    company.size,
                    company.city,
                  ].whereType<String>().join(' · '),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.content});
  final String title, content;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          SelectableText(content),
        ],
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String? value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        SelectableText(value ?? '暂未提供'),
      ],
    ),
  );
}
