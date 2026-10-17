import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import 'home_data_source.dart';
import 'home_models.dart';
import 'widgets/home_applications_section.dart';
import 'widgets/home_interview_section.dart';
import 'widgets/home_section.dart';
import 'widgets/home_status.dart';

class HomeInterviewsPage extends StatelessWidget {
  const HomeInterviewsPage({
    super.key,
    required this.source,
    required this.from,
    required this.onOpen,
    this.onSchedule,
    this.onViewJob,
    this.now,
  });
  final HomeDataSource source;
  final DateTime from;
  final Future<void> Function(HomeInterview) onOpen;
  final VoidCallback? onSchedule;
  final Future<void> Function(HomeInterview)? onViewJob;
  final DateTime Function()? now;
  @override
  Widget build(BuildContext context) => _HomePagedList<HomeInterview>(
    title: '近期面试',
    description: '今天起的面试安排 · 到预约时间后可开始',
    empty: '暂无即将进行的面试',
    onAll: onSchedule,
    allLabel: '面试日程',
    load: (page) => source.loadInterviews(
      page: page,
      minimum: HomeDataSource.pageSize,
      from: from,
    ),
    identity: (item) => item.id,
    itemBuilder: (item, reload) => HomeInterviewRow(
      interview: item,
      now: now,
      onViewJob: onViewJob == null || item.positionId == null
          ? null
          : () async {
              await onViewJob!(item);
              reload();
            },
      onOpen: () async {
        await onOpen(item);
        reload();
      },
    ),
  );
}

class HomeApplicationsPage extends StatelessWidget {
  const HomeApplicationsPage({
    super.key,
    required this.source,
    required this.onOpen,
    this.onJobs,
    this.companyName,
  });
  final HomeDataSource source;
  final Future<void> Function(HomeApplication) onOpen;
  final VoidCallback? onJobs;
  final String? companyName;
  @override
  Widget build(BuildContext context) => _HomePagedList<HomeApplication>(
    title: '岗位投递概览',
    description: '累计投递 · 按岗位发布时间排序',
    empty: '暂无岗位投递数据',
    onAll: onJobs,
    allLabel: '全部岗位',
    wrapItemsInCard: false,
    load: (page) => source.loadApplications(page: page),
    identity: (item) => '${item.positionId ?? item.title}',
    itemBuilder: (item, reload) => HomeApplicationRow(
      application: item,
      companyName: companyName,
      onOpen: () async {
        await onOpen(item);
        reload();
      },
    ),
  );
}

class _HomePagedList<T> extends StatefulWidget {
  const _HomePagedList({
    required this.title,
    required this.description,
    required this.empty,
    required this.load,
    required this.identity,
    required this.itemBuilder,
    this.onAll,
    required this.allLabel,
    this.wrapItemsInCard = true,
  });
  final String title;
  final String description;
  final String empty;
  final Future<HomePageSlice<T>> Function(int) load;
  final String Function(T) identity;
  final Widget Function(T, VoidCallback) itemBuilder;
  final VoidCallback? onAll;
  final String allLabel;
  final bool wrapItemsInCard;
  @override
  State<_HomePagedList<T>> createState() => _HomePagedListState<T>();
}

class _HomePagedListState<T> extends State<_HomePagedList<T>> {
  final _items = <T>[];
  bool _loading = true;
  Object? _error;
  int? _nextPage = 1;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
  }

  Future<void> _load({bool reset = false}) async {
    if (!mounted || (!reset && (_loading || _nextPage == null))) return;
    final request = ++_request;
    final page = reset ? 1 : _nextPage!;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _nextPage = 1;
      }
    });
    try {
      final slice = await widget.load(page);
      if (!mounted || request != _request) return;
      final merged = <String, T>{
        for (final item in _items) widget.identity(item): item,
      };
      for (final item in slice.items) {
        merged[widget.identity(item)] = item;
      }
      setState(() {
        _items
          ..clear()
          ..addAll(merged.values);
        _nextPage = slice.nextPage;
      });
    } catch (error) {
      if (mounted && request == _request) setState(() => _error = error);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        if (widget.onAll != null)
          TextButton(onPressed: widget.onAll, child: Text(widget.allLabel)),
      ],
    ),
    body: SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              widget.description,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            if (_items.isEmpty && _loading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: HomeSkeleton(),
                ),
              )
            else if (_items.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: HomeStatus(
                    message: widget.empty,
                    error: _error,
                    onRetry: () => _load(reset: true),
                  ),
                ),
              )
            else ...[
              for (final item in _items) ...[
                if (widget.wrapItemsInCard)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: widget.itemBuilder(item, () {
                        if (mounted) unawaited(_load(reset: true));
                      }),
                    ),
                  )
                else
                  widget.itemBuilder(item, () {
                    if (mounted) unawaited(_load(reset: true));
                  }),
                const SizedBox(height: 12),
              ],
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                HomeStatus(message: '', error: _error, onRetry: () => _load())
              else if (_nextPage != null)
                OutlinedButton(
                  onPressed: () => _load(),
                  child: const Text('加载更多'),
                )
              else
                const Center(
                  child: Text(
                    '已显示全部',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
