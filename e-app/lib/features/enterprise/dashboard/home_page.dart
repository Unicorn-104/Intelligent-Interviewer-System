import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../jobs/job_detail_page.dart';
import '../talent/talent_detail_page.dart';
import '../talent/models/talent_detail_view_data.dart';
import 'home_data_source.dart';
import 'home_lists_page.dart';
import 'home_models.dart';
import 'widgets/home_applications_section.dart';
import 'widgets/home_carousel.dart';
import 'widgets/home_interview_calendar.dart';
import 'widgets/home_interview_preview.dart';
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
    this.onStartInterview,
  });
  final VoidCallback onNotifications;
  final VoidCallback onFeatures;
  final VoidCallback onInterviews;
  final VoidCallback onJobs;
  final Future<void> Function()? onOpenNotices;
  final HomeDataSource? dataSource;
  final Future<void> Function(HomeInterview interview)? onStartInterview;
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
  final _calendarInterviews = _HomeSectionState<List<HomeInterview>>();
  late DateTime _selectedInterviewDate;

  DateTime get _calendarToday {
    final now = _source.now.toUtc().add(const Duration(hours: 8));
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _loadCalendarInterviews() => _load(
    _calendarInterviews,
    () => _source.loadInterviewsOn(_selectedInterviewDate),
  );

  Future<void> _selectInterviewDate(DateTime day) async {
    setState(() => _selectedInterviewDate = day);
    await _loadCalendarInterviews();
  }

  @override
  void initState() {
    super.initState();
    _selectedInterviewDate = _calendarToday;
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
      _loadCalendarInterviews(),
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
    if (!interview.canStartAt(_source.now)) return;
    if (widget.onStartInterview == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('面试会议功能开发中，会议入口已预留')));
      return;
    }
    await widget.onStartInterview!(interview);
    if (mounted) {
      await Future.wait([
        _load(_interviews, _source.loadInterviews),
        _loadCalendarInterviews(),
        _load(_stats, _source.loadStats),
      ]);
    }
  }

  Future<void> _openInterviewCandidate(HomeInterview interview) async {
    final candidateId = interview.candidateId;
    if (candidateId == null) return;
    final positionId = interview.positionId;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TalentDetailPage(
          talent: {'talentId': candidateId, 'name': interview.candidate},
          jobContext: positionId == null
              ? null
              : TalentJobContext(
                  positionId: positionId,
                  title: interview.position,
                ),
        ),
      ),
    );
    if (mounted) {
      await Future.wait([
        _load(_interviews, _source.loadInterviews),
        _loadCalendarInterviews(),
      ]);
    }
  }

  Future<void> _openInterviewJob(HomeInterview interview) async {
    final positionId = interview.positionId;
    if (positionId == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => JobDetailPage(
          job: {'posId': positionId, 'title': interview.position},
          initialTab: 0,
        ),
      ),
    );
    if (mounted) {
      await Future.wait([
        _load(_interviews, _source.loadInterviews),
        _loadCalendarInterviews(),
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
    final local = _source.now.toUtc().add(const Duration(hours: 8));
    final from = DateTime.utc(
      local.year,
      local.month,
      local.day,
    ).subtract(const Duration(hours: 8));
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => HomeInterviewsPage(
          source: _source,
          from: from,
          onOpen: _openInterview,
          onViewJob: _openInterviewJob,
          onViewCandidate: _openInterviewCandidate,
          now: () => _source.now,
          onSchedule: widget.onInterviews,
        ),
      ),
    );
    if (mounted) {
      await Future.wait([
        _load(_interviews, _source.loadInterviews),
        _loadCalendarInterviews(),
      ]);
    }
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
    bool wrapInCard = true,
  }) => HomeSection(
    title: title,
    subtitle: subtitle,
    onMore: onMore,
    wrapInCard:
        wrapInCard ||
        state.loading ||
        state.error != null ||
        state.data == null ||
        isEmpty(state.data as T),
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
      if (index > 0) const Divider(height: 24),
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
    final greeting = switch (_source.now.hour) {
      < 12 => '早上好',
      < 18 => '下午好',
      _ => '晚上好',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(
          identity?.company ?? '首页',
          style: const TextStyle(
            color: AppColors.brand,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Badge(
                key: const ValueKey('home-notice-badge'),
                backgroundColor: AppColors.error,
                textColor: AppColors.canvas,
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
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.interactiveSoft,
                    foregroundColor: AppColors.interactive,
                  ),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting，${identity?.nickname ?? '招聘伙伴'}',
                        style: const TextStyle(
                          color: AppColors.brand,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '今天也让招聘有序推进',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
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
                const SizedBox(height: 24),
                HomeCarousel(
                  identity: identity,
                  stats: stats,
                  nextInterview: interviews?.firstOrNull,
                  interviewsLoaded: interviews != null,
                ),
                const SizedBox(height: 12),
                _section<HomeStats>(
                  title: '快捷统计',
                  state: _stats,
                  loader: _source.loadStats,
                  isEmpty: (data) => data.isEmpty,
                  empty: '暂无统计数据',
                  content: (data) => HomeStatsSection(stats: data),
                ),
                const SizedBox(height: 12),
                HomeSection(
                  title: '近期面试',
                  onMore: _moreInterviews,
                  child: HomeInterviewCalendar(
                    selectedDate: _selectedInterviewDate,
                    today: _calendarToday,
                    onDateSelected: _selectInterviewDate,
                    onRefresh: _loadCalendarInterviews,
                    count:
                        !_calendarInterviews.loading &&
                            _calendarInterviews.error == null
                        ? _calendarInterviews.data?.length
                        : null,
                    child: _calendarInterviews.loading
                        ? const HomeSkeleton()
                        : _calendarInterviews.error != null
                        ? HomeStatus(
                            message: '',
                            error: _calendarInterviews.error,
                            onRetry: _loadCalendarInterviews,
                          )
                        : _calendarInterviews.data == null ||
                              _calendarInterviews.data!.isEmpty
                        ? const HomeStatus(
                            message: '当日无面试，可切换日期查看安排',
                            icon: Icons.event_available_outlined,
                          )
                        : Column(
                            children: _rows(
                              _calendarInterviews.data!,
                              (item) => HomeInterviewPreview(
                                interview: item,
                                now: () => _source.now,
                                rescheduleSource:
                                    _source.candidateActionsSource,
                                onRescheduled: () async {
                                  await Future.wait<void>([
                                    _load(_interviews, _source.loadInterviews),
                                    _loadCalendarInterviews(),
                                    _load(_stats, _source.loadStats),
                                  ]);
                                },
                                onOpen: () => _openInterview(item),
                                onViewCandidate: item.candidateId == null
                                    ? null
                                    : () => _openInterviewCandidate(item),
                                onViewJob: item.positionId == null
                                    ? null
                                    : () => _openInterviewJob(item),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                _section<HomePageSlice<HomeApplication>>(
                  title: '岗位投递概览',
                  state: _applications,
                  loader: _source.loadApplications,
                  isEmpty: (data) => data.items.isEmpty,
                  empty: '暂无岗位投递数据',
                  onMore: widget.onJobs,
                  wrapInCard: false,
                  content: (data) => Column(
                    children: [
                      for (final (index, item)
                          in data.items.take(3).indexed) ...[
                        if (index > 0) const SizedBox(height: 12),
                        HomeApplicationRow(
                          application: item,
                          companyName: identity?.company,
                          onOpen: () => _openApplication(item),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
