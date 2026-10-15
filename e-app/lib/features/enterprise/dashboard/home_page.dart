import 'dart:async';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../jobs/job_detail_page.dart';
import '../schedule/interview_appointment_detail_page.dart';
import 'home_data_source.dart';
import 'home_lists_page.dart';
import 'home_models.dart';
import 'widgets/home_applications_section.dart';
import 'widgets/home_carousel.dart';
import 'widgets/home_interview_section.dart';
import 'widgets/home_section.dart';
import 'widgets/home_stats_section.dart';
import 'widgets/home_status.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onNotifications,
    required this.onFeatures,
    required this.onInterviews,
    required this.onJobs,
    this.onOpenNotices,
    this.dataSource,
  });
  final VoidCallback onNotifications;
  final VoidCallback onFeatures;
  final VoidCallback onInterviews;
  final VoidCallback onJobs;
  final Future<void> Function()? onOpenNotices;
  final HomeDataSource? dataSource;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomeSectionState<T> {
  T? data;
  Object? error;
  bool loading = true;
  int request = 0;
}

class _HomePageState extends State<HomePage> {
  late final HomeDataSource _source = widget.dataSource ?? HomeDataSource();
  final _identity = _HomeSectionState<HomeIdentity>();
  final _unread = _HomeSectionState<int>();
  final _stats = _HomeSectionState<HomeStats>();
  final _interviews = _HomeSectionState<HomePageSlice<HomeInterview>>();
  final _applications = _HomeSectionState<HomePageSlice<HomeApplication>>();

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _load<T>(
    _HomeSectionState<T> section,
    Future<T> Function() loader,
  ) async {
    final request = ++section.request;
    setState(() {
      section.loading = true;
      section.error = null;
    });
    try {
      final result = await loader();
      if (mounted && request == section.request) {
        setState(() => section.data = result);
      }
    } catch (error) {
      if (mounted && request == section.request) {
        setState(() => section.error = error);
      }
    } finally {
      if (mounted && request == section.request) {
        setState(() => section.loading = false);
      }
    }
  }

  Future<void> _refresh() async {
    await Future.wait<void>([
      _load(_identity, _source.loadIdentity),
      _load(_unread, _source.loadUnread),
      _load(_stats, _source.loadStats),
      _load(_interviews, _source.loadInterviews),
      _load(_applications, _source.loadApplications),
    ]);
  }

  Future<void> _notices() async {
    if (widget.onOpenNotices != null) {
      await widget.onOpenNotices!();
    } else {
      widget.onNotifications();
    }
    if (mounted) await _load(_unread, _source.loadUnread);
  }

  Future<void> _openInterview(HomeInterview interview) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            InterviewAppointmentDetailPage(appointment: Map.of(interview.raw)),
      ),
    );
    if (mounted) {
      await Future.wait([
        _load(_interviews, _source.loadInterviews),
        _load(_stats, _source.loadStats),
      ]);
    }
  }

  Future<void> _openApplication(HomeApplication application) async {
    if (application.positionId == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => JobDetailPage(job: application.detail, initialTab: 1),
      ),
    );
    if (mounted) {
      await Future.wait([
        _load(_applications, _source.loadApplications),
        _load(_stats, _source.loadStats),
      ]);
    }
  }

  Future<void> _moreInterviews() async {
    final from = _source.now;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => HomeInterviewsPage(
          source: _source,
          from: from,
          onOpen: _openInterview,
          onSchedule: widget.onInterviews,
        ),
      ),
    );
    if (mounted) await _load(_interviews, _source.loadInterviews);
  }

  Future<void> _moreApplications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => HomeApplicationsPage(
          source: _source,
          onOpen: _openApplication,
          onJobs: widget.onJobs,
        ),
      ),
    );
    if (mounted) await _load(_applications, _source.loadApplications);
  }

  Widget _section<T>({
    required String title,
    String? subtitle,
    required _HomeSectionState<T> state,
    required Future<T> Function() loader,
    required bool Function(T) isEmpty,
    required String empty,
    required Widget Function(T) content,
    VoidCallback? onMore,
  }) => HomeSection(
    title: title,
    subtitle: subtitle,
    onMore: onMore,
    child: state.loading
        ? const HomeSkeleton()
        : state.error != null
        ? HomeStatus(
            message: '',
            error: state.error,
            onRetry: () => _load(state, loader),
          )
        : state.data == null || isEmpty(state.data as T)
        ? HomeStatus(message: empty)
        : content(state.data as T),
  );

  List<Widget> _rows<T>(Iterable<T> items, Widget Function(T) row) => [
    for (final (index, item) in items.indexed) ...[
      if (index > 0) const Divider(height: 32),
      row(item),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final interviews = _interviews.error == null && !_interviews.loading
        ? _interviews.data?.items
        : null;
    final identity = _identity.error == null && !_identity.loading
        ? _identity.data
        : null;
    final stats = _stats.error == null && !_stats.loading ? _stats.data : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          identity?.company ?? '首页',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Badge(
                key: const ValueKey('home-notice-badge'),
                isLabelVisible:
                    !_unread.loading &&
                    _unread.error == null &&
                    (_unread.data ?? 0) > 0,
                label: Text(
                  (_unread.data ?? 0) > 99 ? '99+' : '${_unread.data ?? 0}',
                ),
                child: IconButton(
                  tooltip: '通知与公告',
                  onPressed: _notices,
                  icon: Icon(
                    _unread.error == null
                        ? Icons.notifications_none
                        : Icons.notifications_paused_outlined,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: '更多功能',
            onPressed: widget.onFeatures,
            icon: const Icon(Icons.apps_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            key: const PageStorageKey('enterprise-home-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_identity.loading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LinearProgressIndicator(),
                  )
                else if (_identity.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: HomeStatus(
                      message: '',
                      error: _identity.error,
                      onRetry: () => _load(_identity, _source.loadIdentity),
                    ),
                  )
                else
                  Text(
                    '今天也让招聘有序推进',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                if (_unread.loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '正在读取公告未读数…',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                else if (_unread.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: HomeStatus(
                      message: '',
                      error: _unread.error,
                      onRetry: () => _load(_unread, _source.loadUnread),
                    ),
                  ),
                const SizedBox(height: 20),
                HomeCarousel(
                  identity: identity,
                  stats: stats,
                  nextInterview: interviews?.firstOrNull,
                  interviewsLoaded: interviews != null,
                ),
                const SizedBox(height: 8),
                _section<HomePageSlice<HomeInterview>>(
                  title: '近期面试',
                  subtitle: '更多信息正在接入',
                  state: _interviews,
                  loader: _source.loadInterviews,
                  isEmpty: (data) => data.items.isEmpty,
                  empty: '暂无即将进行的面试',
                  onMore: _moreInterviews,
                  content: (data) => Column(
                    children: _rows(
                      data.items.take(3),
                      (item) => HomeInterviewRow(
                        interview: item,
                        onOpen: () => _openInterview(item),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _section<HomePageSlice<HomeApplication>>(
                  title: '岗位投递概览',
                  subtitle: '累计投递 · 按岗位发布时间排序',
                  state: _applications,
                  loader: _source.loadApplications,
                  isEmpty: (data) => data.items.isEmpty,
                  empty: '暂无岗位投递数据',
                  onMore: _moreApplications,
                  content: (data) => Column(
                    children: _rows(
                      data.items.take(3),
                      (item) => HomeApplicationRow(
                        application: item,
                        onOpen: () => _openApplication(item),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _section<HomeStats>(
                  title: '快捷统计',
                  subtitle: '未提供的统计显示 —',
                  state: _stats,
                  loader: _source.loadStats,
                  isEmpty: (data) => data.isEmpty,
                  empty: '暂无统计数据',
                  content: (data) => HomeStatsSection(stats: data),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
