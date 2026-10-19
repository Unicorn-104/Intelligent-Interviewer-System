import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'interview/interview_workbench_page.dart';
import 'interview/device_check_page.dart';
import 'interview/recording_page.dart';
import 'interview/practice_preload_page.dart';
import 'interview/interview_entrance_page.dart';
import 'schedule/reschedule_review_page.dart';
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
import 'talent/talent_page.dart';
import 'screening/screening_task_list_page.dart';
import 'screening/shortlist_review_page.dart';
import 'screening/greeting_page.dart';

class _FeatureEntry {
  const _FeatureEntry(
    this.label,
    this.icon,
    this.builder, {
    this.isDemo = false,
    this.alias,
  });
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  final bool isDemo;
  final String? alias;
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
  final _visited = <int>{0};
  int _index = 0;

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
      _FeatureEntry(
        '候选人管理',
        Icons.people_outline,
        (_) => const TalentPage(),
        alias: '人才库',
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
        '录播',
        Icons.video_library_outlined,
        (_) => const RecordingPage(),
        isDemo: true,
      ),
      _FeatureEntry(
        '预加载',
        Icons.hourglass_top_outlined,
        (_) => const PracticePreloadPage(),
        isDemo: true,
      ),
      _FeatureEntry(
        '改期审批',
        Icons.edit_calendar_outlined,
        (_) => const RescheduleReviewPage(),
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
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      if (index == 3) _accountKey.currentState?.reload();
      return;
    }
    setState(() {
      _index = index;
      _visited.add(index);
    });
    if (index == 3) _accountKey.currentState?.reload();
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
                  subtitle: entries[index].isDemo
                      ? const Text('演示数据')
                      : entries[index].alias == null
                      ? null
                      : Text(entries[index].alias!),
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
        onNotifications: _openNotifications,
        onOpenNotices: _openHomeNotices,
        onFeatures: _openMore,
        onInterviews: () => _openFeature(_interviews),
        onJobs: () => _selectTab(1),
      ),
      1 => const JobsPage(),
      2 => const MessageCenterPage(),
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
    bottomNavigationBar: NavigationBar(
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
    ),
  );
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
