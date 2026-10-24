import 'dart:async';

import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/jobs_page.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/job_detail_page.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/widgets/job_list_card.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/widgets/job_sort_sheet.dart';
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
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  FlutterSecureStorage.setMockInitialValues({});
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
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

JobsFixture sortingFixture() {
  final source = JobsFixture();
  final base = Map<String, dynamic>.of(source.rows.first);
  final fields = <Map<String, dynamic>>[
    {
      'latestApplyTime': '2026-10-16 08:00',
      'publishTime': '2026-01-01 09:00',
      'applicantCount': 4,
    },
    {
      'latestApplyTime': '2026-10-17 08:00',
      'publishTime': '2025-12-31 09:00',
      'applicantCount': '12',
    },
    {
      'latestApplyTime': null,
      'publishTime': '2026-03-04 09:00',
      'applicantCount': 0,
    },
    {'publishTime': '2026-02-01 09:00', 'applicantCount': null},
    {'latestApplyTime': '', 'publishTime': 'invalid', 'applicantCount': -1},
    {
      'latestApplyTime': 'invalid',
      'publishTime': '2026-10-01 09:00',
      'applicantCount': 1.5,
    },
    {
      'latestApplyTime': '2026-10-16 08:00',
      'publishTime': '2026-01-01 09:00',
      'applicantCount': 4,
    },
    {
      'latestApplyTime': '2026-02-30 08:00',
      'lastApplyTime': '2099-01-01 00:00',
      'publishTime': null,
      'applicantCount': 'invalid',
    },
  ];
  source.rows
    ..clear()
    ..addAll([
      for (final (index, values) in fields.indexed)
        {...base, 'posId': index + 1, 'title': '排序岗位 ${index + 1}', ...values},
    ]);
  return source;
}

List<int> displayedJobIds(WidgetTester tester) => [
  for (final card in tester.widgetList<JobListCard>(find.byType(JobListCard)))
    card.job['posId'] as int,
];

Future<void> chooseSort(
  WidgetTester tester,
  JobSortDimension dimension,
  bool ascending,
) async {
  await tester.tap(find.byKey(const ValueKey('jobs-sort')));
  await tester.pumpAndSettle();
  final button = find.byKey(
    ValueKey('jobs-sort-${dimension.name}-${ascending ? 'asc' : 'desc'}'),
  );
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(420, 900),
    const Size(900, 420),
  ]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('搜索栏与发布按钮在$size字号$textScale同行且不溢出', (tester) async {
        final source = JobsFixture();
        await open(tester, source, size: size, textScale: textScale);
        final search = tester.getRect(
          find.byKey(const ValueKey('jobs-search')),
        );
        final publish = tester.getRect(
          find.byKey(const ValueKey('jobs-publish')),
        );
        expect(search.center.dy, closeTo(publish.center.dy, .01));
        expect(search.right + 8, closeTo(publish.left, .01));
        expect(search.width, greaterThan(100));
        expect(publish.height, greaterThanOrEqualTo(46));
        expect(publish.right, lessThanOrEqualTo(size.width - 20));
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byKey(const ValueKey('jobs-publish')),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.enterText(
          find.byKey(const ValueKey('jobs-search')),
          'SMOKE',
        );
        await tester.tap(find.byTooltip('搜索'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('job-list-card-8')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

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
      final button = tester.widget<FilledButton>(action);
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
  testWidgets('默认按实际 latestApplyTime 降序，空值和无效日期置后，相同值稳定', (tester) async {
    final source = sortingFixture();
    final originalRows = [for (final row in source.rows) Map.of(row)];
    await open(tester, source, size: const Size(420, 4000));
    expect(displayedJobIds(tester), [2, 1, 7, 3, 4, 5, 6, 8]);
    expect(find.byTooltip('最新投递 · 新到旧'), findsOneWidget);
    expect(source.calls, hasLength(1));
    expect(source.rows, originalRows);
  });

  for (final scenario in <(JobSortDimension, bool, List<int>)>[
    (JobSortDimension.latestApply, true, [1, 7, 2, 3, 4, 5, 6, 8]),
    (JobSortDimension.latestApply, false, [2, 1, 7, 3, 4, 5, 6, 8]),
    (JobSortDimension.published, true, [2, 1, 7, 4, 3, 6, 5, 8]),
    (JobSortDimension.published, false, [6, 3, 4, 1, 7, 2, 5, 8]),
    (JobSortDimension.applicants, true, [3, 1, 7, 2, 4, 5, 6, 8]),
    (JobSortDimension.applicants, false, [2, 1, 7, 3, 4, 5, 6, 8]),
  ]) {
    testWidgets('排序 ${scenario.$1.label} ${scenario.$2 ? '升序' : '降序'} 仅本地重排', (
      tester,
    ) async {
      final source = sortingFixture();
      await open(tester, source, size: const Size(420, 4000));
      final requests = source.calls.length;
      await chooseSort(tester, scenario.$1, scenario.$2);
      expect(displayedJobIds(tester), scenario.$3);
      expect(find.byType(JobSortSheet), findsNothing);
      expect(source.calls.length, requests);
      expect(source.writes, isEmpty);
    });
  }

  testWidgets('排序弹层仅当前维度方向高亮，关闭不改变选择且不请求', (tester) async {
    final source = sortingFixture();
    await open(tester, source, size: const Size(420, 4000));
    await chooseSort(tester, JobSortDimension.applicants, true);
    final order = displayedJobIds(tester);
    final requests = source.calls.length;
    await tester.tap(find.byKey(const ValueKey('jobs-sort')));
    await tester.pumpAndSettle();
    for (final dimension in JobSortDimension.values) {
      for (final ascending in [true, false]) {
        final button = tester.widget<OutlinedButton>(
          find.byKey(
            ValueKey(
              'jobs-sort-${dimension.name}-${ascending ? 'asc' : 'desc'}',
            ),
          ),
        );
        expect(
          button.style!.foregroundColor!.resolve({}),
          dimension == JobSortDimension.applicants && ascending
              ? AppColors.interactive
              : AppColors.textMuted,
        );
      }
    }
    await tester.tap(find.byKey(const ValueKey('jobs-sort-close')));
    await tester.pumpAndSettle();
    expect(displayedJobIds(tester), order);
    expect(source.calls.length, requests);
  });

  testWidgets('点维度默认降序，刷新后保留所选排序并反映新人数', (tester) async {
    final source = sortingFixture();
    await open(tester, source, size: const Size(420, 4000));
    await tester.tap(find.byKey(const ValueKey('jobs-sort')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('jobs-sort-dimension-applicants')),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('投递人数 · 多到少'), findsOneWidget);
    expect(source.calls, hasLength(1));
    source.rows[2]['applicantCount'] = 30;
    final refresh = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();
    await refresh;
    expect(source.calls, hasLength(2));
    expect(displayedJobIds(tester), [3, 2, 1, 7, 4, 5, 6, 8]);
    expect(find.byTooltip('投递人数 · 多到少'), findsOneWidget);
  });

  testWidgets('筛选重新加载后仍应用当前排序，筛选参数不受排序影响', (tester) async {
    final source = sortingFixture();
    await open(tester, source, size: const Size(420, 4000));
    await chooseSort(tester, JobSortDimension.published, true);
    await tester.tap(find.byKey(const ValueKey('jobs-filter-0')));
    await tester.pumpAndSettle();
    expect(source.calls.last.status, 0);
    expect(source.calls, hasLength(2));
    expect(displayedJobIds(tester), [2, 1, 7, 4, 3, 6, 5, 8]);
    expect(find.byTooltip('岗位发布时间 · 旧到新'), findsOneWidget);
  });

  testWidgets('加载更多后将新数据并入当前排序，排序本身不额外请求', (tester) async {
    final source = JobsFixture();
    for (var index = 0; index < source.rows.length; index++) {
      source.rows[index]['applicantCount'] = index;
    }
    await open(tester, source, size: const Size(420, 8000));
    await chooseSort(tester, JobSortDimension.applicants, false);
    expect(displayedJobIds(tester).first, 20);
    expect(source.calls, hasLength(1));
    final more = find.byKey(const ValueKey('jobs-load-more'));
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(source.calls, hasLength(2));
    expect(source.calls.last.page, 2);
    expect(displayedJobIds(tester).first, 25);
    expect(displayedJobIds(tester).take(5), [25, 24, 23, 22, 21]);
    expect(find.byTooltip('投递人数 · 多到少'), findsOneWidget);
  });

  testWidgets('320dp 筛选可滚动，排序按钮固定且弹层不溢出', (tester) async {
    final source = sortingFixture();
    await open(tester, source, size: const Size(320, 640));
    final sort = find.byKey(const ValueKey('jobs-sort'));
    expect(tester.getSize(sort).width, 76);
    final before = tester.getRect(sort);
    final filters = find.ancestor(
      of: find.byKey(const ValueKey('jobs-filter-null')),
      matching: find.byType(SingleChildScrollView),
    );
    await tester.drag(filters, const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(tester.getRect(sort), before);
    expect(
      find.byKey(const ValueKey('jobs-filter-2')).hitTestable(),
      findsOneWidget,
    );
    await chooseSort(tester, JobSortDimension.published, false);
    expect(tester.takeException(), isNull);
    expect(source.calls, hasLength(1));
    expect(tester.getSize(sort).width, 76);
  });
}
