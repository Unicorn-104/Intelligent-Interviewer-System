import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../theme/app_theme.dart';
import '../../schedule/data/reschedule_review_data_source.dart';

class RescheduleChatCard extends StatefulWidget {
  const RescheduleChatCard({
    super.key,
    required this.data,
    required this.peerUserId,
    required this.canReview,
    required this.source,
    required this.onChanged,
  });
  final Map<String, dynamic> data;
  final int? peerUserId;
  final bool canReview;
  final RescheduleReviewDataSource source;
  final VoidCallback onChanged;
  @override
  State<RescheduleChatCard> createState() => _RescheduleChatCardState();
}

class _RescheduleChatCardState extends State<RescheduleChatCard> {
  bool _busy = false, _uncertain = false;
  late String _status = widget.data['status']?.toString() ?? 'pending';
  int? get _requestId => int.tryParse('${widget.data['requestId']}');
  String _text(String key, [String fallback = '—']) {
    final value = key == 'reviewNote'
        ? _reviewNote ?? widget.data[key]
        : widget.data[key];
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String? _reviewNote;

  @override
  void didUpdateWidget(covariant RescheduleChatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final status = widget.data['status']?.toString() ?? 'pending';
    final differentRequest =
        oldWidget.data['requestId'] != widget.data['requestId'];
    if (differentRequest || status != 'pending' || _status == 'pending') {
      _status = status;
      _reviewNote = widget.data['reviewNote']?.toString();
      if (differentRequest || status != 'pending') _uncertain = false;
    }
  }

  void _applyDetail(Map<String, dynamic> detail) {
    _status = detail['status'].toString();
    _reviewNote = detail['reviewNote']?.toString();
    _uncertain = false;
  }

  Future<void> _review(String decision) async {
    final id = _requestId, peer = widget.peerUserId;
    if (_busy ||
        _uncertain ||
        _status != 'pending' ||
        !widget.canReview ||
        id == null ||
        peer == null) {
      return;
    }
    setState(() => _busy = true);
    var submitting = false;
    try {
      var note = '';
      var missingReason = false;
      final value = await showDialog<String>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, refresh) => AlertDialog(
            scrollable: true,
            title: Text(decision == 'approved' ? '同意改期申请' : '拒绝改期申请'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_text('candidateName', '求职者')}申请将“${_text('positionName', '面试')}”改至：\n${_text('newStartTime')}',
                ),
                if (decision == 'rejected') ...[
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (value) => note = value,
                    decoration: InputDecoration(
                      labelText: '拒绝原因（必填）',
                      errorText: missingReason ? '请填写拒绝原因' : null,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  if (decision == 'rejected' && note.trim().isEmpty) {
                    refresh(() => missingReason = true);
                    return;
                  }
                  Navigator.pop(context, note.trim());
                },
                child: Text(decision == 'approved' ? '确认同意' : '确认拒绝'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || value == null) return;
      final detail = await widget.source.detail(id, candidateUserId: peer);
      if (!mounted) return;
      if (detail['status'] != 'pending') {
        setState(() => _applyDetail(detail));
        widget.onChanged();
        return;
      }
      submitting = true;
      final result = await widget.source.review(
        id,
        decision,
        note: value.isEmpty ? null : value,
      );
      if (!mounted) return;
      setState(() {
        _status = result.status;
        _reviewNote = result.reviewNote;
        _uncertain = false;
      });
      widget.onChanged();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(decision == 'approved' ? '已同意改期申请' : '已拒绝改期申请'),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      // 读取详情失败不产生审批；只有已发送且结果不明的写请求才需要人工核对。
      final uncertain =
          submitting && !(error is ApiException && error.code != null);
      setState(() => _uncertain = uncertain);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              uncertain
                  ? '审批结果待核对，请刷新卡片确认，不会自动重复提交'
                  : RescheduleReviewDataSource.errorMessage(error),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final id = _requestId, peer = widget.peerUserId;
    if (id == null || peer == null || _busy) return;
    setState(() => _busy = true);
    try {
      final detail = await widget.source.detail(id, candidateUserId: peer);
      if (!mounted) return;
      final status = detail['status']?.toString() ?? 'pending';
      if (status != 'pending') {
        setState(() {
          _applyDetail(detail);
        });
        widget.onChanged();
      } else {
        final resume = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('申请仍待处理'),
            content: const Text('服务端确认申请仍待处理。核对后可重新选择操作，不会自动重复审批。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('已核对'),
              ),
            ],
          ),
        );
        if (mounted && resume == true) setState(() => _uncertain = false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('暂时无法核对，请稍后刷新')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _status == 'approved' || _status == 'changed'
        ? AppColors.green
        : _status == 'rejected'
        ? Theme.of(context).colorScheme.error
        : AppColors.interactive;
    final heading = switch (_status) {
      'changed' => '企业已调整面试时间',
      'approved' => '改期申请已同意',
      'rejected' => '改期申请已拒绝',
      _ => '求职者申请改期',
    };
    return SizedBox(
      width: 268,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_repeat, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  heading,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _text('candidateName', '求职者'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(_text('positionName', '面试安排')),
          const SizedBox(height: 6),
          Text(
            '原时间：${_text('originalStartTime')} ～ ${_text('originalEndTime')}',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            '${_status == 'rejected' || _status == 'pending' ? '申请时间' : '新时间'}：${_text('newStartTime')} ～ ${_text('newEndTime')}',
            style: const TextStyle(fontSize: 12),
          ),
          if (_text('reason', '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                '原因：${_text('reason')}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          if (_text('reviewNote', '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                '审批说明：${_text('reviewNote')}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          if (_status == 'pending' && widget.canReview) ...[
            const SizedBox(height: 10),
            if (_uncertain)
              OutlinedButton.icon(
                onPressed: _busy ? null : _verify,
                icon: const Icon(Icons.refresh),
                label: const Text('核对申请状态'),
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _busy ? null : () => _review('rejected'),
                    child: const Text('拒绝'),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : () => _review('approved'),
                    child: Text(_busy ? '处理中…' : '同意'),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
