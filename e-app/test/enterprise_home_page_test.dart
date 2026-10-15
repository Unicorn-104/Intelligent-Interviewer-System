import 'dart:async';
import 'package:enterprise_recruiter/features/enterprise/dashboard/home_page.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/home_lists_page.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/home_models.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/widgets/home_section.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/widgets/home_interview_section.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/widgets/home_applications_section.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/job_detail_page.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/home_fixture.dart';

Future<void> mount(
  WidgetTester tester,
  HomeFixture source, {
  Size size = const Size(420, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  FlutterSecureStorage.setMockInitialValues({});
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        ),
        child: HomePage(
          dataSource: source,
          onNotifications: () {},
          onFeatures: () {},
          onInterviews: () {},
          onJobs: () {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Finder inHome(Finder matching) =>
    find.descendant(of: find.byType(HomePage), matching: matching);

Future<void> more(WidgetTester tester, String title) async {
  await tester.pumpAndSettle();
  final section = inHome(find.widgetWithText(HomeSection, title));
  final button = find.descendant(of: section, matching: find.text('更多'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(900, 420),
    const Size(420, 900),
  ]) {
    testWidgets('真实首页在 $size 和安全区内显示三条预览且不溢出', (tester) async {
      await mount(tester, HomeFixture(), size: size);
      expect(find.text('示例企业'), findsOneWidget);
      expect(inHome(find.byType(HomeInterviewRow)), findsNWidgets(3));
      expect(inHome(find.byType(HomeApplicationRow)), findsNWidgets(3));
      final applications = inHome(find.widgetWithText(HomeSection, '岗位投递概览'));
      expect(
        find.descendant(of: applications, matching: find.byType(Card)),
        findsNWidgets(3),
      );
      for (final row in tester.widgetList<HomeApplicationRow>(
        inHome(find.byType(HomeApplicationRow)),
      )) {
        expect(row.companyName, '示例企业');
      }
      for (final title in ['近期面试', '快捷统计']) {
        expect(
          tester
              .widget<HomeSection>(
                inHome(find.widgetWithText(HomeSection, title)),
              )
              .wrapInCard,
          isTrue,
        );
      }
      final badge = tester.widget<Badge>(
        find.byKey(const ValueKey('home-notice-badge')),
      );
      expect(badge.isLabelVisible, isTrue);
      await tester.ensureVisible(find.byKey(const ValueKey('home-stat-待终审')));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('home-stat-待终审'))).data,
        '—',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('home-stat-在招岗位'))).data,
        '0',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('更多分别进入独立面试和累计投递列表，返回仍只有三条', (tester) async {
    await mount(tester, HomeFixture());
    await more(tester, '近期面试');
    expect(find.byType(HomeInterviewsPage), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HomeInterviewsPage),
        matching: find.byType(HomeInterviewRow),
      ),
      findsNWidgets(4),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(inHome(find.byType(HomeInterviewRow)), findsNWidgets(3));
    await more(tester, '岗位投递概览');
    expect(find.byType(HomeApplicationsPage), findsOneWidget);
    expect(
      tester
          .widget<HomeApplicationsPage>(find.byType(HomeApplicationsPage))
          .companyName,
      '示例企业',
    );
    for (final row in tester.widgetList<HomeApplicationRow>(
      find.descendant(
        of: find.byType(HomeApplicationsPage),
        matching: find.byType(HomeApplicationRow),
      ),
    )) {
      expect(row.companyName, '示例企业');
    }
    expect(
      find.descendant(
        of: find.byType(HomeApplicationsPage),
        matching: find.byType(HomeApplicationRow),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: find.byType(HomeApplicationsPage),
        matching: find.text('累计投递 · 按岗位发布时间排序'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('区块失败不遮住其他数据，重试成功后恢复列表', (tester) async {
    final source = HomeFixture()..failures.add('interviews');
    await mount(tester, source);
    expect(inHome(find.byType(HomeApplicationRow)), findsNWidgets(3));
    expect(find.text('连接超时，请检查网络后重试'), findsOneWidget);
    source.failures.clear();
    final retry = inHome(find.text('重试'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();
    expect(inHome(find.byType(HomeInterviewRow)), findsNWidgets(3));
    expect(source.interviewCalls, 2);
  });

  testWidgets('空态不造假，加载态保留可见骨架', (tester) async {
    final source = HomeFixture()
      ..empty = true
      ..unread = 0;
    await mount(tester, source);
    expect(find.text('暂无即将进行的面试'), findsOneWidget);
    expect(find.text('暂无岗位投递数据'), findsOneWidget);
    expect(find.text('暂无统计数据'), findsOneWidget);
    expect(
      tester
          .widget<Badge>(find.byKey(const ValueKey('home-notice-badge')))
          .isLabelVisible,
      isFalse,
    );
    final pending = HomeFixture()
      ..pendingInterviews = Completer<HomePageSlice<HomeInterview>>();
    await tester.pumpWidget(const SizedBox.shrink());
    await mount(tester, pending);
    expect(find.byType(HomeSkeleton), findsOneWidget);
    expect(find.text('正在加载…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('默认详情仍是 Tab 0，首页投递入口显式打开 Tab 1', (tester) async {
    expect(const JobDetailPage(job: {}).initialTab, 0);
    await mount(tester, HomeFixture());
    final row = inHome(find.byKey(const ValueKey('home-job-1')));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    final detail = tester.widget<JobDetailPage>(find.byType(JobDetailPage));
    expect(detail.initialTab, 1);
    final tabs = tester.widget<TabBar>(
      find.descendant(
        of: find.byType(JobDetailPage),
        matching: find.byType(TabBar),
      ),
    );
    expect(tabs.controller!.index, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
