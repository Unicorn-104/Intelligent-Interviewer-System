import 'package:flutter/material.dart';

import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import '../schedule/interview_appointment_detail_page.dart';
import 'data/job_detail_data_source.dart';
import 'models/job_detail_view_data.dart';

class JobInterviewsPage extends StatefulWidget {
  const JobInterviewsPage({
    super.key,
    required this.positionId,
    required this.positionTitle,
    this.source = const JobDetailDataSource(),
    this.initialRange,
    this.onRangeChanged,
    this.detailBuilder,
  });
  final int positionId;
  final String positionTitle;
  final JobDetailDataSource source;
  final DateTimeRange? initialRange;
  final ValueChanged<DateTimeRange?>? onRangeChanged;
  final Widget Function(Map<String, dynamic>)? detailBuilder;

  @override
  State<JobInterviewsPage> createState() => _JobInterviewsPageState();
}

class _JobInterviewsPageState extends State<JobInterviewsPage> {
  DateTimeRange? _range;
  bool _loading = true;
  bool _tooMany = false;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange;
    _load();
  }

  String _date(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (!mounted || range == null) {
      return;
    }
    setState(() => _range = range);
    widget.onRangeChanged?.call(range);
    await _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _tooMany = false;
    });
    try {
      if (widget.positionId <= 0) {
        throw const FormatException('岗位数据缺少有效ID');
      }
      final from = _range == null ? null : '${_date(_range!.start)} 00:00:00';
      final to = _range == null ? null : '${_date(_range!.end)} 23:59:59';
      Future<List<Map<String, dynamic>>> page(int number) async {
        final rows = await widget.source.loadInterviews(
          pageNum: number,
          pageSize: 50,
          from: from,
          to: to,
        );
        if (rows.length > 50) {
          throw const FormatException('面试分页响应异常');
        }
        return rows;
      }

      final first = await page(1);
      final rows = [...first];
      if (first.length == 50) {
        final second = await page(2);
        rows.addAll(second);
        if (second.length == 50) {
          final probe = await page(3);
          if (probe.isNotEmpty) {
            if (!mounted || request != _request) {
              return;
            }
            setState(() {
              _tooMany = true;
              _rows = const [];
            });
            return;
          }
        }
      }
      if (!mounted || request != _request) {
        return;
      }
      setState(
        () => _rows = rows
            .where(
              (row) => jobPositiveId(row['positionId']) == widget.positionId,
            )
            .toList(),
      );
    } catch (error) {
      if (!mounted || request != _request) {
        return;
      }
      setState(() {
        _error = jobDetailError(error);
        _rows = const [];
      });
    } finally {
      if (mounted && request == _request) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.positionTitle} · 面试安排')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                key: const Key('job-interview-range'),
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range),
                label: Text(
                  _range == null
                      ? '选择日期范围'
                      : '${_date(_range!.start)} ~ ${_date(_range!.end)}',
                ),
              ),
              if (_range != null)
                TextButton(
                  key: const Key('job-interview-clear'),
                  onPressed: () {
                    setState(() => _range = null);
                    widget.onRangeChanged?.call(null);
                    _load();
                  },
                  child: const Text('清除筛选'),
                ),
            ],
          ),
        ),
        Expanded(child: _body()),
      ],
    ),
  );

  Widget _body() {
    if (_loading) {
      return const SkeletonList(rows: 4);
    }
    if (_error != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '面试安排加载失败',
        message: _error!,
        onAction: _load,
      );
    }
    if (_tooMany) {
      return PageMessage(
        icon: Icons.filter_alt_outlined,
        title: '数据量过大，请缩小日期范围',
        message: '面试记录超过100条，请选择更短的日期范围',
        actionLabel: '选择日期范围',
        onAction: _pickRange,
      );
    }
    if (_rows.isEmpty) {
      return PageMessage(
        icon: Icons.event_busy_outlined,
        title: '暂无面试安排',
        message: '当前岗位和日期范围内没有面试记录',
        actionLabel: '刷新',
        onAction: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: _rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final appointment = _rows[index];
          return Card(
            child: ListTile(
              title: Text(
                jobValue(appointment['candidateName'], fallback: '候选人未填写'),
              ),
              subtitle: Text('开始：${jobValue(appointment['startTime'])}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      widget.detailBuilder?.call(appointment) ??
                      InterviewAppointmentDetailPage(appointment: appointment),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
