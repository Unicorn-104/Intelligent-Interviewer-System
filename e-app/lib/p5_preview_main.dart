import 'package:flutter/material.dart';

import 'features/enterprise/notification/assistant_placeholder_page.dart';
import 'features/enterprise/notification/message_center_page.dart';
import 'features/enterprise/notification/notice_page.dart';
import 'features/enterprise/notification/notification_log_page.dart';
import 'features/enterprise/notification/survey_result_page.dart';
import 'theme/app_theme.dart';

/// P5 预览入口（独立文件，不影响 main.dart 与 P1-P4 预览入口）。
///
/// 运行方式：
///   flutter run -t lib/p5_preview_main.dart -d emulator-5554
///
/// 覆盖模块六全部功能点：
/// 1. 通知发送日志（检索/场景筛选/送达率·打开率·点击率统计卡片，通知日志 tab）
/// 2. 满意度调研（维度环形评分 + CustomPaint 评分分布柱状图 + 文字反馈，调研结果 tab）
/// 3. IM 消息中心（会话列表/聊天气泡/快捷回复，消息中心 tab）
/// 4. 公告（置顶 listTop/已读未读/全部已读，公告 tab）
/// 5. 7×24 AI 助手入口（候选人侧功能，企业端占位，AI 助手 tab）
///
/// 页面全部使用本地 Mock 数据，不发起任何真实网络请求。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const P5PreviewApp());
}

class P5PreviewApp extends StatelessWidget {
  const P5PreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P5 预览 - 通知与反馈中心',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const P5PreviewShell(),
    );
  }
}

class P5PreviewShell extends StatefulWidget {
  const P5PreviewShell({super.key});

  @override
  State<P5PreviewShell> createState() => _P5PreviewShellState();
}

class _P5PreviewShellState extends State<P5PreviewShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [
      NotificationLogPage(),
      SurveyResultPage(),
      MessageCenterPage(),
      NoticePage(),
      AssistantPlaceholderPage(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: '通知日志'),
          NavigationDestination(icon: Icon(Icons.poll_outlined), selectedIcon: Icon(Icons.poll), label: '调研结果'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: '消息中心'),
          NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: '公告'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), selectedIcon: Icon(Icons.smart_toy), label: 'AI 助手'),
        ],
      ),
    );
  }
}
