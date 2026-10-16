import 'dart:async';

import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../features/auth/domain/auth_session.dart';
import '../features/jobs/data/job_api.dart';
import '../models/job.dart';
import '../theme/app_theme.dart';
import '../widgets/job_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.session, this.initialKeyword});

  final AuthSession session;
  final String? initialKeyword;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late final ApiClient _client;
  late final JobApi _api;
  Timer? _debounce;
  List<Job>? _jobs;
  String? _error;
  String? _filter;
  int? _applyingPositionId;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialKeyword ?? '');
    _client = ApiClient();
    _api = JobApi(_client);
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _client.close();
    super.dispose();
  }

  void _onKeywordChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    setState(() {
      _jobs = null;
      _error = null;
    });
    try {
      final jobs = await _api.searchJobs(
        widget.session.token,
        keyword: _controller.text,
        filter: _filter,
      );
      if (mounted) setState(() => _jobs = jobs);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
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
            child: const Text('取消'),
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
      if (mounted) {
        setState(() {
          _jobs = _jobs
              ?.map(
                (item) => item.positionId == job.positionId
                    ? item.copyWith(applied: true)
                    : item,
              )
              .toList();
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
      if (mounted) setState(() => _applyingPositionId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索职位')),
      body: RefreshIndicator(
        onRefresh: _search,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            TextField(
              controller: _controller,
              autofocus: widget.initialKeyword != null,
              textInputAction: TextInputAction.search,
              onChanged: _onKeywordChanged,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: '职位 / 企业 / 技能',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空',
                        onPressed: () {
                          _controller.clear();
                          setState(() {});
                          _search();
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: '综合推荐',
                    selected: _filter == null,
                    onTap: () => _selectFilter(null),
                  ),
                  _FilterChip(
                    label: '最新发布',
                    selected: _filter == 'latest',
                    onTap: () => _selectFilter('latest'),
                  ),
                  _FilterChip(
                    label: '高薪急招',
                    selected: _filter == 'urgent',
                    onTap: () => _selectFilter('urgent'),
                  ),
                  _FilterChip(
                    label: '大型企业',
                    selected: _filter == 'large',
                    onTap: () => _selectFilter('large'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_jobs != null)
              Text(
                '共找到 ${_jobs!.length} 个相关职位',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 10),
            ..._buildResults(),
          ],
        ),
      ),
    );
  }

  void _selectFilter(String? value) {
    if (_filter == value) return;
    setState(() => _filter = value);
    _search();
  }

  List<Widget> _buildResults() {
    if (_error != null) {
      return [
        _SearchState(
          icon: Icons.wifi_off_rounded,
          title: '加载失败',
          subtitle: _error!,
          action: '重新加载',
          onAction: _search,
        ),
      ];
    }
    if (_jobs == null) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_jobs!.isEmpty) {
      return const [
        _SearchState(
          icon: Icons.search_off_rounded,
          title: '没有找到相关职位',
          subtitle: '换个职位名称、企业或技能关键词试试。',
        ),
      ];
    }
    return [
      for (final job in _jobs!) ...[
        JobCard(
          session: widget.session,
job: job,
          onApply: _apply,
          applying: _applyingPositionId == job.positionId,
        ),
        const SizedBox(height: 12),
      ],
    ];
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _SearchState extends StatelessWidget {
  const _SearchState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.muted),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (action != null) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}
