import 'dart:async';

import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/data/job_detail_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/job_detail_page.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/widgets/job_candidates_tab.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/job_detail_fixture.dart';
import 'support/talent_detail_fixture.dart';

import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_greeting_sheet.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_interview_invite_sheet.dart';

class ScreeningSource extends JobDetailDataSource {
  final actions = TalentFakeSource();
  @override
  TalentFakeSource get candidateActionsSource => actions;
  List<Map<String, dynamic>> candidates = [
    {'talId': 11, 'name': '合成求职者甲', 'matchScore': 72},
    {'talId': 12, 'name': '合成求职者乙', 'matchScore': 65},
  ];
  List<Map<String, dynamic>> results = [
    {'resultId': 12, 'totalScore': 96},
    {'resultId': 11, 'totalScore': 80},
    {'resultId': 99, 'totalScore': 100},
  ];
  int reads = 0, starts = 0, details = 0, resumeReads = 0;
  bool resumeFailure = false;
  Map<String, dynamic> resume = {
    'educationList': [
      {'school': '合成大学', 'degree': 4},
    ],
  };
  @override
  Future<Map<String, dynamic>> loadCandidateResume(int id) async {
    resumeReads++;
    if (resumeFailure) throw const ApiException('合成简历读取失败');
    return resume;
  }

  bool failure = false, screenFailure = false, legacyResponse = false;
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
    return {'taskId': id, if (!legacyResponse) 'processing': false};
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
    expect(find.text('96.0'), findsOneWidget);
    expect(source.starts, 0);
    expect(source.reads, 1);
    await tester.tap(find.byKey(const ValueKey('job-candidate-expand-12')));
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

  testWidgets('姓名旁展示真实状态与阶段，右侧环形评分，未接入操作不伪造写入', (tester) async {
    final source = ScreeningSource();
    source.candidates[1].addAll({
      'statusLabel': '面试中',
      'statusCode': 2,
      'currentStage': '技术面试',
    });
    await mountCandidates(tester, source);
    final card = find.byKey(const ValueKey('job-candidate-12'));
    expect(
      find.descendant(of: card, matching: find.text('面试中')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('技术面试')),
      findsOneWidget,
    );
    final expand = find.byKey(const ValueKey('job-candidate-expand-12'));
    final ring = find.descendant(
      of: card,
      matching: find.byType(CircularProgressIndicator),
    );
    expect(tester.getTopRight(ring).dx, lessThan(tester.getTopLeft(expand).dx));
    expect(tester.getSize(expand).width, 44);
    expect(tester.getSize(expand).height, tester.getSize(card).height);
    final rail = tester.widget<Material>(
      find.ancestor(of: expand, matching: find.byType(Material)).first,
    );
    expect(rail.color, AppColors.hairline);
    expect(
      find.descendant(of: card, matching: find.text('合成大学 · 硕士')),
      findsOneWidget,
    );
    expect(find.text('查看求职者资料'), findsNothing);
    expect(find.text('通用'), findsNothing);
    expect(find.text('调整评分'), findsNothing);
    expect(find.text('#1'), findsNothing);
    expect(tester.getSize(ring).width, 56);
    expect(
      find.descendant(of: card, matching: find.byIcon(Icons.edit_outlined)),
      findsOneWidget,
    );
    final name = find.descendant(of: card, matching: find.text('合成求职者乙'));
    final education = find.descendant(
      of: card,
      matching: find.text('合成大学 · 硕士'),
    );
    expect(
      tester.getTopLeft(name).dy,
      lessThanOrEqualTo(tester.getTopLeft(ring).dy + 4),
    );
    expect(tester.getTopLeft(education).dx, tester.getTopLeft(name).dx);
    expect(tester.getSize(card).height, lessThan(260));

    expect(
      find.descendant(of: card, matching: find.text('96.0')),
      findsOneWidget,
    );
    final adjust = find.byKey(const ValueKey('job-candidate-adjust-12'));
    expect(tester.getTopLeft(adjust).dx, tester.getTopLeft(ring).dx);
    expect(
      tester.getTopRight(adjust).dx,
      lessThanOrEqualTo(tester.getTopLeft(expand).dx),
    );
    await tester.ensureVisible(adjust);
    await tester.tap(adjust);
    await tester.pumpAndSettle();
    expect(find.text('评分调整功能开发中'), findsOneWidget);
    expect(find.text('合成详情 12'), findsNothing);
    expect(find.text('录用'), findsNothing);
    expect(find.text('淘汰'), findsNothing);
    final more = find.byKey(const ValueKey('job-candidate-12-more'));
    await tester.tap(more);
    await tester.pumpAndSettle();
    final reject = find.byKey(const ValueKey('job-candidate-12-reject'));
    expect(
      tester
          .widget<Text>(find.descendant(of: reject, matching: find.text('淘汰')))
          .style!
          .color,
      AppColors.error,
    );
    final hire = find.byKey(const ValueKey('job-candidate-12-hire'));
    expect(
      tester
          .widget<Text>(find.descendant(of: hire, matching: find.text('录用')))
          .style!
          .color,
      AppColors.success,
    );
    await tester.tap(reject);
    await tester.pumpAndSettle();
    expect(find.text('淘汰功能开发中'), findsOneWidget);
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('job-candidate-12-hire')));
    await tester.pumpAndSettle();
    expect(find.text('录用功能开发中'), findsOneWidget);
    expect(find.byType(JobCandidateCard), findsNWidgets(2));
    expect(source.starts, 0);
    expect(source.details, 1);
    expect(source.reads, 1);
  });

  testWidgets('岗位求职者卡片直接复用打招呼和邀约面板，保留岗位上下文且不自动提交', (tester) async {
    final source = ScreeningSource();
    source.actions.workflow = {
      'stages': [
        {'stageId': 21, 'name': '在线笔试', 'sortOrder': 1},
        {'stageId': 22, 'name': '技术面试', 'sortOrder': 2},
      ],
    };
    source.actions.plan = [
      {
        'appointmentId': 81,
        'candidateId': 12,
        'positionId': 1,
        'stageId': 21,
        'status': 3,
      },
    ];
    await mountCandidates(tester, source);
    final card = find.byKey(const ValueKey('job-candidate-12'));
    final firstStage = find.descendant(of: card, matching: find.text('在线笔试'));
    expect(firstStage, findsOneWidget);
    expect(
      tester.getBottomLeft(firstStage).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('job-candidate-12-greeting')))
            .dy,
      ),
    );
    final greenLine = tester.widget<Container>(
      find.descendant(
        of: card,
        matching: find.byKey(const ValueKey('talent-flow-line-21')),
      ),
    );
    expect(greenLine.color, AppColors.success);
    await tester.tap(find.byKey(const ValueKey('job-candidate-12-greeting')));
    await tester.pumpAndSettle();
    final greeting = tester.widget<TalentGreetingSheet>(
      find.byType(TalentGreetingSheet),
    );
    expect(greeting.candidateId, 12);
    expect(greeting.job!.positionId, 1);
    expect(source.actions.greetingCalls, 1);
    expect(source.actions.invites, isEmpty);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('job-candidate-12-invite')));
    await tester.pumpAndSettle();
    final invite = tester.widget<TalentInterviewInviteSheet>(
      find.byType(TalentInterviewInviteSheet),
    );
    expect(invite.candidateId, 12);
    expect(invite.job!.positionId, 1);
    expect(invite.job!.title, 'Java工程师');
    expect(source.actions.stageInvites, isEmpty);
    expect(source.actions.invites, isEmpty);
    await tester.tap(find.byKey(const Key('invite-close')));
    await tester.pumpAndSettle();
    expect(find.byType(TalentInterviewInviteSheet), findsNothing);
    expect(find.byType(JobCandidateCard), findsNWidgets(2));
  });

  testWidgets('教育信息独立失败可重试，评分刷新不重复读取简历', (tester) async {
    final source = ScreeningSource()..resumeFailure = true;
    await mountCandidates(tester, source);
    final retry = find.byKey(
      const ValueKey('job-candidate-education-retry-12'),
    );
    expect(find.text('教育信息暂不可用'), findsNWidgets(2));
    expect(find.text('96.0'), findsOneWidget);
    expect(source.resumeReads, 2);
    source.resumeFailure = false;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.text('合成大学 · 硕士'), findsOneWidget);
    expect(source.resumeReads, 3);
    await tester.tap(find.byKey(const Key('job-rescreen')));
    await tester.pumpAndSettle();
    expect(source.resumeReads, 3);
    expect(source.starts, 1);
  });

  testWidgets('缺失教育经历显示空态，完整学历信息不伪造', (tester) async {
    final source = ScreeningSource()..resume = {'educationList': []};
    await mountCandidates(tester, source);
    expect(find.text('学校未填写 · 学历未填写'), findsNWidgets(2));
    expect(find.text('合成大学 · 硕士'), findsNothing);
    expect(find.text('查看求职者资料'), findsNothing);
    expect(find.byType(JobCandidateCard), findsNWidgets(2));
  });

  testWidgets('评分加载及失败不隐藏名单，单独重试成功后更新分数', (tester) async {
    final source = ScreeningSource()
      ..failure = true
      ..readGate = Completer<void>();
    await mountCandidates(tester, source);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('合成求职者甲'), findsOneWidget);
    expect(find.text('72.0'), findsOneWidget);
    source.readGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('合成评分网络失败'), findsOneWidget);
    expect(find.byType(JobCandidateCard), findsNWidgets(2));
    source.failure = false;
    await tester.tap(find.byKey(const Key('job-scores-retry')));
    await tester.pumpAndSettle();
    expect(find.text('合成评分网络失败'), findsNothing);
    expect(find.text('96.0'), findsOneWidget);
    expect(source.reads, 2);
    expect(source.starts, 0);
  });

  testWidgets('旧版服务器响应明确提示部署新版，不声称AI分析成功', (tester) async {
    final source = ScreeningSource()..legacyResponse = true;
    await mountCandidates(tester, source);
    await tester.tap(find.byKey(const Key('job-rescreen')));
    await tester.pumpAndSettle();
    expect(find.text('服务器尚未部署新版AI筛选服务，请先更新服务器后端'), findsOneWidget);
    expect(source.starts, 1);
    expect(source.reads, 2);
  });

  testWidgets('点击增量分析先读缓存再补充求职者，执行中阻止重复', (tester) async {
    final source = ScreeningSource()..screenGate = Completer<void>();
    await mountCandidates(tester, source);
    expect(source.starts, 0);
    final action = find.byKey(const Key('job-rescreen'));
    expect(
      find.descendant(
        of: action,
        matching: find.byIcon(Icons.auto_awesome_outlined),
      ),
      findsOneWidget,
    );
    await tester.tap(action);
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('分析中…'), findsOneWidget);
    await tester.tap(action);
    await tester.pump();
    expect(source.starts, 1);
    source.results = [
      {'resultId': 11, 'totalScore': 99},
    ];
    source.screenGate!.complete();
    await tester.pumpAndSettle();
    expect(source.details, 3);
    expect(source.reads, 3);
    expect(find.byType(JobCandidateCard), findsNWidgets(2));
    expect(find.text('99.0'), findsOneWidget);
  });

  testWidgets('刷新筛选失败保留名单，不自动重发并恢复按钮以供手动重试', (tester) async {
    final source = ScreeningSource()..screenFailure = true;
    await mountCandidates(tester, source);
    final action = find.byKey(const Key('job-rescreen'));
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('筛选刷新失败，请重试'), findsOneWidget);
    expect(find.byType(JobCandidateCard), findsNWidgets(2));
    expect(find.text('增量分析'), findsOneWidget);
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
    expect(find.text('72.0'), findsOneWidget);
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
    expect(find.text('88.0'), findsOneWidget);
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
      await tester.dragUntilVisible(
        target,
        find.byKey(const PageStorageKey('job-candidates-scroll')),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(target, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
