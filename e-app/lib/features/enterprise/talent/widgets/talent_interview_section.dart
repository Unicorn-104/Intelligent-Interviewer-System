import 'package:flutter/material.dart';

import '../../../../widgets/page_states.dart';
import '../../../../widgets/skeleton_list.dart';
import '../data/talent_detail_data_source.dart';
import '../../schedule/interview_appointment_detail_page.dart';

class TalentInterviewSection extends StatefulWidget {
  const TalentInterviewSection({
    super.key,
    required this.candidateId,
    required this.source,
    this.revision = 0,
  });
  final int? candidateId;
  final TalentDetailDataSource source;
  final int revision;
  @override
  State<TalentInterviewSection> createState() => _TalentInterviewSectionState();
}

class _TalentInterviewSectionState extends State<TalentInterviewSection> {
  bool _interviewLoading = false, _tooManyInterviews = false;
  String? _interviewError;
  List<Map<String, dynamic>>? _interviews;
  DateTimeRange? _interviewRange;
  int _interviewRequest = 0;
  @override
  void initState() {
    super.initState();
    _loadInterviews();
  }

  @override
  void didUpdateWidget(covariant TalentInterviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      _loadInterviews();
    }
  }

  String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _chooseInterviewRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _interviewRange,
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() => _interviewRange = selected);
    await _loadInterviews();
  }

  Future<void> _loadInterviews() async {
    final request = ++_interviewRequest;
    setState(() {
      _interviewLoading = true;
      _interviewError = null;
      _tooManyInterviews = false;
    });
    try {
      final candidateId = int.tryParse('${widget.candidateId}');
      if (candidateId == null) {
        throw const FormatException('候选人数据缺少 ID');
      }
      final range = _interviewRange;
      final from = range == null ? null : '${_date(range.start)} 00:00:00';
      final to = range == null ? null : '${_date(range.end)} 23:59:59';
      const pageSize = 50;
      final first = List<Map<String, dynamic>>.of(
        await widget.source.loadInterviews(
          pageNum: 1,
          pageSize: pageSize,
          from: from,
          to: to,
        ),
      );
      if (first.length > pageSize) {
        throw const FormatException('分页响应异常');
      }
      if (first.length == pageSize) {
        final second = await widget.source.loadInterviews(
          pageNum: 2,
          pageSize: pageSize,
          from: from,
          to: to,
        );
        if (second.length > pageSize) {
          throw const FormatException('分页响应异常');
        }
        first.addAll(second);
        if (second.length == pageSize) {
          // 探测第 101 条；请求异常直接进入 catch，绝不误报超量。
          final probe = await widget.source.loadInterviews(
            pageNum: 3,
            pageSize: pageSize,
            from: from,
            to: to,
          );
          if (probe.isNotEmpty) {
            if (!mounted || request != _interviewRequest) {
              return;
            }
            setState(() {
              _interviews = null;
              _tooManyInterviews = true;
            });
            return;
          }
        }
      }
      if (!mounted || request != _interviewRequest) {
        return;
      }
      setState(
        () => _interviews = first
            .where(
              (item) => int.tryParse('${item['candidateId']}') == candidateId,
            )
            .toList(),
      );
    } catch (_) {
      if (!mounted || request != _interviewRequest) {
        return;
      }
      setState(() {
        _interviews = null;
        _interviewError = '请求失败，请重试';
      });
    } finally {
      if (mounted && request == _interviewRequest) {
        setState(() => _interviewLoading = false);
      }
    }
  }

  Widget _buildInterviewSection() {
    final range = _interviewRange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle('面试安排')),
            IconButton(
              tooltip: '刷新面试安排',
              onPressed: _interviewLoading ? null : _loadInterviews,
              icon: const Icon(Icons.refresh),
            ),
            TextButton.icon(
              onPressed: _chooseInterviewRange,
              icon: const Icon(Icons.date_range, size: 18),
              label: const Text('筛选日期'),
            ),
          ],
        ),
        if (range != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${_date(range.start)} ~ ${_date(range.end)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _interviewRange = null);
                    _loadInterviews();
                  },
                  child: const Text('清除筛选'),
                ),
              ],
            ),
          ),
        if (_interviewLoading)
          const SkeletonList(rows: 2)
        else if (_interviewError != null)
          PageMessage(
            icon: Icons.cloud_off_outlined,
            title: '加载失败',
            message: _interviewError!,
            actionLabel: '重试',
            onAction: _loadInterviews,
          )
        else if (_tooManyInterviews)
          PageMessage(
            icon: Icons.filter_alt_outlined,
            title: '数据量过大，请缩小范围',
            message: '面试记录超过 100 条，请选择更短的日期范围',
            actionLabel: '选择日期范围',
            onAction: _chooseInterviewRange,
          )
        else if (_interviews?.isEmpty ?? true)
          const Card(
            child: Padding(padding: EdgeInsets.all(16), child: Text('暂无面试安排')),
          )
        else
          for (final item in _interviews!)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  title: Text('${item['positionTitle'] ?? '岗位未填写'}'),
                  subtitle: Text('开始：${item['startTime'] ?? '未填写'}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          InterviewAppointmentDetailPage(appointment: item),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => _buildInterviewSection();
}
