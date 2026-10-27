import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../data/interview_api.dart';
import '../domain/interview_schedule.dart';

class RescheduleRequestAction extends StatefulWidget {
  const RescheduleRequestAction({
    super.key,
    required this.api,
    required this.token,
    required this.appointment,
  });
  final InterviewApi api;
  final String token;
  final InterviewSchedule appointment;
  @override
  State<RescheduleRequestAction> createState() =>
      _RescheduleRequestActionState();
}

class _RescheduleRequestActionState extends State<RescheduleRequestAction> {
  bool _busy = false, _uncertain = false, _checking = true;
  String? _status, _error;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _checking = true);
    try {
      final row = await widget.api.findOwnReschedule(
        widget.token,
        widget.appointment.appointmentId,
      );
      if (!mounted) return;
      setState(() {
        _status = row?['status']?.toString();
        _uncertain = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _uncertain = true;
          _error = error is ApiException ? error.message : '申请状态暂不可用';
        });
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _request() async {
    if (_busy || _checking || _uncertain || _status == 'pending') return;
    final original =
        DateTime.tryParse(
          (widget.appointment.startAt ?? '').replaceFirst(' ', 'T'),
        ) ??
        DateTime.now().add(const Duration(days: 1));
    var selected = original;
    var reason = '';
    final request = await showDialog<(DateTime, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          scrollable: true,
          title: const Text('申请改期'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.appointment.positionTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text('当前时间：${widget.appointment.startAt ?? '—'}'),
              Wrap(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
                    ),
                    onPressed: () async {
                      final day = DateTime(
                        selected.year,
                        selected.month,
                        selected.day,
                      );
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: day.isBefore(DateTime.now())
                            ? DateTime.now()
                            : day,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        refresh(
                          () => selected = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            selected.hour,
                            selected.minute,
                          ),
                        );
                      }
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}',
                    ),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selected),
                      );
                      if (picked != null) {
                        refresh(
                          () => selected = DateTime(
                            selected.year,
                            selected.month,
                            selected.day,
                            picked.hour,
                            picked.minute,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              TextField(
                onChanged: (value) => reason = value,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(labelText: '改期原因（必填）'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (reason.trim().isNotEmpty) {
                  Navigator.pop(dialogContext, (selected, reason.trim()));
                }
              },
              child: const Text('提交申请'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || request == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.submitReschedule(
        widget.token,
        widget.appointment.appointmentId,
        request.$1,
        request.$2,
      );
      if (!mounted) return;
      setState(() {
        _status = 'pending';
        _uncertain = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('改期申请已发送，等待企业处理')));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _uncertain = error.code == null || error.statusCode == null;
        _error = _uncertain ? '提交结果待核对，请刷新申请状态，不要重复提交' : error.message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const ListTile(
        leading: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('正在核对改期申请…'),
      );
    }
    if (_status == 'pending' && !_uncertain) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.hourglass_top),
          title: const Text('改期申请已提交'),
          subtitle: const Text('企业处理后会通过消息通知您。'),
          trailing: IconButton(
            tooltip: '刷新申请状态',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ),
      );
    }
    if (_status == 'approved' && !_uncertain) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.check_circle_outline),
          title: Text('改期申请已同意'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_status == 'rejected')
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('上次改期申请未通过，可重新申请。'),
          ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_uncertain)
          OutlinedButton.icon(
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新申请状态'),
          )
        else
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _request,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.event_repeat),
            label: Text(_busy ? '提交中…' : '申请改期'),
          ),
      ],
    );
  }
}
