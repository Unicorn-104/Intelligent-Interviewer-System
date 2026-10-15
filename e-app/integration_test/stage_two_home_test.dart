import 'dart:convert';
import 'dart:io';
import 'package:enterprise_recruiter/features/enterprise/dashboard/home_page.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/home_lists_page.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/widgets/home_section.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/widgets/home_status.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/widgets/home_interview_section.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/widgets/home_applications_section.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/notice_page.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'stage_one_device_test.dart' show frames, bridge, capture;

Future<Map<String, dynamic>> control(
  Map<String, String> params, {
  bool report = false,
}) async {
  final client = HttpClient();
  try {
    final uri = Uri.http(
      '10.0.2.2:18990',
      report ? '/__control/report' : '/__control/set',
      params,
    );
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 10));
    final response = await request.close().timeout(const Duration(seconds: 10));
    final text = await utf8.decoder.bind(response).join();
    if (response.statusCode != 200) {
      throw StateError('Synthetic server control unavailable');
    }
    return Map<String, dynamic>.from(jsonDecode(text) as Map);
  } finally {
    client.close(force: true);
  }
}

Finder inHome(Finder matching) =>
    find.descendant(of: find.byType(HomePage), matching: matching);
Finder section(String title) => inHome(find.widgetWithText(HomeSection, title));

Future<void> until(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await frames(tester, 100);
    if (ready()) {
      return;
    }
  }
  throw StateError('Controlled device state did not become ready');
}

Future<void> loaded(WidgetTester tester) => until(
  tester,
  () =>
      inHome(find.byType(HomeSkeleton)).evaluate().isEmpty &&
      inHome(find.byType(LinearProgressIndicator)).evaluate().isEmpty &&
      inHome(find.text('正在读取公告未读数…')).evaluate().isEmpty,
);

Future<void> mount(WidgetTester tester, {bool waitForData = true}) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      navigatorKey: navigator,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Banner(
        message: '受控验收',
        location: BannerLocation.topEnd,
        color: AppColors.warning,
        child: HomePage(
          onNotifications: () {},
          onFeatures: () {},
          onInterviews: () {},
          onJobs: () {},
          onOpenNotices: () async {
            await navigator.currentState!.push<void>(
              MaterialPageRoute(builder: (_) => const NoticePage()),
            );
          },
        ),
      ),
    ),
  );
  if (waitForData) {
    await loaded(tester);
  }
}

Future<void> tapMore(WidgetTester tester, String title) async {
  final more = find.descendant(of: section(title), matching: find.text('更多'));
  await tester.ensureVisible(more);
  await frames(tester, 100);
  await tester.tap(more);
  await frames(tester, 500);
}

int page(WidgetTester tester) {
  final finder = find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        (widget.properties.label ?? '').startsWith('轮播图，第 '),
  );
  final label = tester.widget<Semantics>(finder).properties.label!;
  return int.parse(RegExp(r'第 (\d) 页').firstMatch(label)!.group(1)!);
}

Badge badge(WidgetTester tester) => tester.widget<Badge>(
  inHome(find.byKey(const ValueKey('home-notice-badge'))),
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final report = <String, Object?>{};
  void record(String name, Object result) {
    report[name] = result;
    binding.reportData ??= {};
    binding.reportData!['stageTwo'] = report;
    debugPrint('STAGE_TWO_DEVICE: $name=$result');
  }

  testWidgets('受控真实 API：三条预览、独立列表、轮播、公告已读与返回刷新', (tester) async {
    await control({'reset': '1'});
    await mount(tester);
    expect(inHome(find.text('受控验收企业')), findsOneWidget);
    expect(inHome(find.byType(HomeInterviewRow)), findsNWidgets(3));
    expect(inHome(find.byType(HomeApplicationRow)), findsNWidgets(3));
    expect(badge(tester).isLabelVisible, isTrue);
    expect((badge(tester).label! as Text).data, '4');
    record('apiPreviewCounts', {'interviews': 3, 'applications': 3});

    await tester.tap(inHome(find.byKey(const ValueKey('home-carousel-dot-0'))));
    await frames(tester, 100);
    expect(page(tester), 1);
    await Future<void>.delayed(const Duration(milliseconds: 5200));
    await frames(tester, 100);
    expect(page(tester), 2);
    await tester.drag(
      inHome(find.byKey(const ValueKey('home-carousel'))),
      const Offset(-300, 0),
    );
    await frames(tester, 500);
    expect(page(tester), 3);
    await tester.tap(inHome(find.byKey(const ValueKey('home-carousel-dot-0'))));
    await frames(tester, 500);
    expect(page(tester), 1);
    await capture('stage2_controlled_home');
    record('carouselAutoManualIndicators', true);

    await tapMore(tester, '近期面试');
    await until(
      tester,
      () =>
          find
              .descendant(
                of: find.byType(HomeInterviewsPage),
                matching: find.byType(HomeInterviewRow),
              )
              .evaluate()
              .length ==
          4,
    );
    expect(
      find.descendant(
        of: find.byType(HomeInterviewsPage),
        matching: find.byType(HomeInterviewRow),
      ),
      findsNWidgets(4),
    );
    await tester.binding.handlePopRoute();
    await frames(tester, 500);
    await loaded(tester);
    await tapMore(tester, '岗位投递概览');
    await until(
      tester,
      () => find
          .descendant(
            of: find.byType(HomeApplicationsPage),
            matching: find.byType(HomeApplicationRow),
          )
          .evaluate()
          .isNotEmpty,
    );
    expect(
      find.descendant(
        of: find.byType(HomeApplicationsPage),
        matching: find.text('累计投递 · 按岗位发布时间排序'),
      ),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await frames(tester, 500);
    await loaded(tester);
    record('independentMoreLists', true);

    await tester.ensureVisible(
      inHome(find.byKey(const ValueKey('home-stat-待终审'))),
    );
    expect(
      tester
          .widget<Text>(inHome(find.byKey(const ValueKey('home-stat-待终审'))))
          .data,
      '—',
    );
    await tester.tap(find.byTooltip('通知与公告'));
    await until(tester, () => find.text('公告 · 未读 4').evaluate().isNotEmpty);
    await tester.tap(find.text('全部已读'));
    await until(tester, () => find.text('公告 · 未读 0').evaluate().isNotEmpty);
    await tester.binding.handlePopRoute();
    await frames(tester, 500);
    await until(tester, () => !badge(tester).isLabelVisible);
    final counts = (await control({}, report: true))['counts'] as Map;
    expect(counts['/system/notice/unreadCount'], 2);
    expect(counts['/system/notice/markRead'], 4);
    record('noticeReadReturnRefresh', {
      'unreadRequests': 2,
      'markedRead': 4,
      'badgeHiddenAfterReturn': true,
    });

    await control({'reset': '1', 'unread': '100'});
    await mount(tester);
    expect((badge(tester).label! as Text).data, '99+');
    await control({'reset': '1', 'unread': 'null'});
    await mount(tester);
    expect(badge(tester).isLabelVisible, isFalse);
    record('noticeOverflowAndNullZero', true);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('受控真实 API：加载和空态，不伪造统计', (tester) async {
    await control({'reset': '1', 'delay': '1.2'});
    await mount(tester, waitForData: false);
    expect(inHome(find.byType(HomeSkeleton)), findsWidgets);
    await loaded(tester);
    await control({'reset': '1', 'scenario': 'empty', 'unread': '0'});
    await mount(tester);
    expect(inHome(find.text('暂无即将进行的面试')), findsOneWidget);
    expect(inHome(find.text('暂无岗位投递数据')), findsOneWidget);
    expect(inHome(find.text('暂无统计数据')), findsOneWidget);
    await capture('stage2_controlled_empty');
    record('loadingAndAllEmptyStates', true);
  });

  for (final part in [
    'identity',
    'unread',
    'interviews',
    'applications',
    'stats',
  ]) {
    testWidgets('受控真实 API：$part 独立失败和重试', (tester) async {
      await control({'reset': '1', 'failure': part});
      await mount(tester);
      final title = {
        'interviews': '近期面试',
        'applications': '岗位投递概览',
        'stats': '快捷统计',
      }[part];
      final scope = title == null
          ? inHome(find.byType(HomeStatus))
          : find.descendant(
              of: section(title),
              matching: find.byType(HomeStatus),
            );
      expect(scope, findsOneWidget);
      final retry = find.descendant(of: scope, matching: find.text('重试'));
      expect(retry, findsOneWidget);
      if (part != 'applications') {
        expect(inHome(find.byType(HomeApplicationRow)), findsNWidgets(3));
      } else {
        expect(inHome(find.byType(HomeInterviewRow)), findsNWidgets(3));
      }
      await tester.ensureVisible(retry);
      await frames(tester, 100);
      await capture('stage2_controlled_error_$part');
      await control({'failure': 'none'});
      await tester.tap(retry);
      await until(
        tester,
        () =>
            inHome(find.byType(HomeStatus)).evaluate().isEmpty &&
            inHome(find.byType(HomeSkeleton)).evaluate().isEmpty,
      );
      final counts = (await control({}, report: true))['counts'] as Map;
      final endpoint = {
        'identity': '/getInfo',
        'unread': '/system/notice/unreadCount',
        'interviews': '/enterprise/interview/list',
        'applications': '/system/enterprise/jobs/list',
        'stats': '/system/dashboard/overview',
      }[part]!;
      expect(counts[endpoint], 2);
      await capture('stage2_controlled_retry_$part');
      record('failureRetry_$part', {
        'retriedEndpointRequests': 2,
        'otherSectionsPreserved': true,
      });
    });
  }

  testWidgets('受控真实 API：物理窄屏、横屏、安全区', (tester) async {
    await control({'reset': '1'});
    try {
      for (final layout in ['narrow', 'landscape', 'portrait']) {
        await bridge('layout/$layout');
        await frames(tester, 1200);
        await mount(tester);
        final carousel = inHome(find.byKey(const ValueKey('home-carousel')));
        final media = MediaQuery.of(tester.element(find.byType(HomePage)));
        final rect = tester.getRect(carousel);
        expect(rect.left, greaterThanOrEqualTo(media.padding.left + 19));
        expect(
          rect.right,
          lessThanOrEqualTo(media.size.width - media.padding.right - 19),
        );
        expect(tester.takeException(), isNull);
        await capture('stage2_controlled_layout_$layout');
        await tester.ensureVisible(
          inHome(find.byKey(const ValueKey('home-stat-待终审'))),
        );
        await frames(tester, 100);
        expect(tester.takeException(), isNull);
        await capture('stage2_controlled_layout_${layout}_stats');
        record('layout_$layout', {
          'width': media.size.width,
          'height': media.size.height,
          'safeArea': true,
        });
      }
    } finally {
      await bridge('layout/reset');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
