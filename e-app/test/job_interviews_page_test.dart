import 'dart:async';

import 'package:enterprise_recruiter/features/enterprise/dashboard/widgets/home_interview_preview.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/data/job_detail_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/job_interviews_page.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class JobInterviewsTestSource extends JobDetailDataSource {
  final calls = <({int page, String? from, String? to})>[];
  final pages = <int, List<Map<String, dynamic>>>{};
  Object? error;
  Completer<List<Map<String, dynamic>>>? pending;

  @override
  Future<List<Map<String, dynamic>>> loadInterviews({
    required int pageNum,
    int pageSize = 50,
    String? from,
    String? to,
  }) async {
    calls.add((page: pageNum, from: from, to: to));
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    final rows = pages[pageNum] ?? [];
    return [for (final row in rows) Map.of(row)];
  }
}

Map<String, dynamic> row(
  int id,
  String start,
  int status, {
  int position = 7,
  String? end,
}) => {
  'appointmentId': id,
  'positionId': position,
  'candidateName': '合成候选人$id',
  'interviewerName': '合成面试官',
  'startTime': start,
  'status': status,
  'endTime': ?end,
};

JobInterviewsTestSource fixture() => JobInterviewsTestSource()
  ..pages[1] = [
    row(1, '2030-01-03 10:00', 0, end: '2030-01-03 11:00'),
    row(2, '2030-01-02 10:00', 1, end: '2030-01-02 11:00'),
    row(3, '2030-01-02 08:00', 0, end: '2030-01-02 09:00'),
    row(4, '2030-01-01 08:00', 3, end: '2030-01-01 09:00'),
    row(5, '2030-01-01 07:00', 2, end: '2030-01-01 08:00'),
    row(6, '2030-01-02 09:00', 1, end: '2030-01-02 09:30'),
    row(7, '2030-01-03 10:00', 0, end: '2030-01-03 11:00'),
    row(8, '2030-01-04 10:00', 9),
    row(99, '2030-01-01 06:00', 0, position: 99),
    {...row(100, '2030-01-01 06:00', 0), 'positionId': null},
  ];

Future<void> mount(
  WidgetTester tester,
  JobInterviewsTestSource source, {
  Size size = const Size(420, 4000),
  double scale = 1,
  DateTime Function()? clock,
  DateTimeRange? range,
  Future<void> Function(dynamic)? onStart,
  ValueChanged<DateTimeRange?>? onRangeChanged,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: JobInterviewsPage(
          positionId: 7,
          positionTitle: '当前岗位',
          source: source,
          now: clock ?? () => DateTime.utc(2030, 1, 2, 2),
          initialRange: range,
          onRangeChanged: onRangeChanged,
          onStartInterview: onStart,
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

List<String> ids(WidgetTester tester) => [
  for (final card in tester.widgetList<HomeInterviewPreview>(
    find.byType(HomeInterviewPreview),
  ))
    card.interview.id,
];

Future<void> filter(WidgetTester tester, String status) async {
  final chip = find.byKey(ValueKey('job-interview-filter-$status'));
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> sort(WidgetTester tester, bool descending) async {
  await tester.tap(find.byKey(const Key('job-interview-sort')));
  await tester.pumpAndSettle();
  expect(find.text(descending ? '时间倒序' : '时间正序'), findsOneWidget);
  expect(find.byType(PopupMenuButton<bool>), findsNothing);
  expect(find.byType(CheckedPopupMenuItem<bool>), findsNothing);
}

void main() {
  testWidgets('只显示当前岗位，复用首页卡片，默认开始时间正序且同时间稳定', (tester) async {
    final source = fixture();
    await mount(tester, source);
    expect(ids(tester), ['5', '4', '3', '6', '2', '1', '7', '8']);
    expect(find.text('合成候选人99'), findsNothing);
    expect(find.text('合成候选人100'), findsNothing);
    for (final card in tester.widgetList<HomeInterviewPreview>(
      find.byType(HomeInterviewPreview),
    )) {
      expect(card.interview.positionId, 7);
      expect(card.interview.position, '当前岗位');
    }
    expect(
      find.descendant(
        of: find.byType(HomeInterviewPreview),
        matching: find.text('已失效'),
      ),
      findsNWidgets(2),
    );
    expect(find.text('开始面试'), findsNWidgets(8));
    expect(source.calls, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('正倒序本地重排不请求，切换回正序恢复，排序不改原始数据', (tester) async {
    final source = fixture();
    final original = [for (final item in source.pages[1]!) Map.of(item)];
    await mount(tester, source);
    await sort(tester, true);
    expect(ids(tester), ['8', '1', '7', '2', '6', '3', '4', '5']);
    await sort(tester, false);
    expect(ids(tester), ['5', '4', '3', '6', '2', '1', '7', '8']);
    expect(source.calls, hasLength(1));
    expect(source.pages[1], original);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final sample in <(String, List<String>)>[
    ('pending', ['1', '7']),
    ('confirmed', ['2']),
    ('completed', ['4']),
    ('cancelled', ['5']),
    ('expired', ['3', '6']),
    ('unknown', ['8']),
  ]) {
    testWidgets('状态筛选 ${sample.$1} 与卡片有效状态一致，不请求且不跨岗位', (tester) async {
      final source = fixture();
      await mount(tester, source);
      await filter(tester, sample.$1);
      expect(ids(tester), sample.$2);
      expect(source.calls, hasLength(1));
      await sort(tester, true);
      expect(ids(tester).toSet(), sample.$2.toSet());
      expect(source.calls, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('范围筛选沿用 from/to，清除范围保留状态与排序，刷新仍保留', (tester) async {
    final source = fixture();
    var changed = false;
    await mount(
      tester,
      source,
      range: DateTimeRange(
        start: DateTime(2030, 1, 1),
        end: DateTime(2030, 1, 4),
      ),
      onRangeChanged: (range) {
        changed = true;
        expect(range, isNull);
      },
    );
    expect(source.calls.single.from, '2030-01-01 00:00:00');
    expect(source.calls.single.to, '2030-01-04 23:59:59');
    await filter(tester, 'pending');
    await sort(tester, true);
    await tester.tap(find.byKey(const Key('job-interview-clear')));
    await tester.pumpAndSettle();
    expect(changed, isTrue);
    expect(source.calls.last.from, isNull);
    expect(source.calls.last.to, isNull);
    expect(ids(tester), ['1', '7']);
    expect(find.text('时间倒序'), findsOneWidget);
    final refresh = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();
    await refresh;
    expect(ids(tester), ['1', '7']);
    expect(source.calls, hasLength(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('跨页过滤当前岗位，第一页其他岗位不误判为空', (tester) async {
    final source = JobInterviewsTestSource()
      ..pages[1] = List.generate(
        50,
        (i) => row(i, '2030-01-02 10:00', 0, position: 99),
      )
      ..pages[2] = [row(66, '2030-01-02 11:00', 0)];
    await mount(tester, source);
    expect(source.calls.map((call) => call.page), [1, 2]);
    expect(ids(tester), ['66']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('超过原有100条边界仍提示缩小日期范围，不展示不完整数据', (tester) async {
    final source = JobInterviewsTestSource();
    for (var page = 1; page <= 3; page++) {
      source.pages[page] = List.generate(
        50,
        (i) => row(page * 100 + i, '2030-01-02 10:00', 0),
      );
    }
    await mount(tester, source);
    expect(find.text('数据量过大，请缩小日期范围'), findsOneWidget);
    expect(ids(tester), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('错误重试和加载状态保留，时间无效记录明确提示', (tester) async {
    final source = JobInterviewsTestSource()
      ..pending = Completer<List<Map<String, dynamic>>>();
    await mount(tester, source, settle: false);
    source.pending!.complete([row(1, 'invalid', 0)]);
    source.pending = null;
    await tester.pumpAndSettle();
    expect(find.text('1 条面试记录的开始时间无效，请刷新重试'), findsOneWidget);
    expect(ids(tester), isEmpty);
    source.error = StateError('synthetic failure');
    await tester.tap(find.text('刷新'));
    await tester.pumpAndSettle();
    expect(find.text('面试安排加载失败'), findsOneWidget);
    source.error = null;
    source.pages[1] = [row(2, '2030-01-02 10:00', 0)];
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(ids(tester), ['2']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('无匹配状态可恢复全部状态，不将筛选空态当成无岗位面试', (tester) async {
    final source = JobInterviewsTestSource()
      ..pages[1] = [row(2, '2030-01-02 10:00', 0)];
    await mount(tester, source);
    await filter(tester, 'completed');
    expect(find.text('当前岗位和日期范围内暂无「已完成」面试'), findsOneWidget);
    await tester.tap(find.text('查看全部状态'));
    await tester.pumpAndSettle();
    expect(ids(tester), ['2']);
    expect(source.calls, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('到预约结束时自动移出待面试筛选，失效筛选显示同条记录', (tester) async {
    final source = JobInterviewsTestSource()
      ..pages[1] = [row(2, '2030-01-02 10:00', 0, end: '2030-01-02 10:01')];
    final start = tester.binding.clock.now();
    await mount(
      tester,
      source,
      clock: () => DateTime.utc(
        2030,
        1,
        2,
        2,
      ).add(tester.binding.clock.now().difference(start)),
    );
    await filter(tester, 'pending');
    expect(ids(tester), ['2']);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(ids(tester), isEmpty);
    await filter(tester, 'expired');
    expect(ids(tester), ['2']);
    expect(find.text('已失效'), findsWidgets);
    expect(source.calls, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('开始面试沿用时间门槛和预留会议回调，不打开详情页', (tester) async {
    final source = JobInterviewsTestSource()
      ..pages[1] = [row(2, '2030-01-02 10:00', 0, end: '2030-01-02 11:00')];
    var started = 0;
    await mount(
      tester,
      source,
      onStart: (interview) async {
        expect(interview.positionId, 7);
        started++;
      },
    );
    await tester.tap(find.byKey(const ValueKey('home-interview-action-2')));
    await tester.pumpAndSettle();
    expect(started, 1);
    expect(source.calls, hasLength(2));
    expect(
      Navigator.of(tester.element(find.byType(JobInterviewsPage))).canPop(),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final sample in [
    (const Size(320, 640), 1.0),
    (const Size(320, 640), 2.0),
    (const Size(900, 420), 1.0),
  ]) {
    testWidgets('面试安排 ${sample.$1} 字号 ${sample.$2} 筛选排序与卡片不溢出', (tester) async {
      await mount(tester, fixture(), size: sample.$1, scale: sample.$2);
      await sort(tester, true);
      await filter(tester, 'expired');
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('job-interview-sort')).hitTestable(),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
