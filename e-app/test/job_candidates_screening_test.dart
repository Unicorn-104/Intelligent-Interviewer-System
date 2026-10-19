import 'dart:async';

import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/data/job_detail_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/job_detail_page.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/widgets/job_candidates_tab.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/job_detail_fixture.dart';

class ScreeningSource extends JobDetailDataSource {
  List<Map<String, dynamic>> candidates = [
    {'talId': 11, 'name': '合成求职者甲', 'matchScore': 72},
    {'talId': 12, 'name': '合成求职者乙', 'matchScore': 65},
  ];
  List<Map<String, dynamic>> results = [
    {'resultId': 12, 'totalScore': 96},
    {'resultId': 11, 'totalScore': 80},
    {'resultId': 99, 'totalScore': 100},
  ];
  int reads = 0, starts = 0, details = 0;
  bool failure = false, screenFailure = false;
  Completer<void>? readGate, screenGate;

  @override
  Future<Map<String, dynamic>> loadDetail(int id) async {
    details++;
    return jobDetailJson(candidates: candidates);
  }

  @override
  Future<Map<String, dynamic>> loadProfile(int id) async => profileJson();
  @override
  Future<Map<String, dynamic>> loadWorkflow(int id) async => {'stages': []};
  @override
  Future<List<Map<String, dynamic>>> loadScores(int id) async {
    reads++;
    await readGate?.future;
    if (failure) throw const ApiException('合成评分网络失败');
    return results;
  }

  @override
  Future<Map<String, dynamic>> startScreening(int id) async {
    starts++;
    await screenGate?.future;
    if (screenFailure) throw const ApiException('筛选刷新失败，请重试');
    return {'taskId': id};
  }
}

Future<void> mountCandidates(
  WidgetTester tester,
  ScreeningSource source, {
  Size size = const Size(430, 1000),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: JobDetailPage(
        job: const {'posId': 1},
        initialTab: 1,
        source: source,
        candidateBuilder: (candidate) =>
            Scaffold(body: Text('合成详情 ${candidate['talId']}')),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  if (source.readGate == null) await tester.pumpAndSettle();
}

void main() {
  testWidgets('合并名单只含当前岗位求职者，应用 AI 分数排序，点击进入同一人详情', (tester) async {
    final source = ScreeningSource();
    await mountCandidates(tester, source);
    expect(find.byType(JobCandidateCard), findsNWidgets(2));
    expect(find.byKey(const ValueKey('job-candidate-99')), findsNothing);
    final first = find.byKey(const ValueKey('job-candidate-12'));
    final second = find.byKey(const ValueKey('job-candidate-11'));
    expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(second).dy));
    expect(find.text('通用评分：96'), findsOneWidget);
    expect(source.starts, 0);
    expect(source.reads, 1);
    await tester.tap(first);
    await tester.pumpAndSettle();
    expect(find.text('合成详情 12'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('基础信息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('求职者'));
    await tester.pumpAndSettle();
    expect(source.reads, 1);
    expect(source.starts, 0);
  });

  testWidgets('评分加载及失败不隐藏名单，单独重试成功后更新分数', (tester) async {
    final source = ScreeningSource()
      ..failure = true
      ..readGate = Completer<void>();
    await mountCandidates(tester, source);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('合成求职者甲'), findsOneWidget);
    expect(find.text('通用评分：72'), findsOneWidget);
    source.readGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('合成评分网络失败'), findsOneWidget);
    expect(find.byType(JobCandidateCard), findsNWidgets(2));
    source.failure = false;
    await tester.tap(find.byKey(const Key('job-scores-retry')));
    await tester.pumpAndSettle();
    expect(find.text('合成评分网络失败'), findsNothing);
    expect(find.text('通用评分：96'), findsOneWidget);
    expect(source.reads, 2);
    expect(source.starts, 0);
  });

  testWidgets('点击直接刷新筛选，执行中阻止重复并刷新同一份名单', (tester) async {
    final source = ScreeningSource()..screenGate = Completer<void>();
    await mountCandidates(tester, source);
    expect(source.starts, 0);
    final action = find.byKey(const Key('job-rescreen'));
    expect(
      find.descendant(of: action, matching: find.byIcon(Icons.refresh)),
      findsOneWidget,
    );
    await tester.tap(action);
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('筛选中…'), findsOneWidget);
    await tester.tap(action);
    await tester.pump();
    expect(source.starts, 1);
    source.results = [
      {'resultId': 11, 'totalScore': 99},
    ];
    source.screenGate!.complete();
    await tester.pumpAndSettle();
    expect(source.details, 2);
    expect(source.reads, 2);
    expect(find.byType(JobCandidateCard), findsNWidgets(2));
    expect(find.text('通用评分：99'), findsOneWidget);
  });

  testWidgets('刷新筛选失败保留名单，不自动重发并恢复按钮以供手动重试', (tester) async {
    final source = ScreeningSource()..screenFailure = true;
    await mountCandidates(tester, source);
    final action = find.byKey(const Key('job-rescreen'));
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('筛选刷新失败，请重试'), findsOneWidget);
    expect(find.byType(JobCandidateCard), findsNWidgets(2));
    expect(find.text('AI辅助筛选'), findsOneWidget);
    expect(source.starts, 1);
    expect(find.byType(AlertDialog), findsNothing);
    source.screenFailure = false;
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(source.starts, 2);
    expect(find.text('筛选刷新失败，请重试'), findsNothing);
    expect(find.byType(JobCandidateCard), findsNWidgets(2));
  });

  testWidgets('空评分保留原通用评分，下拉刷新同时更新名单和评分', (tester) async {
    final source = ScreeningSource()..results = [];
    await mountCandidates(tester, source);
    expect(find.text('暂无评分数据'), findsOneWidget);
    expect(find.text('通用评分：72'), findsOneWidget);
    source.candidates = [
      {'talId': 12, 'name': '合成求职者乙', 'matchScore': 65},
    ];
    source.results = [
      {'resultId': 12, 'totalScore': 88},
    ];
    await tester.drag(
      find.byKey(const PageStorageKey('job-candidates-scroll')),
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();
    expect(source.details, 2);
    expect(source.reads, 2);
    expect(find.byType(JobCandidateCard), findsOneWidget);
    expect(find.text('通用评分：88'), findsOneWidget);
    expect(find.text('合成求职者甲'), findsNothing);
  });

  for (final count in [0, 101]) {
    testWidgets('求职者数量 $count 保留空态或超量保护，不请求评分或发起筛选', (tester) async {
      final source = ScreeningSource()
        ..candidates = List.generate(
          count,
          (i) => {'talId': i + 1, 'name': '合成求职者$i'},
        );
      await mountCandidates(tester, source);
      expect(find.text(count == 0 ? '暂无求职者' : '数据量过大，暂无法完整展示'), findsOneWidget);
      expect(find.byKey(const Key('job-rescreen')), findsNothing);
      expect(source.reads, 0);
      expect(source.starts, 0);
    });
  }

  for (final setting in [
    (const Size(320, 700), 1.0),
    (const Size(900, 420), 1.0),
    (const Size(320, 700), 2.0),
  ]) {
    testWidgets('合并页在 ${setting.$1} 字号 ${setting.$2} 无溢出且可滚动', (tester) async {
      final source = ScreeningSource()
        ..candidates.first['name'] = '合成超长求职者名称的兼容性验证内容';
      await mountCandidates(
        tester,
        source,
        size: setting.$1,
        scale: setting.$2,
      );
      expect(tester.takeException(), isNull);
      final target = find.byKey(const ValueKey('job-candidate-11'));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      expect(target, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
