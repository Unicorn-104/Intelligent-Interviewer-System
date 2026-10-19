import 'package:flutter/material.dart';

import 'features/enterprise/screening/greeting_page.dart';
import 'features/enterprise/screening/screening_task_list_page.dart';
import 'features/enterprise/screening/shortlist_review_page.dart';
import 'theme/app_theme.dart';

/// P2 预览入口（独立文件，不影响现有 main.dart 与 p1_preview_main.dart）。
///
/// 运行方式：
///   flutter run -t lib/p2_preview_main.dart -d emulator-5554
///
/// 覆盖模块二全部 6 个功能点：
/// 1. 筛选任务列表/触发（筛选任务 tab）
/// 2. 匹配度评分与维度明细（任务 → 结果 → 评分明细，四维雷达 + 加权条）
/// 3. 短名单 Top N 降序（结果页）
/// 4. AI 推荐报告（评分明细 → 推荐报告）
/// 5. 个性化招呼语（招呼语 tab / 结果页右上角入口）
/// 6. HR 复核（短名单复核 tab）
///
/// 页面全部使用本地 Mock 数据，不发起任何真实网络请求。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const P2PreviewApp());
}

class P2PreviewApp extends StatelessWidget {
  const P2PreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P2 预览 - AI 初筛与短名单',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const P2PreviewShell(),
    );
  }
}

class P2PreviewShell extends StatefulWidget {
  const P2PreviewShell({super.key});

  @override
  State<P2PreviewShell> createState() => _P2PreviewShellState();
}

class _P2PreviewShellState extends State<P2PreviewShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [
      ScreeningTaskListPage(),
      ShortlistReviewPage(),
      GreetingPage(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.playlist_add_check_outlined), selectedIcon: Icon(Icons.playlist_add_check), label: '筛选任务'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: '短名单复核'),
          NavigationDestination(icon: Icon(Icons.waving_hand_outlined), selectedIcon: Icon(Icons.waving_hand), label: '招呼语'),
        ],
      ),
    );
  }
}
