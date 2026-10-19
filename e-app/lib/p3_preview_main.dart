import 'package:flutter/material.dart';

import 'features/enterprise/interview/device_check_page.dart';
import 'features/enterprise/interview/interview_entrance_page.dart';
import 'features/enterprise/schedule/interview_schedule_page.dart';
import 'features/enterprise/schedule/reschedule_review_page.dart';
import 'theme/app_theme.dart';

/// P3 预览入口（独立文件，不影响 main.dart 与 P1/P2 预览入口）。
///
/// 运行方式：
///   flutter run -t lib/p3_preview_main.dart -d emulator-5554
///
/// 覆盖模块三 + 模块四全部 7 个功能点：
/// 1. 面试日程列表（时间轴 + 日期条，面试日程 tab）
/// 2. 发起面试邀约（日程页右下角按钮，表单弹层）
/// 3. 面试官日历忙闲（日程页右上角"面试官日历"）
/// 4. 自助改期记录与审批（改期审批 tab）
/// 5. 面试入口页（场次上下文/须知/同意，面试入口 tab）
/// 6. 设备检测页（绿黄红灯模拟检测，设备检测 tab / 入口页"准备就绪"进入）
/// 7. 实操环境预加载（入口页底部"在线实操环境预加载"）
///
/// 页面全部使用本地 Mock 数据，不发起任何真实网络请求。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const P3PreviewApp());
}

class P3PreviewApp extends StatelessWidget {
  const P3PreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P3 预览 - 面试调度与入口',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const P3PreviewShell(),
    );
  }
}

class P3PreviewShell extends StatefulWidget {
  const P3PreviewShell({super.key});

  @override
  State<P3PreviewShell> createState() => _P3PreviewShellState();
}

class _P3PreviewShellState extends State<P3PreviewShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [
      InterviewSchedulePage(),
      InterviewEntrancePage(),
      DeviceCheckPage(),
      RescheduleReviewPage(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: '面试日程'),
          NavigationDestination(icon: Icon(Icons.login_outlined), selectedIcon: Icon(Icons.login), label: '面试入口'),
          NavigationDestination(icon: Icon(Icons.sensors_outlined), selectedIcon: Icon(Icons.sensors), label: '设备检测'),
          NavigationDestination(icon: Icon(Icons.event_repeat_outlined), selectedIcon: Icon(Icons.event_repeat), label: '改期审批'),
        ],
      ),
    );
  }
}
