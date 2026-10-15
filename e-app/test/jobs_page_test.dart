import 'dart:async';
import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/jobs_page.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/job_detail_page.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/widgets/job_list_card.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:enterprise_recruiter/widgets/skeleton_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/jobs_fixture.dart';

Future<void> open(
  WidgetTester tester,
  JobsFixture source, {
  WidgetBuilder? publishBuilder,
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
      home: JobsPage(
        loadJobs: source.load,
        updateStatus: source.update,
        publishBuilder: publishBuilder,
      ),
    ),
  );
  await tester.pump();
  if (source.loadGate == null) await tester.pumpAndSettle();
}

Future<void> reach(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    320,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('jobs-list')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('搜索和四种筛选传递真实条件；测试岗位不特殊隐藏', (tester) async {
    final source = JobsFixture();
    await open(tester, source);
    expect(source.calls.last.page, 1);
    for (final value in [1, 0, 2, null]) {
      await tester.tap(find.byKey(ValueKey('jobs-filter-$value')));
      await tester.pumpAndSettle();
      expect(source.calls.last.status, value);
    }
    await tester.enterText(find.byKey(const ValueKey('jobs-search')), 'SMOKE');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byType(JobListCard), findsNWidgets(2));
    expect(find.byKey(const ValueKey('job-list-card-8')), findsOneWidget);
    expect(find.byKey(const ValueKey('job-list-card-10')), findsOneWidget);
    expect(source.writes, isEmpty);
  });

  testWidgets('第二页失败保留第一页，可重试；新筛选从第一页开始', (tester) async {
    final source = JobsFixture();
    await open(tester, source);
    final more = find.byKey(const ValueKey('jobs-load-more'));
    await reach(tester, more);
    source.failNextPage = true;
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(source.calls.last.page, 2);
    expect(find.text('加载失败'), findsOneWidget);
    source.failNextPage = false;
    await tester.ensureVisible(find.text('重试'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(source.calls.last.page, 2);
    await reach(tester, find.text('已显示全部'));
    expect(find.text('已显示全部'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('jobs-filter-1')));
    await tester.pumpAndSettle();
    expect(source.calls.last.page, 1);
  });

  testWidgets('卡片进入初始 Tab 0，累计徽标进入初始 Tab 1', (tester) async {
    final source = JobsFixture()..rows.removeRange(1, 25);
    await open(tester, source);
    for (final entry in [('job-open-1', 0), ('job-applicants-1', 1)]) {
      await tester.tap(find.byKey(ValueKey(entry.$1)));
      await tester.pumpAndSettle();
      final page = find.byType(JobDetailPage);
      expect(tester.widget<JobDetailPage>(page).initialTab, entry.$2);
      expect(
        tester
            .widget<TabBar>(
              find.descendant(of: page, matching: find.byType(TabBar)),
            )
            .controller!
            .index,
        entry.$2,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
    expect(source.writes, isEmpty);
  });

  for (final state in [0, 1, 2]) {
    testWidgets('状态 $state 确认后仅提交一次；取消不写入', (tester) async {
      final source = JobsFixture()..rows.removeRange(1, 25);
      source.rows[0]['status'] = state;
      await open(tester, source);
      final action = find.byKey(const ValueKey('job-status-1'));
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text(state == 1 ? '确认下线' : '确认上线'), findsOneWidget);
      if (state == 2) expect(find.textContaining('恢复为在招'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(source.writes, isEmpty);
      source.statusGate = Completer<void>();
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(source.writes, [(1, state == 1 ? 0 : 1)]);
      final button = tester.widget<OutlinedButton>(action);
      expect(button.onPressed, isNull);
      source.statusGate!.complete();
      await tester.pumpAndSettle();
      expect(source.writes.length, 1);
      expect(source.rows[0]['status'], state == 1 ? 0 : 1);
    });
  }

  for (final error in [
    const ApiException('拒绝', code: 403),
    const ApiException('失效', code: 401),
    const ApiException('连接超时'),
    const ApiException('服务错误', code: 500),
  ]) {
    testWidgets('错误 ${error.code ?? error.message} 可重试', (tester) async {
      final source = JobsFixture()..error = error;
      await open(tester, source);
      final action = find.widgetWithText(
        OutlinedButton,
        error.code == 403 ? '重新检查' : '重试',
      );
      expect(action, findsOneWidget);
      source.error = null;
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byType(JobListCard), findsWidgets);
    });
  }

  testWidgets('骨架加载、空态、清除条件恢复', (tester) async {
    final source = JobsFixture()
      ..loadGate = Completer<List<Map<String, dynamic>>>();
    await open(tester, source);
    expect(find.byType(SkeletonList), findsOneWidget);
    source.loadGate!.complete([]);
    source.loadGate = null;
    await tester.pumpAndSettle();
    expect(find.text('暂无岗位'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('jobs-search')),
      'no-match',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('清除条件'));
    await tester.pumpAndSettle();
    expect(find.byType(JobListCard), findsWidgets);
  });

  testWidgets('旧搜索请求不会覆盖新筛选结果', (tester) async {
    final source = JobsFixture();
    await open(tester, source);
    final old = Completer<List<Map<String, dynamic>>>();
    source.loadGate = old;
    await tester.tap(find.byKey(const ValueKey('jobs-filter-0')));
    await tester.pump();
    source.loadGate = null;
    await tester.tap(find.byKey(const ValueKey('jobs-filter-1')));
    await tester.pumpAndSettle();
    old.complete([
      {'posId': 999, 'title': '过期响应', 'status': 0},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('过期响应'), findsNothing);
    expect(source.calls.last.status, 1);
  });

  testWidgets('发布成功保留原列表刷新与查看岗位入口', (tester) async {
    final source = JobsFixture();
    await open(
      tester,
      source,
      publishBuilder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).pop(1),
          child: const Text('合成发布完成'),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('jobs-publish')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('合成发布完成'));
    await tester.pumpAndSettle();
    expect(source.calls.length, 2);
    expect(find.text('岗位发布成功，已更新岗位列表'), findsOneWidget);
  });

  for (final size in [const Size(320, 640), const Size(900, 420)]) {
    testWidgets('列表在 $size 不溢出', (tester) async {
      await open(tester, JobsFixture(), size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('发布岗位'), findsOneWidget);
    });
  }
}
