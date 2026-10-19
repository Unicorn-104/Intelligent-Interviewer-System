import 'package:flutter/material.dart';

import 'features/enterprise/jobs/jobs_page.dart';
import 'features/enterprise/notification/notification_templates_page.dart';
import 'features/enterprise/talent/talent_page.dart';
import 'theme/app_theme.dart';

/// P1 预览入口（独立文件，不影响现有 main.dart 的登录/主流程）。
///
/// 运行方式：
///   flutter run -t lib/p1_preview_main.dart -d emulator-5554
///
/// 页面全部使用本地 Mock 数据，不发起任何真实网络请求。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const P1PreviewApp());
}

class P1PreviewApp extends StatelessWidget {
  const P1PreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P1 预览 - 岗位/人才/通知模板',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const P1PreviewShell(),
    );
  }
}

class P1PreviewShell extends StatefulWidget {
  const P1PreviewShell({super.key});

  @override
  State<P1PreviewShell> createState() => _P1PreviewShellState();
}

class _P1PreviewShellState extends State<P1PreviewShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [
      JobsPage(),
      TalentPage(),
      NotificationTemplatesPage(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work), label: '岗位管理'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: '人才库'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: '通知模板'),
        ],
      ),
    );
  }
}
