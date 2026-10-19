import 'package:flutter/material.dart';

import 'features/enterprise/interview/interview_workbench_page.dart';
import 'features/enterprise/interview/recording_page.dart';
import 'features/enterprise/offer/offer_page.dart';
import 'features/enterprise/review/review_page.dart';
import 'theme/app_theme.dart';

/// P4 预览入口（独立文件，不影响 main.dart 与 P1/P2/P3 预览入口）。
///
/// 运行方式：
///   flutter run -t lib/p4_preview_main.dart -d emulator-5554
///
/// 覆盖模块五全部功能点：
/// 1. 面试执行工作台（AI 实时字幕流 + HR 协同提词建议/采纳/编辑/忽略 +
///    人工接管/结束/异常终止，面试工作台 tab）
/// 2. 面试回放（录播列表/下载码/存储策略，录播回放 tab）
/// 3. 评估报告查看（五维雷达评分卡 + 结构化评语 + 回放链接，终审卡片"查看报告"）
/// 4. HR 终审（确认通过/调整评分/驳回淘汰，评估终审 tab）
/// 5. Offer 管理（触发/列表/状态，Offer 管理 tab）
/// 6. 级联流转（非终面确认通过 → "已自动创建下一轮预约任务"提示，UC-15）
/// 7. 淘汰归档（驳回 → "已归档人才库 + 感谢信已发送"提示）
///
/// 页面全部使用本地 Mock 数据，不发起任何真实网络请求。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const P4PreviewApp());
}

class P4PreviewApp extends StatelessWidget {
  const P4PreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P4 预览 - 面试执行与评估',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const P4PreviewShell(),
    );
  }
}

class P4PreviewShell extends StatefulWidget {
  const P4PreviewShell({super.key});

  @override
  State<P4PreviewShell> createState() => _P4PreviewShellState();
}

class _P4PreviewShellState extends State<P4PreviewShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [
      InterviewWorkbenchPage(),
      ReviewPage(),
      OfferPage(),
      RecordingPage(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.mic_none), selectedIcon: Icon(Icons.mic), label: '面试工作台'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: '评估终审'),
          NavigationDestination(icon: Icon(Icons.mail_outline), selectedIcon: Icon(Icons.mail), label: 'Offer 管理'),
          NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library), label: '录播回放'),
        ],
      ),
    );
  }
}
