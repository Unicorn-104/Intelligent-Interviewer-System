import 'package:flutter/material.dart';

/// 模块六：通知与反馈中心 - 主页面（占位）。
///
/// TODO(P1/P5): 通知模板/发送日志/满意度调研/消息中心/7×24 AI 助手入口，
/// 数据源见 lib/api/notification_api.dart、lib/api/survey_api.dart、
/// lib/api/message_api.dart、lib/api/assistant_api.dart
/// （当前均为占位函数，不发真实请求）。
class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知与反馈中心')),
      body: const Center(child: Text('通知与反馈中心 - 待开发')),
    );
  }
}
