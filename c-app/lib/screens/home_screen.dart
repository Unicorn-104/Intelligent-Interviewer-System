import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../features/auth/domain/auth_session.dart';
import '../features/jobs/data/job_api.dart';
import '../features/applications/presentation/application_screen.dart';
import '../features/applications/presentation/application_detail_screen.dart';
import '../features/interviews/data/interview_api.dart';
import '../features/interviews/domain/interview_schedule.dart';
import '../features/interviews/presentation/interview_calendar.dart';
import '../features/interviews/presentation/interview_controller.dart';
import '../features/interviews/presentation/interview_detail_screen.dart';
import '../models/job.dart';
import '../theme/app_theme.dart';
import '../widgets/job_card.dart';
import '../widgets/section_header.dart';
import '../widgets/async_state_card.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.onOpenMessages,
    this.unreadCount = 0,
  });

  final AuthSession session;
  final VoidCallback onOpenMessages;
  final int unreadCount;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiClient _client;
  late final JobApi _api;
  late final InterviewController _interviews;
  final _recommendationKey = GlobalKey();
  HomeFeed? _feed;
  String? _error;
  String? _filter;
  int? _applyingPositionId;

  static const _filters = <(String, String?)>[
    ('推荐', null),
    ('最新发布', 'latest'),
    ('高薪急招', 'urgent'),
    ('NLP', 'nlp'),
    ('大型企业', 'large'),
  ];

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _api = JobApi(_client);
    _interviews = InterviewController(
      InterviewApi(_client),
      widget.session.token,
    )..load();
    _load();
  }

  @override
  void dispose() {
    _interviews.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _load({String? filter, bool updateFilter = false}) async {
    if (updateFilter) {
      setState(() {
        _filter = filter;
        _error = null;
        _feed = null;
      });
    } else {
      setState(() => _error = null);
    }
    try {
      final feed = await _api.fetchHome(
        widget.session.token,
        filter: filter ?? _filter,
      );
      if (mounted) setState(() => _feed = feed);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  void _openSearch({String? keyword, bool openFilters = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchScreen(
          session: widget.session,
          initialKeyword: keyword,
          openFilters: openFilters,
        ),
      ),
    );
  }

  Future<void> _refreshAll() async {
    await Future.wait([_load(), _interviews.load()]);
  }

  Future<void> _openApplications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ApplicationScreen(session: widget.session),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openApplication(int id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ApplicationDetailScreen(session: widget.session, applicationId: id),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openInterview(InterviewSchedule item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            InterviewDetailScreen(session: widget.session, appointment: item),
      ),
    );
    if (mounted) await _interviews.load();
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
    if (confirmed != true || !mounted) return false;

    setState(() => _applyingPositionId = job.positionId);
    try {
      await _api.apply(widget.session.token, job.positionId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('投递成功，可在首页查看最新进度')));
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
      if (mounted) setState(() => _applyingPositionId = null);
    }
  }

  void _scrollToRecommendations() {
    final targetContext = _recommendationKey.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            sliver: SliverList.list(
              children: [
                _Header(
                  name: widget.session.nickName,
                  onOpenMessages: widget.onOpenMessages,
                  unreadCount: widget.unreadCount,
                ),
                const SizedBox(height: 20),
                _SearchEntry(onTap: _openSearch),
                const SizedBox(height: 16),
                _AiHero(
                  opportunityCount: _feed?.newOpportunityCount,
                  highMatchCount: _feed?.highMatchCount,
                  onView: _scrollToRecommendations,
                ),
                const SizedBox(height: 24),
                SectionHeader(
                  key: _recommendationKey,
                  title: 'AI 为你推荐',
                  subtitle: '基于简历、求职意向与岗位匹配结果',
                  action: '筛选全部岗位',
                  onAction: () => _openSearch(openFilters: true),
                ),
                const SizedBox(height: 12),
                _FilterBar(
                  selected: _filter,
                  filters: _filters,
                  onSelected: (value) =>
                      _load(filter: value, updateFilter: true),
                ),
                const SizedBox(height: 12),
                ..._buildRecommendationContent(),
                ...[
                  const SizedBox(height: 16),
                  SectionHeader(
                    title: '我的投递',
                    subtitle: '查看岗位投递与企业处理进度',
                    action: '查看全部',
                    onAction: _openApplications,
                  ),
                  const SizedBox(height: 12),
                  for (final application
                      in _feed?.applications ?? <ApplicationSummary>[]) ...[
                    InkWell(
                      onTap: () => _openApplication(application.applicationId),
                      child: _ApplicationCard(application: application),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                const SizedBox(height: AppSpacing.xxl),
                InterviewCalendar(
                  controller: _interviews,
                  onOpen: _openInterview,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRecommendationContent() {
    if (_error != null) {
      return [
        AsyncStateCard(
          icon: Icons.wifi_off_rounded,
          title: '首页加载失败',
          message: _error!,
          onRetry: _load,
        ),
      ];
    }
    if (_feed == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 34),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_feed!.jobs.isEmpty) {
      return [
        AsyncStateCard(
          icon: Icons.work_outline_rounded,
          title: '暂时没有匹配岗位',
          message: '完善简历和求职意向后，AI 会为你推荐更合适的机会。',
          actionLabel: '搜索更多岗位',
          onRetry: _openSearch,
        ),
      ];
    }
    return [
      for (final job in _feed!.jobs) ...[
        JobCard(
          job: job,
          session: widget.session,
          onApply: _apply,
          applying: _applyingPositionId == job.positionId,
        ),
        const SizedBox(height: 12),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.onOpenMessages,
    this.unreadCount = 0,
  });

  final String name;
  final VoidCallback onOpenMessages;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 11
        ? '早上好'
        : (hour < 14 ? '中午好' : (hour < 18 ? '下午好' : '晚上好'));
    final displayName = name.trim().isEmpty ? '求职者' : name.trim();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting，$displayName',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '今天也离理想工作更近一步',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: '消息',
          onPressed: onOpenMessages,
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            smallSize: 7,
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
      ],
    );
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.search, color: AppColors.ink),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  '搜索职位 / 企业 / 技能',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
              Icon(Icons.tune, color: AppColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiHero extends StatelessWidget {
  const _AiHero({
    required this.opportunityCount,
    required this.highMatchCount,
    required this.onView,
  });
  final int? opportunityCount;
  final int? highMatchCount;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.ink, AppColors.brandDeep],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: Color(0xFF3B89FF)),
              SizedBox(width: 8),
              Text(
                'AI 求职助手',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            opportunityCount == null
                ? '正在寻找适合你的\n新机会'
                : '已为你匹配 $opportunityCount 个\n新机会',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            highMatchCount == null
                ? 'AI 正在根据你的简历和求职意向进行匹配。'
                : '其中 $highMatchCount 个岗位匹配度超过 90%，AI 结果仅供求职参考。',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onView,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
            ),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('查看推荐'),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.filters,
    required this.onSelected,
  });
  final String? selected;
  final List<(String, String?)> filters;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in filters) ...[
            FilterChip(
              label: Text(item.$1),
              selected: selected == item.$2,
              onSelected: (_) => onSelected(item.$2),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application});
  final ApplicationSummary application;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: CircularProgressIndicator(
                value: application.progress,
                strokeWidth: 5,
                backgroundColor: AppColors.primarySoft,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    application.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    application.company,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              application.statusLabel,
              style: const TextStyle(
                color: AppColors.interactive,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
