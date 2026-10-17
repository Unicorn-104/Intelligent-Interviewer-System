import 'package:flutter/material.dart';

/// 模块四：面试入口与监控 + 模块五面试执行 - 主页面（占位）。
///
/// TODO(P3/P4): 面试入场（设备检测）/AI 面试监控/HR 协同提词/回放，
/// 数据源见 lib/api/interview_room_api.dart 与 lib/api/practice_api.dart
/// （当前均为占位函数，不发真实请求）。
class InterviewPage extends StatelessWidget {
  const InterviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('面试入口与监控')),
      body: const Center(child: Text('面试入口与监控 - 待开发')),
    );
  }
}
