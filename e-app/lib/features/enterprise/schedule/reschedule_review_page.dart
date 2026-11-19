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
  bool _loading = true, _moreLoading = false;
  int _filter = 0, _nextPage = 1, _total = 0, _pendingCount = 0;
  int? _reviewing;
  String? _error, _moreError;
  final _uncertain = <int>{};
  final _reviewErrors = <int, String>{};

  @override
  void initState() {
    super.initState();
    final id = widget.initialRequestId;
    if (id == null) {
      _load();
    } else {
      _loadSpecific(id);
    }
  }

  Future<void> _loadSpecific(int id) async {
    setState(() { _loading = true; _error = null; });
    try {
      final row = RescheduleRequest.fromJson(await _source.detail(id));
      if (!mounted) return;
      setState(() { _records..clear()..add(row); _total = 1; _nextPage = 1; });
    } catch (error) {
      if (mounted) setState(() => _error = RescheduleReviewDataSource.errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load({bool more = false}) async {
    if (_reviewing != null || (more && (_moreLoading || _loading || _records.length >= _total))) {
      return;
    }
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
      final result = await _source.load(page: more ? _nextPage : 1);
      var pending = _pendingCount;
      try {
        pending = await _source.pendingCount();
      } catch (_) {
        // 列表可用时，角标接口暂时失败不阻断审批记录展示。
      }
      if (!mounted) return;
      setState(() {
        if (!more) _records.clear();
        for (final row in result.rows) {
          _records.removeWhere((old) => old.id == row.id);
          _records.add(row);
        }
        _total = result.total;
        _nextPage = (more ? _nextPage : 1) + 1;
        _pendingCount = pending;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (more) {
          _moreError = RescheduleReviewDataSource.errorMessage(error);
        } else {
          _error = RescheduleReviewDataSource.errorMessage(error);
        }
      });
    } finally {
      if (mounted) setState(() { _loading = false; _moreLoading = false; });
    }
  }

  List<RescheduleRequest> get _visibleRecords => _records.where((row) => switch (_filter) {
    1 => row.status == 'pending',
    2 => row.source == 'enterprise',
    3 => row.status != 'pending',
    _ => true,
  }).toList();

  Future<void> _audit(RescheduleRequest row, String decision) async {
    if (_reviewing != null) return;
    final note = await showDialog<String>(context: context, builder: (_) => _ReviewDialog(row: row, decision: decision));
    if (!mounted || note == null) return;
    setState(() => _reviewing = row.id);
    try {
      await _source.review(row.id, decision, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(decision == 'approved' ? '已同意改期申请' : '已拒绝改期申请')));
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _reviewErrors[row.id] = RescheduleReviewDataSource.errorMessage(error));
        _uncertain.add(row.id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(RescheduleReviewDataSource.errorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _reviewing = null);
    }
  }

  Future<void> _verify(RescheduleRequest row) async {
    try {
      final detail = await _source.detail(row.id);
      final latest = RescheduleRequest.fromJson(detail);
      if (!mounted) return;
      if (latest.status != 'pending') {
        _uncertain.remove(row.id);
        _reviewErrors.remove(row.id);
        await _load();
        return;
      }
      setState(() => _reviewErrors[row.id] = '服务端确认申请仍待审批，可人工核对后恢复操作');
    } catch (error) {
      if (mounted) setState(() => _reviewErrors[row.id] = RescheduleReviewDataSource.errorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('改期审批'),
      actions: [
        IconButton(key: const Key('reschedule-review-refresh'), tooltip: '刷新改期记录', onPressed: _loading ? null : () => _load(), icon: const Icon(Icons.refresh_rounded)),
      ],
    ),
    body: Column(children: [_summary(), _filters(), Expanded(child: _body())]),
  );

  Widget _summary() => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [AppColors.primarySoft, Color(0xfff8fbff)]),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.interactive.withValues(alpha: .14)),
    ),
    child: Row(children: [
      Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.event_repeat_rounded, color: AppColors.interactive)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('集中处理面试时间变更', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 5),
        Text('共 ${_records.length} 条记录 · 我发起的改期也会自动归档', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ])),
      if (_pendingCount > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)), child: Text('$_pendingCount 待处理', style: const TextStyle(color: AppColors.orange, fontSize: 12, fontWeight: FontWeight.w700))),
    ]),
  );

  Widget _filters() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
    child: Row(children: [
      for (final (index, label) in const [(0, '全部'), (1, '待审批'), (2, '我发起'), (3, '已处理')])
        Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(key: ValueKey('reschedule-review-filter-$index'), label: Text(label), selected: _filter == index, onSelected: _reviewing != null ? null : (_) => setState(() => _filter = index))),
    ]),
  );

  Widget _body() {
    if (_loading) return const SkeletonList(rows: 4);
    if (_error != null) return PageMessage(icon: Icons.cloud_off_outlined, title: '改期记录加载失败', message: _error!, actionLabel: '重试', onAction: () => _load());
    final rows = _visibleRecords;
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView.separated(
        key: const Key('reschedule-review-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: rows.isEmpty ? 1 : rows.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (rows.isEmpty) return const PageMessage(icon: Icons.event_available_outlined, title: '暂无改期记录', message: '新的求职者申请和企业改期记录会集中显示在这里');
          if (index == rows.length) {
            if (_records.length < _total) return OutlinedButton(key: const Key('reschedule-review-more'), onPressed: _moreLoading ? null : () => _load(more: true), child: Text(_moreLoading ? '加载中…' : '加载更多'));
            return Center(child: Text(_moreError ?? '已加载全部记录', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)));
          }
          final row = rows[index];
          return _RecordCard(
            row: row,
            busy: _reviewing != null,
            uncertain: _uncertain.contains(row.id),
            error: _reviewErrors[row.id],
            onAudit: (decision) => _audit(row, decision),
            onVerify: () => _verify(row),
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
  @override
  void dispose() { _note.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final approve = widget.decision == 'approved';
    return AlertDialog(
      title: Text(approve ? '同意改期申请' : '拒绝改期申请'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${widget.row.candidateName} · ${widget.row.positionName}'),
        const SizedBox(height: 8),
        Text('新时间：${widget.row.newStart} - ${widget.row.newEnd}'),
        const SizedBox(height: 12),
        TextField(key: const Key('reschedule-review-note'), controller: _note, minLines: 2, maxLines: 4, maxLength: 500, decoration: InputDecoration(labelText: approve ? '审批说明（选填）' : '拒绝原因（必填）')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(key: const Key('reschedule-review-confirm'), onPressed: () { if (!approve && _note.text.trim().isEmpty) return; Navigator.pop(context, _note.text.trim()); }, child: Text(approve ? '确认同意' : '确认拒绝')),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.row, required this.busy, required this.uncertain, this.error, required this.onAudit, required this.onVerify});
  final RescheduleRequest row;
  final bool busy;
  final bool uncertain;
  final String? error;
  final ValueChanged<String> onAudit;
  final VoidCallback onVerify;
  @override
  Widget build(BuildContext context) {
    final pending = row.status == 'pending';
    final statusColor = switch (row.status) { 'approved' => AppColors.green, 'rejected' => AppColors.red, _ => AppColors.orange };
    final statusLabel = switch (row.status) { 'approved' => '已同意', 'rejected' => '已拒绝', _ => '待审批' };
    final enterprise = row.source == 'enterprise';
    return Container(
      key: ValueKey('reschedule-review-card-${row.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .035), blurRadius: 12, offset: const Offset(0, 5))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(row.candidateName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink))),
          _Tag(text: enterprise ? '我发起' : '求职者申请', color: enterprise ? AppColors.interactive : AppColors.purple),
          const SizedBox(width: 6),
          _Tag(text: statusLabel, color: statusColor, filled: true),
        ]),
        const SizedBox(height: 5),
        Text(row.positionName, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 14),
        _TimeRow(icon: Icons.history_rounded, label: '原安排', value: '${row.originalStart} - ${row.originalEnd}'),
        const SizedBox(height: 8),
        _TimeRow(icon: Icons.event_repeat_rounded, label: '调整为', value: '${row.newStart} - ${row.newEnd}', highlight: true),
        const SizedBox(height: 12),
        Container(width: double.infinity, padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)), child: Text('原因：${row.reason}', style: const TextStyle(fontSize: 13, color: AppColors.body))),
        const SizedBox(height: 10),
        Text('申请时间：${row.requestedAt} · 面试官：${row.interviewerName}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        if (row.reviewNote?.isNotEmpty == true) ...[const SizedBox(height: 5), Text('审批说明：${row.reviewNote}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted))],
        if (pending && !enterprise && uncertain) ...[
          const SizedBox(height: 12),
          if (error != null) Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
          const SizedBox(height: 8),
          OutlinedButton(key: ValueKey('reschedule-review-check-${row.id}'), onPressed: busy ? null : onVerify, child: const Text('刷新核对状态')),
        ] else if (pending && !enterprise) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: OutlinedButton(key: ValueKey('reschedule-review-reject-${row.id}'), onPressed: busy ? null : () => onAudit('rejected'), child: const Text('拒绝'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(key: ValueKey('reschedule-review-approve-${row.id}'), onPressed: busy ? null : () => onAudit('approved'), child: const Text('同意'))),
          ]),
        ],
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color, this.filled = false});
  final String text;
  final Color color;
  final bool filled;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: filled ? color.withValues(alpha: .13) : Colors.transparent, borderRadius: BorderRadius.circular(7), border: filled ? null : Border.all(color: color.withValues(alpha: .45))),
    child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.icon, required this.label, required this.value, this.highlight = false});
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: highlight ? AppColors.interactive : AppColors.textMuted),
    const SizedBox(width: 8),
    SizedBox(width: 48, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
    Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: highlight ? AppColors.interactive : AppColors.ink))),
  ]);
}
