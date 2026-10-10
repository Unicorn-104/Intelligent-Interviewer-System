import 'package:flutter/material.dart';

import 'features/enterprise/dashboard/overview_page.dart';
import 'features/enterprise/interview/device_check_page.dart';
import 'features/enterprise/interview/interview_entrance_page.dart';
import 'features/enterprise/interview/interview_workbench_page.dart';
import 'features/enterprise/interview/recording_page.dart';
import 'features/enterprise/jobs/jobs_page.dart';
import 'features/enterprise/login_page.dart';
import 'features/enterprise/notification/assistant_placeholder_page.dart';
import 'features/enterprise/notification/message_center_page.dart';
import 'features/enterprise/notification/notice_page.dart';
import 'features/enterprise/notification/notification_log_page.dart';
import 'features/enterprise/notification/notification_templates_page.dart';
import 'features/enterprise/notification/survey_result_page.dart';
import 'features/enterprise/offer/offer_page.dart';
import 'features/enterprise/review/review_page.dart';
import 'features/enterprise/schedule/interview_schedule_page.dart';
import 'features/enterprise/schedule/reschedule_review_page.dart';
import 'features/enterprise/screening/greeting_page.dart';
import 'features/enterprise/screening/screening_task_list_page.dart';
import 'features/enterprise/screening/shortlist_review_page.dart';
import 'features/enterprise/talent/talent_page.dart';
import 'theme/app_theme.dart';

/// 统一入口：flutter run -t lib/enterprise_main.dart -d emulator-5554
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EnterpriseMainApp());
}

class EnterpriseMainApp extends StatelessWidget {
  const EnterpriseMainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '智能面试官 · 企业端',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: LoginPage(
        authenticatedBuilder: (context, onLogout) =>
            EnterpriseModuleShell(onLogout: onLogout),
      ),
    );
  }
}

class _ModulePage {
  const _ModulePage(this.label, this.page, {this.isDemo = false});

  final String label;
  final Widget page;
  final bool isDemo;
}

class _Module {
  const _Module(this.label, this.icon, this.pages, {this.more = const []});

  final String label;
  final IconData icon;
  final List<_ModulePage> pages;
  final List<_ModulePage> more;
}

// 工作台概览使用真实接口；消息、公告及尚未接入的业务页保留演示标识。
const _modules = <_Module>[
  _Module(
    '工作台',
    Icons.dashboard_outlined,
    [
      _ModulePage('概览', OverviewPage()),
      _ModulePage('通知', NotificationLogPage(), isDemo: true),
      _ModulePage('公告', NoticePage(), isDemo: true),
      _ModulePage('消息', MessageCenterPage(), isDemo: true),
    ],
    more: [
      _ModulePage('通知模板', NotificationTemplatesPage(), isDemo: true),
      _ModulePage('调研结果', SurveyResultPage(), isDemo: true),
      _ModulePage('AI 助手', AssistantPlaceholderPage(), isDemo: true),
    ],
  ),
  _Module(
    '招聘',
    Icons.work_outline,
    [
      _ModulePage('岗位', JobsPage()),
      _ModulePage('人才库', TalentPage()),
      _ModulePage('AI 初筛', ScreeningTaskListPage(), isDemo: true),
    ],
    more: [
      _ModulePage('短名单复核', ShortlistReviewPage(), isDemo: true),
      _ModulePage('招呼语', GreetingPage(), isDemo: true),
    ],
  ),
  _Module(
    '面试',
    Icons.event_note_outlined,
    [
      _ModulePage('日程', RealInterviewSchedulePage()),
      _ModulePage('工作台', InterviewWorkbenchPage(), isDemo: true),
      _ModulePage('终审', ReviewPage(), isDemo: true),
      _ModulePage('Offer', OfferPage(), isDemo: true),
    ],
    more: [
      _ModulePage('演示排期', InterviewSchedulePage(), isDemo: true),
      _ModulePage('改期审批', RescheduleReviewPage(), isDemo: true),
      _ModulePage('面试入口', InterviewEntrancePage(), isDemo: true),
      _ModulePage('设备检测', DeviceCheckPage(), isDemo: true),
      _ModulePage('录播回放', RecordingPage(), isDemo: true),
    ],
  ),
  _Module('我的', Icons.person_outline, [_ModulePage('账号', _AccountPage())]),
];

class EnterpriseModuleShell extends StatefulWidget {
  const EnterpriseModuleShell({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<EnterpriseModuleShell> createState() => _EnterpriseModuleShellState();
}

class _EnterpriseModuleShellState extends State<EnterpriseModuleShell> {
  final _navigatorKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());
  int _index = 0;
  bool _pageIsDemo = false;
  bool? _detailIsDemo;

  void _selectTab(int index) {
    if (index == _index) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() {
      _index = index;
      _pageIsDemo = _modules[index].pages.first.isDemo;
      _detailIsDemo = null;
    });
  }

  // 后端 DashboardServiceImpl.buildTodos 目前只会生成以下三种 go。
  void _navigateTodo(String? go) {
    switch (go) {
      case '/enterprise/interviews':
        _selectTab(2); // 面试 · 真实日程
      case '/enterprise/jobs':
        _selectTab(1); // 招聘 · 岗位
      case '/enterprise/meeting/ai':
        _selectTab(2); // 先进入真实日程，不打开仍为演示数据的工作台。
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先在面试日程中核对实际会话')));
      default:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('该功能请在 Web 端操作')));
    }
  }

  Future<void> _openMore(_ModulePage page) async {
    setState(() => _detailIsDemo = page.isDemo);
    await _navigatorKeys[_index].currentState?.push<void>(
      MaterialPageRoute(builder: (_) => page.page),
    );
    if (mounted) setState(() => _detailIsDemo = null);
  }

  @override
  Widget build(BuildContext context) {
    final module = _modules[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text(module.label),
        actions: [
          if (module.more.isNotEmpty)
            PopupMenuButton<_ModulePage>(
              tooltip: '更多功能',
              icon: const Icon(Icons.more_horiz),
              onSelected: _openMore,
              itemBuilder: (context) => [
                for (final page in module.more)
                  PopupMenuItem(value: page, child: Text(page.label)),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          if (_detailIsDemo ?? _pageIsDemo) const _DemoBanner(),
          Expanded(
            child: NavigatorPopHandler(
              onPopWithResult: (result) =>
                  _navigatorKeys[_index].currentState?.pop(),
              child: Navigator(
                key: _navigatorKeys[_index],
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => _ModuleTabs(
                    module: module,
                    onDemoChanged: (value) =>
                        setState(() => _pageIsDemo = value),
                    onLogout: widget.onLogout,
                    onOpenTodo: _navigateTodo,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        destinations: [
          for (final tab in _modules)
            NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}

class _ModuleTabs extends StatefulWidget {
  const _ModuleTabs({
    required this.module,
    required this.onDemoChanged,
    required this.onLogout,
    required this.onOpenTodo,
  });

  final _Module module;
  final ValueChanged<bool> onDemoChanged;
  final VoidCallback onLogout;
  final ValueChanged<String?> onOpenTodo;

  @override
  State<_ModuleTabs> createState() => _ModuleTabsState();
}

class _ModuleTabsState extends State<_ModuleTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: widget.module.pages.length, vsync: this);
    _tabs.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabs.index == _currentPage) return;
    setState(() => _currentPage = _tabs.index);
    widget.onDemoChanged(widget.module.pages[_currentPage].isDemo);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.module.pages[_currentPage];
    return Column(
      children: [
        if (widget.module.pages.length > 1)
          Material(
            color: AppColors.background,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                for (var index = 0; index < widget.module.pages.length; index++)
                  Tab(
                    text: widget.module.label == '面试'
                        ? '${index + 1} ${widget.module.pages[index].label}'
                        : widget.module.pages[index].label,
                  ),
              ],
            ),
          ),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(_currentPage),
            child: widget.module.label == '我的'
                ? _AccountPage(onLogout: widget.onLogout)
                : page.page is OverviewPage
                ? OverviewPage(
                    onOpenTodo: widget.onOpenTodo,
                    onOpenNotifications: () => _tabs.animateTo(1),
                    onOpenAnnouncements: () => _tabs.animateTo(2),
                  )
                : page.page,
          ),
        ),
      ],
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.warningSoft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '演示数据 · 当前页面使用 Mock 内容',
              style: TextStyle(fontSize: 12, color: AppColors.body),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountPage extends StatelessWidget {
  const _AccountPage({this.onLogout});

  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Card(
          child: ListTile(
            leading: Icon(Icons.verified_user_outlined),
            title: Text('已登录'),
            subtitle: Text('当前登录信息与设置将在第三阶段整理'),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('退出登录'),
        ),
      ],
    );
  }
}
