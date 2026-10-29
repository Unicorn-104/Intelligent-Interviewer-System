import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'interview/interview_workbench_page.dart';
import 'interview/device_check_page.dart';
import 'interview/practice_preload_page.dart';
import 'interview/interview_entrance_page.dart';
import 'notification/notification_templates_page.dart';
import 'notification/survey_result_page.dart';
import 'notification/assistant_placeholder_page.dart';
import 'dashboard/home_page.dart';
import 'dashboard/overview_page.dart';
import 'feature_shortcuts_page.dart';
import 'jobs/jobs_page.dart';
import 'notification/message_center_page.dart';
import 'notification/notice_page.dart';
import 'notification/notification_log_page.dart';
import 'offer/offer_page.dart';
import 'profile/account_page.dart';
import 'review/review_page.dart';
import 'schedule/interview_schedule_page.dart';
import 'screening/screening_task_list_page.dart';
import 'screening/shortlist_review_page.dart';
import 'screening/greeting_page.dart';

class _FeatureEntry {
  const _FeatureEntry(
    this.label,
    this.icon,
    this.builder, {
    this.isDemo = false,
  });
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  final bool isDemo;
}

class EnterpriseModuleShell extends StatefulWidget {
  const EnterpriseModuleShell({
    super.key,
    required this.onLogout,
    this.tabBuilders,
  }) : assert(tabBuilders == null || tabBuilders.length == 4);
  final VoidCallback onLogout;

  /// Optional roots let navigation tests run without a network service.
  final List<WidgetBuilder>? tabBuilders;

  @override
  State<EnterpriseModuleShell> createState() => _EnterpriseModuleShellState();
}

class _EnterpriseModuleShellState extends State<EnterpriseModuleShell> {
  final _navigatorKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());
  final _accountKey = GlobalKey<AccountPageState>();
  // 4 个根页面的 key，用于在 Tab 选中时调用各自的 scrollToTop()
  final _homeKey = GlobalKey<HomePageState>();
  final _jobsKey = GlobalKey<JobsPageState>();
  final _messageKey = GlobalKey<MessageCenterPageState>();
  final _visited = <int>{0};
  int _index = 0;
  // 底部导航栏是否可见：进入子页面（嵌套 Navigator 有子路由）时隐藏、
  // 回到根页面时恢复，从而实现子页面全屏。
  bool _barVisible = true;
  // 各嵌套 Navigator 的路由观察者，用于在 push/pop 时同步底部栏显隐。
  late final List<_TabBarObserver> _observers = [
    for (var i = 0; i < 4; i++) _TabBarObserver(_syncBarVisibility),
  ];

  List<List<_FeatureEntry>> get _featureGroups => [
    [
      _FeatureEntry(
        '招聘概览',
        Icons.dashboard_outlined,
        (_) => Scaffold(
          appBar: AppBar(title: const Text('招聘概览')),
          body: OverviewPage(
            onOpenTodo: _navigateTodo,
            onOpenNotifications: () => _openFeature(_notification),
            onOpenAnnouncements: () => _openFeature(_announcement),
          ),
        ),
      ),
      _interviews,
      _FeatureEntry(
        '终审',
        Icons.fact_check_outlined,
        (_) => const ReviewPage(),
        isDemo: true,
      ),
      _FeatureEntry(
        'Offer',
        Icons.mark_email_read_outlined,
        (_) => const OfferPage(),
        isDemo: true,
      ),
      _notification,
      _announcement,
    ],
    [
      _FeatureEntry(
        '筛选任务',
        Icons.auto_awesome_outlined,
        (_) => const ScreeningTaskListPage(),
        isDemo: true,
      ),
      _FeatureEntry(
        '短名单',
        Icons.checklist_outlined,
        (_) => const ShortlistReviewPage(),
        isDemo: true,
      ),
      _FeatureEntry(
        '招呼语',
        Icons.waving_hand_outlined,
        (_) => const GreetingPage(),
        isDemo: true,
      ),
    ],
    [
      _FeatureEntry(
        '工作台',
        Icons.video_camera_front_outlined,
        (_) => const InterviewWorkbenchPage(),
        isDemo: true,
      ),
      _FeatureEntry(
        '设备检测',
        Icons.devices_outlined,
        (_) => const DeviceCheckPage(),
        isDemo: true,
      ),
      _FeatureEntry(
        '预加载',
        Icons.hourglass_top_outlined,
        (_) => const PracticePreloadPage(),
        isDemo: true,
      ),
      _FeatureEntry(
        '模板',
        Icons.description_outlined,
        (_) => const NotificationTemplatesPage(),
        isDemo: true,
      ),
      _FeatureEntry(
        '调研',
        Icons.poll_outlined,
        (_) => const SurveyResultPage(),
        isDemo: true,
      ),
      _FeatureEntry(
        'AI 助手',
        Icons.auto_awesome_outlined,
        (_) => const AssistantPlaceholderPage(),
        isDemo: true,
      ),
    ],
  ];

  _FeatureEntry get _interviews => _FeatureEntry(
    '面试日程',
    Icons.event_outlined,
    (_) => const RealInterviewSchedulePage(),
  );
  _FeatureEntry get _notification => _FeatureEntry(
    '通知',
    Icons.notifications_outlined,
    (_) => const NotificationLogPage(),
    isDemo: true,
  );
  _FeatureEntry get _announcement =>
      _FeatureEntry('公告', Icons.campaign_outlined, (_) => const NoticePage());

  void _selectTab(int index) {
    if (_index == index) {
      // 重复点当前 Tab：回到该 Tab 嵌套导航的根路由（兜底）
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      // 切换到目标 Tab
      setState(() {
        _index = index;
        _visited.add(index);
      });
    }
    if (index == 3) _accountKey.currentState?.reload();
    // 同步底部栏显隐（根页面应显示底部栏）
    _syncBarVisibility();
    // 下一帧再让目标根页面回到顶部（首次访问时页面本帧才挂载）
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollRootToTop(index),
    );
  }

  /// 调用目标 Tab 根页面的 scrollToTop()，使其回到页面顶部
  /// （首页还会把轮播复位到第 1 页）。
  void _scrollRootToTop(int index) {
    switch (index) {
      case 0:
        _homeKey.currentState?.scrollToTop();
      case 1:
        _jobsKey.currentState?.scrollToTop();
      case 2:
        _messageKey.currentState?.scrollToTop();
      case 3:
        _accountKey.currentState?.scrollToTop();
    }
  }

  /// 根据当前 Tab 嵌套 Navigator 是否存在子路由，决定底部栏显隐：
  /// 有子页面（canPop）时隐藏底部栏实现全屏，回到根路由时恢复。
  void _syncBarVisibility() {
    final navigator = _navigatorKeys[_index].currentState;
    final visible = !(navigator?.canPop() ?? false);
    if (visible != _barVisible) {
      setState(() => _barVisible = visible);
    }
  }

  void _navigateTodo(String? go) {
    switch (go) {
      case '/enterprise/jobs':
        _selectTab(1);
      case '/enterprise/interviews':
      case '/enterprise/meeting/ai':
        _openFeature(_interviews);
      default:
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('该功能请在 Web 端操作')));
    }
  }

  void _openFeature(_FeatureEntry entry) {
    _navigatorKeys[_index].currentState?.push<void>(
      MaterialPageRoute(
        builder: (context) => entry.isDemo
            ? Column(
                children: [
                  _DemoBanner(
                    onLegacyInterview: entry.label == '工作台'
                        ? _openLegacyInterview
                        : null,
                    ai: [
                      '筛选任务',
                      '短名单',
                      '招呼语',
                      '工作台',
                      'AI 助手',
                    ].contains(entry.label),
                  ),
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: entry.builder(context),
                    ),
                  ),
                ],
              )
            : entry.builder(context),
      ),
    );
  }

  void _openLegacyInterview(String target) {
    _openFeature(
      _FeatureEntry(
        target,
        Icons.event_outlined,
        (_) => target == '演示排期'
            ? const InterviewSchedulePage()
            : const InterviewEntrancePage(),
        isDemo: true,
      ),
    );
  }

  void _openMore() {
    final sections = <Widget>[];
    for (var batch = 0; batch < _featureGroups.length; batch++) {
      final entries = _featureGroups[batch];
      if (batch > 0) sections.add(const SizedBox(height: 24));
      sections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            ['招聘与协作', '筛选与沟通', '演示功能'][batch],
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
      sections.add(
        Card(
          child: Column(
            children: [
              for (var index = 0; index < entries.length; index++) ...[
                if (index > 0) const Divider(height: 1),
                ListTile(
                  key: ValueKey('feature-${entries[index].label}'),
                  leading: Icon(entries[index].icon, color: AppColors.brand),
                  title: Text(entries[index].label),
                  subtitle: entries[index].isDemo ? const Text('演示数据') : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openFeature(entries[index]),
                ),
              ],
            ],
          ),
        ),
      );
    }
    _navigatorKeys[_index].currentState?.push<void>(
      MaterialPageRoute(
        builder: (_) => FeatureShortcutsPage(sections: sections),
      ),
    );
  }

  void _openNotifications() {
    _navigatorKeys[_index].currentState?.push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('通知与公告')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('通知'),
                      subtitle: const Text('演示数据'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openFeature(_notification),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('公告'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openFeature(_announcement),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openHomeNotices() async {
    await _navigatorKeys[0].currentState?.push<void>(
      MaterialPageRoute(builder: (_) => const NoticePage()),
    );
  }

  Widget _root(BuildContext context, int index) {
    if (widget.tabBuilders case final builders?) {
      return builders[index](context);
    }
    return switch (index) {
      0 => HomePage(
        key: _homeKey,
        onNotifications: _openNotifications,
        onOpenNotices: _openHomeNotices,
        onFeatures: _openMore,
        onInterviews: () => _openFeature(_interviews),
        onJobs: () => _selectTab(1),
      ),
      1 => JobsPage(key: _jobsKey),
      2 => MessageCenterPage(key: _messageKey),
      _ => AccountPage(key: _accountKey, onLogout: widget.onLogout),
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      top: false,
      bottom: false,
      child: IndexedStack(
        index: _index,
        children: [
          for (var index = 0; index < 4; index++)
            TickerMode(
              enabled: _index == index,
              child: NavigatorPopHandler<Object?>(
                enabled: _index == index,
                onPopWithResult: (result) {
                  final navigator = _navigatorKeys[index].currentState;
                  if (_index == index &&
                      navigator != null &&
                      navigator.canPop()) {
                    navigator.pop(result);
                  }
                },
                child: _visited.contains(index)
                    ? Navigator(
                        key: _navigatorKeys[index],
                        observers: [_observers[index]],
                        onGenerateRoute: (_) => MaterialPageRoute<void>(
                          builder: (context) => _root(context, index),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    ),
    bottomNavigationBar: _barVisible
        ? NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _selectTab,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: '首页',
              ),
              NavigationDestination(
                icon: Icon(Icons.work_outline),
                selectedIcon: Icon(Icons.work),
                label: '岗位',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: '消息',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: '我的',
              ),
            ],
          )
        : null,
  );
}

/// 嵌套 Navigator 路由观察者：在 push/pop/remove/replace 后，下一帧通知
/// Shell 重新计算底部导航栏显隐（子页面全屏、根页面恢复）。
class _TabBarObserver extends NavigatorObserver {
  _TabBarObserver(this.onChanged);
  final VoidCallback onChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _schedule();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _schedule();
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _schedule();
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _schedule();

  /// 路由变化后下一帧再回调，确保 canPop 等状态已更新。
  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) => onChanged());
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner({this.onLegacyInterview, this.ai = false});
  final ValueChanged<String>? onLegacyInterview;
  final bool ai;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.warningSoft,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: AppColors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ai ? '演示数据 · AI 结果仅供参考' : '演示数据 · 当前页面使用 Mock 内容',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (onLegacyInterview != null)
              PopupMenuButton<String>(
                tooltip: '更多面试演示',
                onSelected: onLegacyInterview,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: '演示排期', child: Text('演示排期 · 演示数据')),
                  PopupMenuItem(value: '面试入口', child: Text('面试入口 · 演示数据')),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}
