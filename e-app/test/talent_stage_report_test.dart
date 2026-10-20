import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/data/talent_detail_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/data/talent_stage_report_loader.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/models/talent_detail_view_data.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_stage_report_sheet.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_workflow_progress.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';

Map<String, dynamic> record(int session, {int stage = 1, int status = 3}) => {
  'candidateId': 11,
  'positionId': 7,
  'stageId': stage,
  'appointmentId': session + 100,
  'sessionId': session,
  'status': status,
};
Map<String, dynamic> contextFor(
  int session, {
  String? start = '2026-10-18 09:00:00',
  int status = 2,
}) => {
  'sessionId': session,
  'appointmentId': session + 100,
  'candidateId': 11,
  'positionId': 7,
  'status': status,
  'startAt': start,
};
Map<String, dynamic> reportFor(int session) => {
  'sessionId': session,
  'candidateId': 11,
  'overallScore': 86.5,
  'summary': '本轮合成总结$session',
  'advantages': ['合成亮点'],
  'risks': '合成风险',
  'gaps': '合成待提升项',
  'dimensionScores': {'技术': 90, '协作': null},
  'recommendation': '合成建议',
};

class StageSource extends TalentDetailDataSource {
  List<Map<String, dynamic>> records = [];
  Map<int, Map<String, dynamic>> sessions = {};
  Map<int, Map<String, dynamic>> reports = {};
  final queries = <int>[];
  int plans = 0;
  bool failSession = false, failReport = false;
  Completer<Map<String, dynamic>>? sessionGate, reportGate;
  @override
  Future<Map<String, dynamic>> loadWorkflow(int id) async => {
    'stages': [
      {'stageId': 1, 'name': '合成技术面试', 'sortOrder': 1},
      {'stageId': 2, 'name': '合成HR面试', 'sortOrder': 2},
    ],
  };
  @override
  Future<List<Map<String, dynamic>>> loadCandidatePlan(
    int candidate,
    int position,
  ) async {
    plans++;
    return records;
  }

  @override
  Future<Map<String, dynamic>> loadWorkflowSession(int id) async {
    if (failSession) throw const ApiException('会话读取失败，请重试');
    return await sessionGate?.future ?? sessions[id] ?? {};
  }

  @override
  Future<Map<String, dynamic>> loadInterviewReport(int id) async {
    queries.add(id);
    if (failReport) throw const ApiException('报告读取失败，请重试');
    if (reportGate != null) return await reportGate!.future;
    if (!reports.containsKey(id)) throw const ApiException('面试记录或评估结果不存在');
    return reports[id]!;
  }
}

Future<void> mount(
  WidgetTester tester,
  StageSource source, {
  Size size = const Size(430, 800),
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
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TalentWorkflowProgress(
            candidateId: 11,
            job: const TalentJobContext(positionId: 7, title: '合成岗位'),
            source: source,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapStage(WidgetTester tester, [int id = 1]) async {
  await tester.tap(find.byKey(ValueKey('talent-flow-stage-$id')));
  await tester.pumpAndSettle();
}

StageSource ready() => StageSource()
  ..records = [record(21)]
  ..sessions = {21: contextFor(21)}
  ..reports = {21: reportFor(21)};

void main() {
  test('场次解析只选当前候选人岗位阶段，取消与其他轮次排除', () async {
    final source = ready()
      ..records = [
        record(21),
        record(22, stage: 2),
        record(23, status: 2),
        {...record(24), 'candidateId': 99},
        {...record(25), 'positionId': 99},
      ];
    final sessions = await loadTalentStageSessions(
      source: source,
      candidateId: 11,
      positionId: 7,
      stageId: 1,
    );
    expect(sessions.map((s) => s.id), [21]);
    expect(source.queries, isEmpty);
  });

  testWidgets('未开始点击显示中央提示，无确认按钮，两秒自动消失', (tester) async {
    final source = StageSource();
    await mount(tester, source);
    await tapStage(tester);
    final hint = find.text('本轮还未进行面试');
    expect(hint, findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(TalentStageReportSheet), findsNothing);
    expect(source.queries, isEmpty);
    expect(tester.getCenter(hint).dy, closeTo(400, 40));
    await tester.pump(const Duration(seconds: 2));
    expect(hint, findsNothing);
  });

  testWidgets('仅预约或已过期不显示其他阶段报告，无实际开场仍为未进行', (tester) async {
    final source = StageSource()
      ..records = [record(21, status: 0), record(22, stage: 2)]
      ..sessions = {
        21: contextFor(21, start: null, status: 0),
        22: contextFor(22),
      }
      ..reports = {22: reportFor(22)};
    await mount(tester, source);
    await tapStage(tester);
    expect(find.text('本轮还未进行面试'), findsOneWidget);
    expect(source.queries, isEmpty);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('已开始报告仅展示该轮真实返回字段，关闭正常', (tester) async {
    final source = ready();
    await mount(tester, source);
    expect(source.queries, isEmpty);
    await tapStage(tester);
    expect(find.byType(TalentStageReportSheet), findsOneWidget);
    expect(find.text('合成技术面试'), findsNWidgets(2));
    expect(find.text('本轮合成总结21'), findsOneWidget);
    expect(find.text('86.5 分'), findsOneWidget);
    expect(find.text('技术：90'), findsOneWidget);
    expect(find.textContaining('协作：0'), findsNothing);
    expect(source.queries, [21]);
    await tester.tap(find.byKey(const Key('talent-stage-report-close')));
    await tester.pumpAndSettle();
    expect(find.byType(TalentStageReportSheet), findsNothing);
  });

  testWidgets('进行中无报告显示尚未生成，重试只重读本轮', (tester) async {
    final source = ready()
      ..sessions = {21: contextFor(21, status: 1)}
      ..reports = {};
    await mount(tester, source);
    await tapStage(tester);
    expect(find.text('本轮面试已开始，AI总结报告尚未生成'), findsOneWidget);
    expect(find.text('本轮还未进行面试'), findsNothing);
    source.reports[21] = reportFor(21);
    await tester.tap(find.byKey(const Key('talent-stage-report-retry')));
    await tester.pumpAndSettle();
    expect(find.text('本轮合成总结21'), findsOneWidget);
    expect(source.queries, [21, 21]);
  });

  testWidgets('完成但缺少会话不冒充未开始', (tester) async {
    final source = StageSource()
      ..records = [
        {...record(21), 'sessionId': null},
      ];
    await mount(tester, source);
    await tapStage(tester);
    expect(find.text('本轮暂无可查看的AI总结报告'), findsOneWidget);
    expect(find.text('本轮还未进行面试'), findsNothing);
    expect(source.queries, isEmpty);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('同阶段多场面试可切换，默认最新，不替换成其他阶段报告', (tester) async {
    final source = ready()
      ..records = [record(20), record(21), record(99, stage: 2)]
      ..sessions = {
        20: contextFor(20, start: '2026-10-17 09:00:00'),
        21: contextFor(21),
        99: contextFor(99),
      }
      ..reports = {20: reportFor(20), 21: reportFor(21), 99: reportFor(99)};
    await mount(tester, source);
    await tapStage(tester);
    expect(find.text('本轮合成总结21'), findsOneWidget);
    await tester.tap(find.byKey(const Key('talent-stage-report-session')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-10-17 09:00:00').last);
    await tester.pumpAndSettle();
    expect(find.text('本轮合成总结20'), findsOneWidget);
    expect(source.queries, [21, 20]);
    expect(find.text('本轮合成总结99'), findsNothing);
  });

  testWidgets('会话归属或报告身份不符拒绝展示，原文不泄露', (tester) async {
    final source = ready()
      ..sessions = {
        21: {...contextFor(21), 'candidateId': 99},
      };
    await mount(tester, source);
    await tapStage(tester);
    expect(find.text('本轮面试记录不一致，请刷新后重试'), findsOneWidget);
    expect(source.queries, isEmpty);
    await tester.pump(const Duration(seconds: 2));
    source.sessions[21] = contextFor(21);
    source.reports[21] = {
      ...reportFor(21),
      'sessionId': 99,
      'summary': '不应显示的其他场次内容',
    };
    await tapStage(tester);
    expect(find.text('报告与本轮面试不匹配，暂无法展示'), findsOneWidget);
    expect(find.text('不应显示的其他场次内容'), findsNothing);
  });

  testWidgets('会话失败不显示未开始，点击可重试；报告失败独立重试', (tester) async {
    final source = ready()..failSession = true;
    await mount(tester, source);
    await tapStage(tester);
    expect(find.text('会话读取失败，请重试'), findsOneWidget);
    expect(find.text('本轮还未进行面试'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    source.failSession = false;
    source.failReport = true;
    await tapStage(tester);
    expect(find.text('报告读取失败，请重试'), findsOneWidget);
    source.failReport = false;
    await tester.tap(find.byKey(const Key('talent-stage-report-retry')));
    await tester.pumpAndSettle();
    expect(find.text('本轮合成总结21'), findsOneWidget);
  });

  testWidgets('重复点击只开一个报告，销毁时清除提示', (tester) async {
    final source = ready();
    await mount(tester, source);
    source.sessionGate = Completer<Map<String, dynamic>>();
    final before = source.plans;
    await tester.tap(find.byKey(const ValueKey('talent-flow-stage-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('talent-flow-stage-1')));
    await tester.pump();
    expect(source.plans, before + 1);
    source.sessionGate!.complete(contextFor(21));
    await tester.pumpAndSettle();
    expect(find.byType(TalentStageReportSheet), findsOneWidget);
    expect(source.queries, [21]);
    await tester.tap(find.byKey(const Key('talent-stage-report-close')));
    await tester.pumpAndSettle();
    await tapStage(tester, 2);
    expect(find.text('本轮还未进行面试'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(find.text('本轮还未进行面试'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('报告加载保留关闭入口，关闭后迟到响应不更新已销毁面板', (tester) async {
    final source = ready()..reportGate = Completer<Map<String, dynamic>>();
    await mount(tester, source);
    await tester.tap(find.byKey(const ValueKey('talent-flow-stage-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TalentStageReportSheet), findsOneWidget);
    expect(find.byKey(const Key('talent-stage-report-close')), findsOneWidget);
    await tester.tap(find.byKey(const Key('talent-stage-report-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    source.reportGate!.complete(reportFor(21));
    await tester.pumpAndSettle();
    expect(find.byType(TalentStageReportSheet), findsNothing);
    expect(find.text('本轮合成总结21'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('本轮报告在$size及长正文大字号下无溢出', (tester) async {
      final source = ready();
      source.reports[21]!['summary'] = List.filled(120, '合成面试总结正文').join();
      await mount(tester, source, size: size, scale: 1.5);
      await tapStage(tester);
      expect(find.byType(TalentStageReportSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byKey(const Key('talent-stage-report-content')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
