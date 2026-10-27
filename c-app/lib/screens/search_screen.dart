import '../features/jobs/presentation/application_resume_picker.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../features/auth/domain/auth_session.dart';
import '../features/jobs/data/job_api.dart';
import '../features/jobs/data/job_search_api.dart';
import '../features/jobs/domain/job_search.dart';
import '../features/jobs/presentation/job_filter_sheet.dart';
import '../features/jobs/presentation/job_search_controller.dart';
import '../models/job.dart';
import '../theme/app_theme.dart';
import '../widgets/async_state_card.dart';
import '../widgets/job_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.session,
    this.initialKeyword,
    this.searchApi,
    this.openFilters = false,
  });
  final AuthSession session;
  final String? initialKeyword;
  final JobSearchApi? searchApi;
  final bool openFilters;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late final ApiClient _client;
  late final JobApi _api;
  late final JobSearchController _search;
  final _scroll = ScrollController();
  Timer? _debounce;
  int? _applyingPositionId;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialKeyword ?? '');
    _client = ApiClient();
    _api = JobApi(_client);
    _search = JobSearchController(
      widget.searchApi ?? JobSearchApi(_client),
      widget.session.token,
      query: JobSearchQuery(keyword: _controller.text),
    );
    _scroll.addListener(_loadNearEnd);
    unawaited(_search.refresh());
    unawaited(_search.loadOptions());
    if (widget.openFilters) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openFilter(JobFilterPanel.more));
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scroll.dispose();
    _search.dispose();
    _client.close();
    super.dispose();
  }

  void _loadNearEnd() {
    if (_scroll.position.extentAfter < MediaQuery.sizeOf(context).height / 2) {
      unawaited(_search.loadMore());
    }
  }

  void _toStart() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _onKeywordChanged(String value) {
    _debounce?.cancel();
    _search.prepare(_search.query.copyWith(keyword: value));
    _toStart();
    _debounce = Timer(const Duration(milliseconds: 350), _refresh);
  }

  Future<void> _refresh() {
    _debounce?.cancel();
    return _search.refresh();
  }

  Future<void> _changeQuery(JobSearchQuery query) async {
    _debounce?.cancel();
    _search.prepare(query);
    _toStart();
    await _search.refresh();
  }

  Future<void> _openFilter(JobFilterPanel panel) async {
    FocusScope.of(context).unfocus();
    if (_debounce?.isActive == true) unawaited(_refresh());
    if (panel != JobFilterPanel.sort &&
        _search.options == null &&
        !_search.optionsLoading) {
      unawaited(_search.loadOptions());
    }
    final result = await showModalBottomSheet<JobSearchQuery>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SafeArea(
        top: false,
        child: JobFilterSheet(controller: _search, panel: panel),
      ),
    );
    if (!mounted || result == null) return;
    FocusScope.of(context).unfocus();
    if (_controller.text != result.keyword) _controller.text = result.keyword;
    await _changeQuery(result);
  }

  void _clearAll() {
    _controller.clear();
    unawaited(_changeQuery(JobSearchQuery(sort: _search.query.sort)));
  }

  Future<bool> _apply(Job job) async {
    final resumeId = await chooseApplicationResume(
      context,
      token: widget.session.token,
      job: job,
    );
    if (!mounted || resumeId == null) return false;
    setState(() => _applyingPositionId = job.positionId);
    try {
      await _api.apply(
        widget.session.token,
        job.positionId,
        resumeId: resumeId,
      );
      if (mounted) {
        _search.markApplied(job.positionId);
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
      if (mounted) setState(() => _applyingPositionId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('搜索职位')),
    body: AnimatedBuilder(
      animation: _search,
      builder: (context, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: _controls(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                itemCount: _search.items.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) return _header();
                  if (index <= _search.items.length) {
                    final job = _search.items[index - 1];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: JobCard(
                        session: widget.session,
                        key: ValueKey(job.positionId),
                        job: job,
                        onApply: _apply,
                        applying: _applyingPositionId == job.positionId,
                      ),
                    );
                  }
                  return _footer();
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _controls() {
    final query = _search.query;
    final moreCount = query.selectedConditions.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          autofocus: widget.initialKeyword != null,
          textInputAction: TextInputAction.search,
          onChanged: _onKeywordChanged,
          onSubmitted: (_) {
            _toStart();
            unawaited(_refresh());
          },
          decoration: InputDecoration(
            hintText: '职位 / 企业 / 技能',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: '清空',
                    onPressed: () {
                      _controller.clear();
                      _onKeywordChanged('');
                      unawaited(_refresh());
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterButton(
                query.sort == 'match' ? '排序' : jobSortLabels[query.sort]!,
                JobFilterPanel.sort,
                query.sort != 'match',
              ),
              _filterButton(
                query.city.isEmpty ? '城市' : query.city,
                JobFilterPanel.city,
                query.city.isNotEmpty,
              ),
              _filterButton(
                query.positionLabel.isEmpty ? '职位类别' : query.positionLabel,
                JobFilterPanel.category,
                query.positionLabel.isNotEmpty || query.category.isNotEmpty,
              ),
              _filterButton(
                query.experienceMin.isEmpty ? '经验' : query.experienceMin,
                JobFilterPanel.experience,
                query.experienceMin.isNotEmpty,
              ),
              _filterButton(
                moreCount == 0 ? '筛选' : '筛选($moreCount)',
                JobFilterPanel.more,
                moreCount > 0,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header() {
    final query = _search.query;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (query.selectedConditions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final entry in query.selectedConditions.entries)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: InputChip(
                      label: Text(entry.value, overflow: TextOverflow.ellipsis),
                      tooltip: entry.value,
                      onDeleted: () => _changeQuery(query.without(entry.key)),
                      deleteButtonTooltipMessage: '移除${entry.value}',
                    ),
                  ),
                TextButton(onPressed: _clearAll, child: const Text('清空全部')),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (_search.total != null)
          Text(
            '共找到 ${_search.total} 个相关职位',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _filterButton(String label, JobFilterPanel panel, bool active) =>
      ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .45,
        ),
        child: TextButton(
          onPressed: () => _openFilter(panel),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, AppSpacing.minTouch),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            foregroundColor: active
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      );

  Widget _footer() {
    if (_search.loading || _search.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_search.error != null) {
      return AsyncStateCard(
        title: '职位加载失败',
        message: _search.error!,
        icon: Icons.wifi_off_rounded,
        onRetry: _search.retry,
      );
    }
    if (_search.items.isEmpty) {
      return AsyncStateCard(
        title: '没有找到相关职位',
        message: '试试调整关键词或筛选条件。',
        icon: Icons.search_off_rounded,
        actionLabel: '重置筛选',
        onRetry: _clearAll,
      );
    }
    if (_search.hasNext) {
      return Center(
        child: TextButton(
          onPressed: _search.loadMore,
          child: const Text('加载更多'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Text('已显示全部职位', style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}
