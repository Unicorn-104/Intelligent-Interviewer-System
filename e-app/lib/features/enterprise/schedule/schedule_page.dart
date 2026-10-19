import 'package:flutter/material.dart';

/// 模块三：面试调度与日程 - 主页面（占位）。
///
/// TODO(P3): 面试日程/邀约发起/面试官日历忙闲/改期管理，
/// 数据源见 lib/api/schedule_api.dart（当前均为占位函数，不发真实请求）。
class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('面试调度与日程')),
      body: const Center(child: Text('面试调度与日程 - 待开发')),
    );
  }
}
