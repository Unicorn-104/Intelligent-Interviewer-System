import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import 'device_check_page.dart';
import 'mock_interview.dart';
import 'practice_preload_page.dart';

/// 模块四：面试入口与准备 - 面试入口页（P3）。
///
/// 依据《业务功能分析》UC-10 步骤3-8：
/// 鉴权通过后加载场次元数据（岗位/面试官/时长/模式）渲染引导页面；
/// 候选人确认面试须知后点击"准备就绪，进入面试"，会话状态标记"已就绪"，
/// 控制权交接至模块五。
/// 数据来源：本地 Mock 数据（mock_interview.dart），
/// TODO: P7阶段替换为真实接口（lib/api/interview_room_api.dart 的
/// getSessionContext / confirmConsent / startSession）。
class InterviewEntrancePage extends StatefulWidget {
  const InterviewEntrancePage({super.key});

  @override
  State<InterviewEntrancePage> createState() => _InterviewEntrancePageState();
}

class _InterviewEntrancePageState extends State<InterviewEntrancePage> {
  Map<String, dynamic>? _context;
  bool _loading = true;
  bool _consent = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 模拟加载场次上下文（鉴权 + 元数据）。
  /// TODO: P7阶段替换为真实接口（interview_room_api.getSessionContext）。
  Future<void> _load() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _context = Map<String, dynamic>.from(mockSessionContext);
      _loading = false;
    });
  }

  /// 模拟确认面试须知并进入设备检测。
  /// TODO: P7阶段替换为真实接口（interview_room_api.confirmConsent）。
  Future<void> _next() async {
    final messenger = ScaffoldMessenger.of(context);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('面试须知已确认（模拟）')));
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeviceCheckPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(title: const Text('面试入口')),
        body: _loading ? const SkeletonList(rows: 3) : _buildBody(_context!),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> ctx) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // 场次上下文卡片
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.videocam_outlined,
                        size: 18,
                        color: AppColors.interactive,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${ctx['positionName']}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoLine(label: '候选人', value: '${ctx['candidateName']}'),
                _InfoLine(label: '面试官', value: '${ctx['interviewerName']}'),
                _InfoLine(
                  label: '面试时间',
                  value: '${ctx['startTime']}（${ctx['duration']} 分钟）',
                ),
                _InfoLine(label: '面试模式', value: '${ctx['mode']}'),
                _InfoLine(label: '会议链接', value: '${ctx['meetingLink']}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const SectionTitle('面试须知'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final notice in mockInterviewNotices) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Icon(
                          Icons.circle,
                          size: 6,
                          color: AppColors.interactive,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          notice,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                // 同意勾选（UC-10 步骤8）
                Row(
                  children: [
                    Checkbox(
                      value: _consent,
                      activeColor: AppColors.interactive,
                      onChanged: (v) => setState(() => _consent = v ?? false),
                    ),
                    Expanded(
                      child: Text(
                        '我已阅读并确认以上面试须知',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _consent ? _next : null,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('准备就绪，进行设备检测'),
        ),
        if (ctx['hasPractice'] == true) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PracticePreloadPage()),
            ),
            icon: const Icon(Icons.terminal_outlined),
            label: const Text('在线实操环境预加载'),
          ),
        ],
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
