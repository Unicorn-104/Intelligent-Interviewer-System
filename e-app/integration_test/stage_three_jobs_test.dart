import 'dart:async';
import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/jobs_page.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/widgets/job_list_card.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:enterprise_recruiter/widgets/skeleton_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/jobs_fixture.dart';
import 'stage_one_device_test.dart' show frames, bridge, capture;

Future<void> waitReady(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await frames(tester, 100);
    if (find.byType(SkeletonList).evaluate().isEmpty) return;
  }
  throw StateError('Jobs test page did not load');
}

Future<void> mountJobs(WidgetTester tester, JobsFixture source) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Banner(
        message: '受控验收',
        location: BannerLocation.topEnd,
        color: AppColors.warning,
        child: JobsPage(
          loadJobs: source.load,
          updateStatus: source.update,
          detailBuilder: (job, index) =>
              Scaffold(appBar: AppBar(title: Text('详情 Tab $index'))),
        ),
      ),
    ),
  );
  await waitReady(tester);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('岗位列表：四筛选、搜索、分页、徽标与整卡导航、状态确认映射', (tester) async {
    final source = JobsFixture();
    await mountJobs(tester, source);
    for (final state in [1, 0, 2, null]) {
      await tester.tap(find.byKey(ValueKey('jobs-filter-$state')));
      await waitReady(tester);
      expect(source.calls.last.status, state);
    }
    await capture('stage3_jobs_cards');
    await tester.tap(find.byKey(const ValueKey('job-applicants-1')));
    await frames(tester, 500);
    expect(find.text('详情 Tab 1'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await frames(tester, 500);
    await waitReady(tester);
    await tester.tap(find.text('示例岗位 1'));
    await frames(tester, 500);
    expect(find.text('详情 Tab 0'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await frames(tester, 500);
    await waitReady(tester);

    tester
            .widget<TextField>(find.byKey(const ValueKey('jobs-search')))
            .controller!
            .text =
        'SMOKE';
    await frames(tester, 100);
    await tester.tap(find.byTooltip('搜索'));
    FocusManager.instance.primaryFocus?.unfocus();
    await waitReady(tester);
    expect(find.byType(JobListCard), findsNWidgets(2));
    await capture('stage3_jobs_search');
    tester
        .widget<TextField>(find.byKey(const ValueKey('jobs-search')))
        .controller!
        .clear();
    await frames(tester, 100);
    await tester.tap(find.byTooltip('搜索'));
    FocusManager.instance.primaryFocus?.unfocus();
    await waitReady(tester);
    await frames(tester, 700);
    await waitReady(tester);
    expect(source.calls.last.keyword, '');
    final list = find.descendant(
      of: find.byKey(const ValueKey('jobs-list')),
      matching: find.byType(Scrollable),
    );
    final more = find.byKey(const ValueKey('jobs-load-more'));
    for (
      var attempt = 0;
      attempt < 30 && more.hitTestable().evaluate().isEmpty;
      attempt++
    ) {
      if (more.evaluate().isNotEmpty) {
        await tester.ensureVisible(more);
      } else {
        await tester.drag(list, const Offset(0, -500));
      }
      await frames(tester, 100);
    }
    expect(more.hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('jobs-load-more')));
    await frames(tester, 500);
    expect(source.calls.last.page, 2);
    expect(source.writes, isEmpty);

    for (final status in [0, 1, 2]) {
      await tester.tap(find.byKey(ValueKey('jobs-filter-$status')));
      await waitReady(tester);
      final id = status + 1;
      final list = find.descendant(
        of: find.byKey(const ValueKey('jobs-list')),
        matching: find.byType(Scrollable),
      );
      await tester.drag(list, const Offset(0, 8000));
      await frames(tester, 200);
      await tester.tap(find.byKey(ValueKey('job-status-$id')));
      await frames(tester, 500);
      expect(find.text(status == 1 ? '确认下线' : '确认上线'), findsOneWidget);
      if (status == 2) expect(find.textContaining('恢复为在招'), findsOneWidget);
      await capture('stage3_jobs_confirm_$status');
      await tester.tap(find.text('取消'));
      await frames(tester, 500);
      expect(source.writes, isEmpty);
    }
    source.statusGate = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('job-status-3')));
    await frames(tester, 500);
    await tester.tap(find.text('确认'));
    await frames(tester, 500);
    expect(source.writes, [(3, 1)]);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('job-status-3')))
          .onPressed,
      isNull,
    );
    source.statusGate!.complete();
    await waitReady(tester);
    binding.reportData ??= {};
    binding.reportData!['jobsInteractions'] = {
      'search': true,
      'filters': 4,
      'pagination': true,
      'applicantsTab': 1,
      'ordinaryTab': 0,
      'cancelWrites': 0,
      'confirmedWrites': 1,
    };
  });

  testWidgets('岗位列表：空态、错误重试、物理尺寸', (tester) async {
    final source = JobsFixture()..rows.clear();
    await mountJobs(tester, source);
    expect(find.text('暂无岗位'), findsOneWidget);
    for (final error in [
      const ApiException('权限不足', code: 403),
      const ApiException('连接超时'),
      const ApiException('故障', code: 500),
    ]) {
      source.error = error;
      await mountJobs(tester, source);
      final text = error.code == 403 ? '重新检查' : '重试';
      expect(find.text(text), findsOneWidget);
      source.error = null;
      await tester.tap(find.text(text));
      await waitReady(tester);
      expect(find.text('暂无岗位'), findsOneWidget);
    }
    try {
      for (final layout in ['narrow', 'landscape', 'portrait']) {
        await bridge('layout/$layout');
        await frames(tester, 1000);
        await mountJobs(tester, JobsFixture());
        expect(tester.takeException(), isNull);
        await capture('stage3_jobs_layout_$layout');
      }
    } finally {
      await bridge('layout/reset');
    }
    binding.reportData ??= {};
    binding.reportData!['jobsStatesAndPhysicalLayouts'] = true;
  }, timeout: const Timeout(Duration(minutes: 4)));
}
