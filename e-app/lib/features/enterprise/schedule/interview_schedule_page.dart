import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../api/schedule_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import 'interview_appointment_detail_page.dart';
import 'interviewer_calendar_page.dart';
import 'mock_schedule.dart';

String _labelDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  final today = DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final difference = day
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  final suffix = switch (difference) {
    0 => ' 今天',
    1 => ' 明天',
    _ => '',
  };
  return '${date.month}/${date.day}$suffix';
}

/// 正式日程只显示服务端真实记录；演示排期保留为独立入口。
class RealInterviewSchedulePage extends StatefulWidget {
  const RealInterviewSchedulePage({super.key});

  @override
  State<RealInterviewSchedulePage> createState() =>
      _RealInterviewSchedulePageState();
}

class _RealInterviewSchedulePageState extends State<RealInterviewSchedulePage> {
  bool _loading = true;
  bool _tooMany = false;
  String? _error;
  String? _selectedDate;
  DateTimeRange? _range;
  int _request = 0;
  List<Map<String, dynamic>>? _rows;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (range == null || !mounted) return;
    setState(() {
      _range = range;
      _selectedDate = null;
    });
    await _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _tooMany = false;
      _error = null;
    });
    try {
      final range = _range;
      final from = range == null
          ? null
          : '${_formatDate(range.start)} 00:00:00';
      final to = range == null ? null : '${_formatDate(range.end)} 23:59:59';
      const pageSize = 50;
      final rows = await listInterviews(
        pageNum: 1,
        pageSize: pageSize,
        from: from,
        to: to,
      );
      if (rows.length > pageSize) throw const FormatException('分页响应异常');
      if (rows.length == pageSize) {
        final second = await listInterviews(
          pageNum: 2,
          pageSize: pageSize,
          from: from,
          to: to,
        );
        if (second.length > pageSize) throw const FormatException('分页响应异常');
        rows.addAll(second);
        if (second.length == pageSize) {
          // 第 3 页第 1 条即第 101 条；探测失败时只显示请求错误。
          final probe = await listInterviews(
            pageNum: 3,
            pageSize: pageSize,
            from: from,
            to: to,
          );
          if (probe.isNotEmpty) {
            if (!mounted || request != _request) return;
            setState(() {
              _tooMany = true;
              _rows = null;
            });
            return;
          }
        }
      }
      if (!mounted || request != _request) return;
      setState(() => _rows = rows);
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _rows = null;
        _error = error is ApiException ? error.message : '请求失败，请重试';
      });
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dates =
        (_rows ?? const <Map<String, dynamic>>[])
            .map((row) => '${row['startTime']}'.split(' ').first)
            .where((date) => DateTime.tryParse(date) != null)
            .toSet()
            .toList()
          ..sort();
    return Scaffold(
      appBar: MediaQuery.orientationOf(context) == Orientation.landscape
          ? null
          : AppBar(title: const Text('面试日程')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _range == null
                        ? '全部日期'
                        : '${_formatDate(_range!.start)} ~ ${_formatDate(_range!.end)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range),
                  label: const Text('日期范围'),
                ),
                if (_range != null)
                  IconButton(
                    tooltip: '清除筛选',
                    onPressed: () {
                      setState(() => _range = null);
                      _load();
                    },
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
          ),
          if (dates.isNotEmpty && MediaQuery.sizeOf(context).height >= 450)
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ChoiceChip(
                    label: const Text('全部'),
                    selected: _selectedDate == null,
                    onSelected: (_) => setState(() => _selectedDate = null),
                  ),
                  for (final date in dates)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(_labelDate(date)),
                        selected: _selectedDate == date,
                        onSelected: (_) => setState(() => _selectedDate = date),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) return const SkeletonList(rows: 4);
    if (_error != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '加载失败',
        message: _error!,
        actionLabel: '重试',
        onAction: _load,
      );
    }
    if (_tooMany) {
      return PageMessage(
        icon: Icons.filter_alt_outlined,
        title: '数据量过大，请缩小范围',
        message: '面试记录超过 100 条，请选择更短的日期范围',
        actionLabel: '选择日期范围',
        onAction: _pickRange,
      );
    }
    final rows = (_rows ?? const <Map<String, dynamic>>[])
        .where(
          (row) =>
              _selectedDate == null ||
              '${row['startTime']}'.startsWith(_selectedDate!),
        )
        .toList();
    if (rows.isEmpty) {
      return const PageMessage(
        icon: Icons.event_busy_outlined,
        title: '暂无面试安排',
        message: '当前日期范围内暂无真实面试记录',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = rows[index];
          return Card(
            child: ListTile(
              title: Text('${item['candidateName'] ?? '候选人未填写'}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${item['positionTitle'] ?? '岗位未填写'}'),
                  Text('开始：${item['startTime'] ?? '时间未填写'}'),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      InterviewAppointmentDetailPage(appointment: item),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 模块三：智能预约调度 - 面试日程列表页（P3，时间轴 + 日期条）。
///
/// 依据《业务功能分析》UC-07：面试记录含时间、会议链接与状态；
/// 面试前 24h/1h 自动提醒（步骤11）。
/// 数据来源：本地 Mock 数据（mock_schedule.dart），
/// TODO: P7阶段替换为真实接口（lib/api/schedule_api.dart 的
/// listInterviews / sendInterviewInvite / sendInterviewReminder）。
/// 历史预览数据保留为独立演示页面，不会混入真实日程。
class InterviewSchedulePage extends StatefulWidget {
  const InterviewSchedulePage({super.key});

  @override
  State<InterviewSchedulePage> createState() =>
      _DemoInterviewSchedulePageState();
}

class _DemoInterviewSchedulePageState extends State<InterviewSchedulePage> {
  List<Map<String, dynamic>>? _interviews;
  bool _loading = true;
  String? _selectedDate; // null=全部日期

  List<String> get _dates =>
      mockInterviews.map((row) => '${row['date']}').toSet().toList()..sort();

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 模拟加载面试日程。
  /// TODO: P7阶段替换为真实接口（schedule_api.listInterviews）。
  Future<void> _load() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _interviews =
          mockInterviews
              .where(
                (item) =>
                    _selectedDate == null || item['date'] == _selectedDate,
              )
              .toList()
            ..sort(
              (a, b) => '${a['date']} ${a['time']}'.compareTo(
                '${b['date']} ${b['time']}',
              ),
            );
      _loading = false;
    });
  }

  /// 模拟发起面试邀约。
  /// TODO: P7阶段替换为真实接口（schedule_api.sendInterviewInvite）。
  Future<void> _openInvite() async {
    final messenger = ScaffoldMessenger.of(context);
    final formKey = GlobalKey<FormState>();
    final candidate = TextEditingController();
    final interviewer = TextEditingController();
    final duration = ValueNotifier<int>(45);
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('发起面试邀约', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                '系统将自动匹配面试官忙闲并生成专属预约链接（模拟）',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: candidate,
                decoration: const InputDecoration(labelText: '候选人姓名'),
                validator: (v) => (v == null || v.isEmpty) ? '请输入候选人姓名' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: interviewer,
                decoration: const InputDecoration(labelText: '面试官'),
                validator: (v) => (v == null || v.isEmpty) ? '请输入面试官' : null,
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<int>(
                valueListenable: duration,
                builder: (context, value, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '面试时长：$value 分钟/场',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Slider(
                      value: value.toDouble(),
                      min: 15,
                      max: 90,
                      divisions: 5,
                      label: '$value 分钟',
                      onChanged: (v) => duration.value = v.round(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    setState(() {
                      mockInterviews.add({
                        'aptId': 900 + mockInterviews.length,
                        'candidateName': candidate.text.trim(),
                        'positionName': '高级 Flutter 开发工程师',
                        'interviewerName': interviewer.text.trim(),
                        'date': '2026-10-12',
                        'time': '10:00',
                        'duration': duration.value,
                        'mode': 'AI 面试',
                        'meetingLink':
                            'https://meeting.example.com/99${mockInterviews.length + 1000}',
                        'status': 'upcoming',
                        'round': '一轮',
                      });
                    });
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('发送邀约'),
              ),
            ],
          ),
        ),
      ),
    );
    if (created == true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('面试邀约已发送（模拟），候选人将收到专属预约链接')),
      );
      await _load();
    }
  }

  /// 模拟面试提醒。
  /// TODO: P7阶段替换为真实接口（schedule_api.sendInterviewReminder）。
  Future<void> _remind(Map<String, dynamic> item) async {
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发送提醒'),
        content: Text(
          '向「${item['candidateName']}」发送面试提醒（模拟）？\n面试前 24h / 1h 系统会自动催办。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              messenger.showSnackBar(
                SnackBar(content: Text('已向「${item['candidateName']}」发送提醒（模拟）')),
              );
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('面试日程'),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InterviewerCalendarPage(),
                ),
              ),
              icon: const Icon(Icons.calendar_view_week_outlined, size: 18),
              label: const Text('面试官日历'),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openInvite,
          backgroundColor: AppColors.interactive,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('发起邀约'),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateStrip(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildDateStrip() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        children: [
          _DateChip(
            label: '全部',
            selected: _selectedDate == null,
            onTap: () {
              setState(() => _selectedDate = null);
              _load();
            },
          ),
          for (var i = 0; i < _dates.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _DateChip(
                label: _labelDate(_dates[i]),
                selected: _selectedDate == _dates[i],
                onTap: () {
                  setState(() => _selectedDate = _dates[i]);
                  _load();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const SkeletonList(rows: 4);
    final interviews = _interviews ?? const <Map<String, dynamic>>[];
    if (interviews.isEmpty) {
      return PageMessage(
        icon: Icons.event_busy_outlined,
        title: '暂无面试安排',
        message: '点击右下角"发起邀约"为候选人安排面试',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
        children: [
          for (final item in interviews)
            _TimelineItem(item: item, onRemind: () => _remind(item)),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.interactive : AppColors.hairline,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? AppColors.interactive : AppColors.bodySoft,
              fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

/// 时间轴条目：左侧时间点 + 竖线 + 内容卡片。
class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.item, required this.onRemind});

  final Map<String, dynamic> item;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) {
    final status = item['status'] as String;
    final (statusLabel, statusColor) = switch (status) {
      'today' => ('待面试', AppColors.interactive),
      'upcoming' => ('已预约', AppColors.green),
      'rescheduled' => ('已改期', AppColors.orange),
      _ => ('已完成', AppColors.muted),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧时间轴
          SizedBox(
            width: 76,
            child: Column(
              children: [
                Text(
                  '${item['time']}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_labelDate('${item['date']}')} · ${item['duration']} 分钟',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 竖线与圆点
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(child: Container(width: 2, color: AppColors.hairline)),
            ],
          ),
          const SizedBox(width: 10),
          // 内容卡片
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item['candidateName']}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item['positionName']} · ${item['round']}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '面试官：${item['interviewerName']} · ${item['mode']}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.link, size: 14, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${item['meetingLink']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          TextButton(
                            onPressed: onRemind,
                            child: const Text('提醒'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
