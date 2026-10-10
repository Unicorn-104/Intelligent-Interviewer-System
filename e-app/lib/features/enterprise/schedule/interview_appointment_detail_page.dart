import 'package:flutter/material.dart';

import '../../../api/interview_room_api.dart';
import '../../../theme/app_theme.dart';
import '../interview/interview_workbench_page.dart';

/// 展示面试列表返回的真实场次字段；会议房间 ID 不等于会话 ID。
class InterviewAppointmentDetailPage extends StatefulWidget {
  const InterviewAppointmentDetailPage({super.key, required this.appointment});

  final Map<String, dynamic> appointment;

  @override
  State<InterviewAppointmentDetailPage> createState() =>
      _InterviewAppointmentDetailPageState();
}

class _InterviewAppointmentDetailPageState
    extends State<InterviewAppointmentDetailPage> {
  bool _sessionConfirmed = false;

  @override
  void initState() {
    super.initState();
    _verifySession();
  }

  Future<void> _verifySession() async {
    final sessionId = int.tryParse('${widget.appointment['sessionId']}');
    final appointmentId = int.tryParse(
      '${widget.appointment['appointmentId']}',
    );
    // 只有真实预约 ID 和会话 ID 都匹配，才允许打开仍为演示数据的工作台。
    if (sessionId == null || appointmentId == null) return;
    try {
      final session = await getSessionContext(sessionId);
      if (!mounted) return;
      final actualSessionId = int.tryParse('${session['sessionId']}');
      final actualAppointmentId = int.tryParse('${session['appointmentId']}');
      if (actualSessionId == sessionId &&
          actualAppointmentId == appointmentId) {
        setState(() => _sessionConfirmed = true);
      }
    } catch (_) {
      // 无法验证会话时只展示面试详情，不开启模拟工作台入口。
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.appointment;
    return Scaffold(
      appBar: AppBar(title: const Text('面试详情')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['positionTitle'] ?? '岗位未填写'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _DetailRow('候选人', item['candidateName']),
                  _DetailRow('面试官', item['interviewerName']),
                  _DetailRow('开始时间', item['startTime']),
                  _DetailRow('结束时间', item['endTime']),
                  _DetailRow('面试状态', item['status']),
                  if (item['meetingUrl'] != null)
                    _DetailRow('会议链接', item['meetingUrl']),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_sessionConfirmed)
            FilledButton.icon(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => const Banner(
                    message: '演示数据',
                    location: BannerLocation.topStart,
                    color: AppColors.orange,
                    child: InterviewWorkbenchPage(),
                  ),
                ),
              ),
              icon: const Icon(Icons.mic),
              label: const Text('进入面试工作台（演示数据）'),
            )
          else
            Text(
              '暂无可核实的面试会话，暂不提供工作台入口',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '未填写',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
