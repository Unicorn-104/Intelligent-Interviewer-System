import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../api/jobs_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import 'job_detail_page.dart';
import 'job_publish_page.dart';
import 'widgets/job_list_card.dart';
import 'widgets/job_sort_sheet.dart';

typedef JobsLoader = Future<List<Map<String, dynamic>>> Function({
  String? keyword,
  String? dept,
  int? status,
  required int pageNum,
  required int pageSize,
});

class JobsPage extends StatefulWidget {
  const JobsPage({
    super.key,
    this.loadJobs,
    this.updateStatus,
    this.detailBuilder,
    this.publishBuilder,
  });
  final JobsLoader? loadJobs;
  final Future<void> Function(int id, int status)? updateStatus;
  final Widget Function(Map<String, dynamic> job, int initialTab)?
  detailBuilder;
  final WidgetBuilder? publishBuilder;
  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  static const _pageSize = 20;
  final _search = TextEditingController();
  final _jobs = <Map<String, dynamic>>[];
  final _changing = <int>{};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 0;
  int _request = 0;
  Object? _error;
  Object? _moreError;
  int? _statusFilter;
  JobSortDimension _sortDimension = JobSortDimension.latestApply;
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loading || _loadingMore || !_hasMore)) return;
    final request = ++_request;
    final page = more ? _page + 1 : 1;
    setState(() {
      if (more) {
        _loadingMore = true;
        _moreError = null;
      } else {
        _loading = true;
        _loadingMore = false;
        _error = null;
        _moreError = null;
      }
    });
    try {
      final rows = await (widget.loadJobs ?? listJobs)(
        keyword: _search.text.trim(),
        status: _statusFilter,
        pageNum: page,
        pageSize: _pageSize,
      );
      if (!mounted || request != _request) return;
      if (more && rows.isNotEmpty) {
        final known = _jobs.map((job) => '${job['posId']}').toSet();
        if (rows.every((job) => known.contains('${job['posId']}'))) {
          throw const ApiException('分页数据重复，请刷新后重试');
        }
      }
      setState(() {
        if (!more) _jobs.clear();
        final existing = {
          for (var index = 0; index < _jobs.length; index++)
            '${_jobs[index]['posId']}': index,
        };
        for (final row in rows) {
          final index = existing['${row['posId']}'];
          if (index == null) {
            existing['${row['posId']}'] = _jobs.length;
            _jobs.add(Map.of(row));
          } else {
            _jobs[index] = Map.of(row);
          }
        }
        _page = page;
        _hasMore = rows.length == _pageSize;
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          if (more) {
            _moreError = error;
          } else {
            _error = error;
          }
        });
      }
    } finally {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _openJob(Map<String, dynamic> raw, {int initialTab = 0}) async {
    final job = _toJobView(raw);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            widget.detailBuilder?.call(job, initialTab) ??
            JobDetailPage(job: job, initialTab: initialTab),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _toggleStatus(Map<String, dynamic> job) async {
    final id = int.tryParse('${job['posId']}');
    final status = int.tryParse('${job['status']}');
    if (id == null ||
        !const [0, 1, 2].contains(status) ||
        _changing.contains(id)) {
      return;
    }
    setState(() => _changing.add(id));
    final targetStatus = status == 1 ? 0 : 1;
    final target = targetStatus == 1 ? '上线' : '下线';
    final title = _textOr(job['title'], '未命名岗位');
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('确认$target'),
          content: Text(
            status == 2 ? '确定将暂停岗位「$title」恢复为在招吗？' : '确定要$target岗位「$title」吗？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确认'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await (widget.updateStatus ?? changeJobStatus)(id, targetStatus);
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _changing.remove(id));
    }
  }

  Future<void> _openCreate() async {
    final id = await Navigator.of(context, rootNavigator: true).push<int>(
      MaterialPageRoute(
        builder: widget.publishBuilder ?? (_) => const JobPublishPage(),
      ),
    );
    if (id == null || !mounted) return;
    _search.clear();
    setState(() => _statusFilter = null);
    await _load();
    if (!mounted) return;
    final job = _jobs
        .where((row) => int.tryParse('${row['posId']}') == id)
        .firstOrNull;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          id == 0
              ? '请在岗位列表核对发布结果'
              : _error == null
              ? '岗位发布成功，已更新岗位列表'
              : '岗位已发布，列表加载失败，请刷新',
        ),
        action: job == null
            ? null
            : SnackBarAction(label: '查看岗位', onPressed: () => _openJob(job)),
      ),
    );
  }

  void _filter(int? status) {
    setState(() => _statusFilter = status);
    _load();
  }

  Future<void> _openSort() async {
    final selection = await showModalBottomSheet<JobSortSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) =>
          JobSortSheet(dimension: _sortDimension, ascending: _sortAscending),
    );
    if (selection == null || !mounted) return;
    setState(() {
      _sortDimension = selection.dimension;
      _sortAscending = selection.ascending;
    });
  }

  int? _sortValue(Map<String, dynamic> job) {
    final raw = job[_sortDimension.field];
    if (_sortDimension == JobSortDimension.applicants) {
      final count = int.tryParse('$raw');
      return count != null && count >= 0 ? count : null;
    }
    // Both API timestamps are UTC+8 wall-clock values, formatted to the minute.
    final text = raw?.toString().trim() ?? '';
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})$')
        .firstMatch(text);
    if (match == null) return null;
    final parts = [for (var i = 1; i <= 5; i++) int.parse(match.group(i)!)];
    final date = DateTime.utc(parts[0], parts[1], parts[2], parts[3], parts[4]);
    if (date.year != parts[0] ||
        date.month != parts[1] ||
        date.day != parts[2] ||
        date.hour != parts[3] ||
        date.minute != parts[4]) {
      return null;
    }
    return date.millisecondsSinceEpoch;
  }

  List<Map<String, dynamic>> _sortedJobs() {
    final rows = [
      for (final (index, job) in _jobs.indexed)
        (index: index, job: job, value: _sortValue(job)),
    ];
    rows.sort((left, right) {
      final a = left.value;
      final b = right.value;
      if (a == null || b == null) {
        if (a == b) return left.index.compareTo(right.index);
        return a == null ? 1 : -1;
      }
      final order = _sortAscending ? a.compareTo(b) : b.compareTo(a);
      return order == 0 ? left.index.compareTo(right.index) : order;
    });
    return [for (final row in rows) row.job];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('岗位')),
    body: SafeArea(
      top: false,
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact =
                        constraints.maxWidth < 360 ||
                        MediaQuery.textScalerOf(context).scale(13) > 19;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('jobs-search'),
                            controller: _search,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _load(),
                            decoration: InputDecoration(
                              hintText: '搜索岗位或部门',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                              prefixIcon: IconButton(
                                tooltip: '搜索',
                                onPressed: () => _load(),
                                icon: const Icon(Icons.search, size: 21),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          key: const ValueKey('jobs-publish'),
                          onPressed: _openCreate,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!compact) ...[
                                const Icon(Icons.add, size: 18),
                                const SizedBox(width: 4),
                              ],
                              const Text(
                                '发布岗位',
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final (label, value) in <(String, int?)>[
                              ('全部', null),
                              ('在招', 1),
                              ('已下线', 0),
                              ('暂停', 2),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  key: ValueKey('jobs-filter-$value'),
                                  label: Text(label),
                                  selected: _statusFilter == value,
                                  showCheckmark: false,
                                  selectedColor: AppColors.interactiveSoft,
                                  backgroundColor: AppColors.canvas,
                                  side: BorderSide(
                                    color: _statusFilter == value
                                        ? AppColors.interactive
                                        : AppColors.hairline,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  labelStyle: TextStyle(
                                    color: _statusFilter == value
                                        ? AppColors.interactive
                                        : AppColors.textSecondary,
                                  ),
                                  onSelected: (_) => _filter(value),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 76,
                      child: Tooltip(
                        message:
                            '${_sortDimension.label} · '
                            '${_sortDimension.directionLabel(_sortAscending)}',
                        child: OutlinedButton(
                          key: const ValueKey('jobs-sort'),
                          onPressed: _openSort,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(76, 46),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            foregroundColor: AppColors.interactive,
                            backgroundColor: AppColors.canvas,
                            side: const BorderSide(color: AppColors.hairline),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _sortAscending
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              const Flexible(
                                child: Text(
                                  '排序',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    ),
  );

  Widget _failure(Object error, VoidCallback retry) {
    if (error is ApiException) {
      final code = error.code ?? error.statusCode;
      if (code == 403) return PagePermissionDenied(onAction: retry);
      if (code == 401) {
        return PageMessage(
          icon: Icons.lock_outline,
          title: '登录已过期',
          message: '请退出后重新登录',
          onAction: retry,
        );
      }
      if (error.message.toLowerCase().contains('timeout') ||
          error.message.contains('超时')) {
        return PageTimeout(onRetry: retry);
      }
    }
    return PageMessage(
      icon: Icons.cloud_off_outlined,
      title: '加载失败',
      message: _friendlyError(error),
      onAction: retry,
    );
  }

  Widget _body() {
    if (_loading) return const SkeletonList(rows: 4);
    if (_error != null) return _failure(_error!, () => _load());
    if (_jobs.isEmpty) {
      return PageMessage(
        icon: Icons.work_off_outlined,
        title: '暂无岗位',
        message: _search.text.trim().isNotEmpty || _statusFilter != null
            ? '没有符合当前搜索/筛选条件的岗位'
            : '点击搜索栏旁的“发布岗位”开始招聘',
        actionLabel: '清除条件',
        onAction: _search.text.trim().isNotEmpty || _statusFilter != null
            ? () {
                _search.clear();
                _filter(null);
              }
            : null,
      );
    }
    final sortedJobs = _sortedJobs();
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView.separated(
        key: const ValueKey('jobs-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: sortedJobs.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index < sortedJobs.length) {
            final job = sortedJobs[index];
            final id = int.tryParse('${job['posId']}');
            return JobListCard(
              key: ValueKey('jobs-row-${job['posId']}'),
              job: job,
              changing: _changing.contains(id),
              onOpen: () => _openJob(job),
              onApplicants: () => _openJob(job, initialTab: 1),
              onToggle: () => _toggleStatus(job),
            );
          }
          if (_loadingMore) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (_moreError != null) {
            return _failure(_moreError!, () => _load(more: true));
          }
          if (_hasMore) {
            return OutlinedButton(
              key: const ValueKey('jobs-load-more'),
              onPressed: () => _load(more: true),
              child: const Text('加载更多'),
            );
          }
          return const Center(
            child: Text('已显示全部', style: TextStyle(color: AppColors.textMuted)),
          );
        },
      ),
    );
  }
}

String _friendlyError(Object error) {
  if (error is ApiException) return error.message;
  return '网络异常，请检查网络后重试';
}

String _educationLabel(Object? education) {
  return switch (int.tryParse('$education')) {
    1 => '中专',
    2 => '大专',
    3 => '本科',
    4 => '硕士',
    5 => '博士',
    _ => '不限',
  };
}

/// 后端列表行 → 卡片展示结构（页面层映射，不在 api/ 修改）。
///
/// 列表行含 jdJson（原始 JD JSON 字符串）：技能标签仅在 JD 画像解析后
/// （jdJson 内含 skills 字段）出现，未解析时卡片不显示标签区（不伪造数据）；
/// 技能标签在详情页由 /enterprise/jd/{posId} 展示（t_pos_skill 真实数据）。
Map<String, dynamic> _toJobView(Map<String, dynamic> row) {
  final salaryMin = num.tryParse('${row['salaryMin']}');
  final salaryMax = num.tryParse('${row['salaryMax']}');
  final salaryParts = <String>[
    if (salaryMin != null) _salaryK(salaryMin),
    if (salaryMax != null) _salaryK(salaryMax),
  ];
  return {
    'posId': int.tryParse('${row['posId']}'),
    'title': _textOr(row['title'], '未命名岗位'),
    'dept': _textOr(row['dept'], '部门未填写'),
    'location': _textOr(row['city'], '地点未填写'),
    'status': int.tryParse('${row['status']}'),
    'education': _educationLabel(row['education']),
    'years': row['experience'] ?? '不限',
    'skills': _jdSkills(row['jdJson']),
    'salary': salaryParts.isEmpty ? '面议' : '${salaryParts.join('-')}K·月薪',
    'applicants': int.tryParse('${row['applicantCount']}') ?? '-',
  };
}

/// 月薪（元）→ K 展示（如 22000 → 22K）。
String _salaryK(num value) =>
    (value / 1000).toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

String _textOr(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

/// 从 jdJson（JSON 字符串）提取技能标签；非画像格式时返回空列表。
List<String> _jdSkills(Object? jdJson) {
  if (jdJson is! String || jdJson.isEmpty) return const [];
  try {
    final decoded = jsonDecode(jdJson);
    if (decoded is Map && decoded['skills'] is List) {
      return (decoded['skills'] as List)
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
    }
  } catch (_) {
    // jdJson 非标准 JSON 时忽略
  }
  return const [];
}
