import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import 'data/reschedule_review_data_source.dart';

class RescheduleReviewPage extends StatefulWidget {
  const RescheduleReviewPage({super.key, this.source, this.initialRequestId});
  final RescheduleReviewDataSource? source;
  final int? initialRequestId;

  @override
  State<RescheduleReviewPage> createState() => _RescheduleReviewPageState();
}

class _RescheduleReviewPageState extends State<RescheduleReviewPage> {
  late final _source = widget.source ?? RescheduleReviewDataSource();
  final _records = <RescheduleRequest>[];
  final _uncertain = <int>{};
  final _verifiedPending = <int>{};
  final _reviewErrors = <int, String>{};
  bool _loading = true, _moreLoading = false;
  int _filterIndex = 0, _generation = 0, _nextPage = 1, _total = 0;
  int? _reviewing;
  String? _error, _moreError;
  static const _statuses = <String?>[null, 'pending', 'approved', 'rejected'];

  @override
  void initState() {
    super.initState();
    final requestId = widget.initialRequestId;
    if (requestId == null) {
      _load();
    } else {
      _loadSpecific(requestId);
    }
  }

  Future<void> _loadSpecific(int requestId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _source.detail(requestId);
      final row = RescheduleRequest.fromJson(data);
      if (!mounted) return;
      setState(() {
        _records
          ..clear()
          ..add(row);
        _filterIndex = _statuses.indexOf(row.status);
        _total = 1;
        _nextPage = 1;
      });
    } catch (error) {
      if (mounted)
        setState(() => _error = RescheduleReviewDataSource.errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load({bool more = false}) async {
    if (_reviewing != null ||
        (more && (_loading || _moreLoading || _records.length >= _total))) {
      return;
    }
    final generation = ++_generation;
    final page = more ? _nextPage : 1;
    final status = _statuses[_filterIndex];
    setState(() {
      _error = null;
      _moreError = null;
      if (more) {
        _moreLoading = true;
      } else {
        _loading = true;
        _moreLoading = false;
      }
    });
    try {
      final result = await _source.load(status: status, page: page);
      if (!mounted || generation != _generation) return;
      if (more && result.rows.isEmpty && _records.length < result.total) {
        throw const FormatException('列表已变化，请下拉刷新');
      }
      setState(() {
        if (!more) _records.clear();
        for (final row in result.rows) {
          _records.removeWhere((old) => old.id == row.id);
          _records.add(row);
          if (row.status == 'pending' && _uncertain.contains(row.id)) {
            _verifiedPending.add(row.id);
          }
          if (row.status != 'pending') {
            _verifiedPending.remove(row.id);
            _uncertain.remove(row.id);
            _reviewErrors.remove(row.id);
          }
        }
        _total = result.total;
        _nextPage = page + 1;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        if (more) {
          _moreError = RescheduleReviewDataSource.errorMessage(error);
        } else {
          _error = RescheduleReviewDataSource.errorMessage(error);
        }
      });
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _moreLoading = false;
        });
      }
    }
  }

  Future<void> _audit(RescheduleRequest row, String decision) async {
    if (_reviewing != null || _uncertain.contains(row.id)) return;
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ReviewDialog(row: row, decision: decision),
    );
    if (!mounted || note == null) return;
    setState(() => _reviewing = row.id);
    try {
      final result = await _source.review(row.id, decision, note: note);
      if (!mounted) return;
      setState(() {
        final index = _records.indexWhere((old) => old.id == row.id);
        if (index >= 0) _records[index] = result;
        _uncertain.remove(row.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'approved' ? '申请已通过，面试时段已更新' : '申请已驳回，原面试安排不变',
          ),
        ),
      );
      setState(() => _reviewing = null);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uncertain.add(row.id);
        _verifiedPending.remove(row.id);
        _reviewErrors[row.id] = RescheduleReviewDataSource.errorMessage(error);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('审批结果待核对，请刷新查看。不会自动重复提交')));
    } finally {
      if (mounted) setState(() => _reviewing = null);
    }
  }

  Future<void> _allowManualRetry(RescheduleRequest row) async {
    if (!_verifiedPending.contains(row.id)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新审批前请核对'),
        content: const Text(
          '请先刷新并确认申请仍待审批。重新提交需要再次确认；后端会对同结果重复请求进行幂等校验，不能覆盖已完成的审批。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('已核对，恢复操作'),
          ),
        ],
      ),
    );
    if (mounted && ok == true) setState(() => _uncertain.remove(row.id));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('改期审批'),
      actions: [
        IconButton(
          key: const Key('reschedule-review-refresh'),
          tooltip: '刷新审批记录',
          onPressed: _reviewing != null || _loading ? null : () => _load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (index, title) in const [
                '全部',
                '待审批',
                '已通过',
                '已驳回',
              ].indexed)
                ChoiceChip(
                  key: ValueKey('reschedule-review-filter-$index'),
                  label: Text(title),
                  selected: index == _filterIndex,
                  onSelected: _reviewing != null
                      ? null
                      : (_) {
                          setState(() => _filterIndex = index);
                          _load();
                        },
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            '仅显示当前企业的真实申请。待审批保留原安排，通过后才更新面试时段。',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
        Expanded(child: _body()),
      ],
    ),
  );

  Widget _body() {
    if (_loading) return const SkeletonList(rows: 4);
    if (_error != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '审批记录加载失败',
        message: _error!,
        actionLabel: '重试',
        onAction: () => _load(),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView.separated(
        key: const Key('reschedule-review-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        itemCount: _records.isEmpty ? 1 : _records.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (_records.isEmpty) {
            return const PageMessage(
              icon: Icons.event_repeat_outlined,
              title: '暂无改期申请',
              message: '当前筛选下暂无真实申请，不展示演示数据',
            );
          }
          if (index == _records.length) {
            return Column(
              children: [
                if (_moreError != null)
                  Text(
                    _moreError!,
                    style: const TextStyle(color: AppColors.red),
                  ),
                if (_records.length < _total)
                  OutlinedButton(
                    key: const Key('reschedule-review-more'),
                    onPressed: _moreLoading || _reviewing != null
                        ? null
                        : () => _load(more: true),
                    child: Text(
                      _moreLoading
                          ? '加载中…'
                          : _moreError == null
                          ? '加载更多'
                          : '重试加载更多',
                    ),
                  )
                else
                  Text(
                    '已加载 ${_records.length} 条申请',
                    style: const TextStyle(color: AppColors.muted),
                  ),
              ],
            );
          }
          final row = _records[index];
          return _RecordCard(
            row: row,
            busy: _reviewing != null,
            uncertain: _uncertain.contains(row.id),
            canRetry: _verifiedPending.contains(row.id),
            error: _reviewErrors[row.id],
            onAudit: (decision) => _audit(row, decision),
            onRefresh: () => _load(),
            onManualRetry: () => _allowManualRetry(row),
          );
        },
      ),
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.row, required this.decision});
  final RescheduleRequest row;
  final String decision;
  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _note = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final approve = widget.decision == 'approved';
    return AlertDialog(
      title: Text(approve ? '确认通过改期？' : '确认驳回改期？'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.row.candidateName} · ${widget.row.positionName}'),
            const SizedBox(height: 8),
            Text('原时段：${widget.row.originalStart} — ${widget.row.originalEnd}'),
            Text('新时段：${widget.row.newStart} — ${widget.row.newEnd}'),
            const SizedBox(height: 8),
            Text(approve ? '通过前将重新检查冲突，成功后新时段生效并释放原时段。' : '驳回不会改变原面试安排，请填写说明。'),
            const SizedBox(height: 12),
            TextField(
              key: const Key('reschedule-review-note'),
              controller: _note,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: approve ? '审批说明（选填）' : '驳回说明（必填）',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('reschedule-review-confirm'),
          onPressed: () {
            if (!approve && _note.text.trim().isEmpty) {
              setState(() => _error = '请填写驳回说明');
              return;
            }
            Navigator.pop(context, _note.text.trim());
          },
          child: Text(approve ? '确认通过' : '确认驳回'),
        ),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.row,
    required this.busy,
    required this.uncertain,
    required this.canRetry,
    this.error,
    required this.onAudit,
    required this.onRefresh,
    required this.onManualRetry,
  });
  final RescheduleRequest row;
  final bool busy, uncertain, canRetry;
  final String? error;
  final ValueChanged<String> onAudit;
  final VoidCallback onRefresh, onManualRetry;
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (row.status) {
      'approved' => ('已通过', AppColors.green),
      'rejected' => ('已驳回', AppColors.red),
      _ => ('待审批', AppColors.orange),
    };
    return Card(
      key: ValueKey('reschedule-review-card-${row.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  '${row.candidateName} · ${row.positionName}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(label, style: TextStyle(color: color)),
              ],
            ),
            const SizedBox(height: 10),
            Text('原时段：${row.originalStart} — ${row.originalEnd}'),
            const SizedBox(height: 6),
            Text(
              '新时段：${row.newStart} — ${row.newEnd}',
              style: const TextStyle(color: AppColors.interactive),
            ),
            const SizedBox(height: 8),
            Text('申请原因：${row.reason}'),
            Text(
              '申请于 ${row.requestedAt} · 面试官 ${row.interviewerName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (row.reviewedAt != null)
              Text(
                '审批于 ${row.reviewedAt} · ${row.reviewerName ?? '企业招聘者'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (row.reviewNote?.isNotEmpty == true)
              Text('审批说明：${row.reviewNote}'),
            if (row.status == 'pending') ...[
              const SizedBox(height: 12),
              if (uncertain) ...[
                if (error != null)
                  Text(error!, style: const TextStyle(color: AppColors.red)),
                const Text(
                  '审批结果待核对：请先刷新，不会自动重发',
                  style: TextStyle(color: AppColors.orange),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      key: ValueKey('reschedule-review-check-${row.id}'),
                      onPressed: busy ? null : onRefresh,
                      child: const Text('刷新核对'),
                    ),
                    TextButton(
                      onPressed: busy || !canRetry ? null : onManualRetry,
                      child: const Text('人工核对后恢复操作'),
                    ),
                  ],
                ),
              ] else
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      key: ValueKey('reschedule-review-reject-${row.id}'),
                      onPressed: busy ? null : () => onAudit('rejected'),
                      child: const Text('驳回'),
                    ),
                    FilledButton(
                      key: ValueKey('reschedule-review-approve-${row.id}'),
                      onPressed: busy ? null : () => onAudit('approved'),
                      child: const Text('通过'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
