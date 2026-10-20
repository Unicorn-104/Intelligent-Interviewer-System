import 'dart:async';

import 'package:enterprise_recruiter/features/enterprise/talent/talent_detail_page.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/models/talent_detail_view_data.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_match_analysis_section.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_recommendation_section.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_resume_section.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_status_badge.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/talent_detail_fixture.dart';

import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_candidate_actions.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_greeting_sheet.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_interview_invite_sheet.dart';

void main() {
  testWidgets('资料卡内展示打招呼与拆分邀约按钮，菜单操作与原面板正常', (tester) async {
    final source = TalentFakeSource();
    source.workflow = {
      'stages': [
        {'stageId': 41, 'name': '在线笔试', 'sortOrder': 1},
        {'stageId': 42, 'name': '技术面试', 'sortOrder': 2},
      ],
    };
    source.plan = [
      {
        'appointmentId': 81,
        'candidateId': 11,
        'positionId': 7,
        'stageId': 41,
        'status': 3,
      },
    ];
    await pumpTalentWidget(
      tester,
      TalentDetailPage(
        talent: const {'talentId': 11},
        source: source,
        jobContext: talentTestJob,
      ),
    );
    final pageAppBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(pageAppBar.bottom, isNull);
    final actions = find.byType(TalentCandidateActions);
    expect(
      find.ancestor(of: actions, matching: find.byType(Card)),
      findsOneWidget,
    );
    expect(find.byKey(const Key('talent-greeting')), findsOneWidget);
    expect(find.byKey(const Key('talent-invite')), findsOneWidget);
    expect(find.text('在线笔试'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('在线笔试')).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('talent-greeting'))).dy),
    );
    expect(
      tester
          .widget<Container>(find.byKey(const ValueKey('talent-flow-line-41')))
          .color,
      AppColors.success,
    );

    expect(find.text('录用'), findsNothing);
    await tester.tap(find.byKey(const Key('talent-more')));
    await tester.pumpAndSettle();
    expect(find.text('录用'), findsOneWidget);
    expect(find.text('淘汰'), findsOneWidget);
    expect(find.byType(TalentInterviewInviteSheet), findsNothing);
    await tester.tap(find.byKey(const Key('talent-hire')));
    await tester.pumpAndSettle();
    expect(find.text('录用功能开发中'), findsOneWidget);
    await tester.tap(find.byKey(const Key('talent-greeting')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TalentGreetingSheet>(find.byType(TalentGreetingSheet))
          .candidateId,
      11,
    );
    expect(source.greetingCalls, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('talent-invite')));
    await tester.pumpAndSettle();
    final invite = tester.widget<TalentInterviewInviteSheet>(
      find.byType(TalentInterviewInviteSheet),
    );
    expect(invite.job!.positionId, talentTestJob.positionId);
    expect(invite.job!.title, talentTestJob.title);
    expect(invite.job!.currentStage, source.match.currentStage);
    expect(source.invites, isEmpty);
    expect(source.stageInvites, isEmpty);
    await tester.tap(find.byKey(const Key('invite-close')));
    await tester.pumpAndSettle();
    expect(find.byType(TalentInterviewInviteSheet), findsNothing);
  });

  testWidgets('无岗位上下文兼容人才库，简历完整度和缺失字段保留，不发起岗位分析', (tester) async {
    final source = TalentFakeSource();
    await pumpTalentWidget(
      tester,
      TalentDetailPage(
        talent: const {'talentId': 11, 'name': '合成候选人'},
        source: source,
      ),
    );
    expect(find.text('未指定岗位，暂无岗位招聘阶段'), findsOneWidget);
    expect(find.text('完整度 82%'), findsOneWidget);
    expect(find.text('缺失：项目结束时间'), findsOneWidget);
    expect(source.matchCalls, 0);
    expect(source.invites, isEmpty);
    await scrollTalentTo(tester, find.text('综合匹配度'));
    expect(find.text('91.0'), findsOneWidget);
    expect(find.text('合成测试岗位'), findsOneWidget);
  });
  testWidgets('简历失败独立重试，基本资料和报告不被清空', (tester) async {
    final source = TalentFakeSource()..resumeFails = true;
    await pumpTalentWidget(
      tester,
      TalentDetailPage(
        talent: const {'talentId': 11},
        source: source,
        jobContext: talentTestJob,
      ),
    );
    expect(find.text('当前招聘阶段：技术面试'), findsOneWidget);
    final resume = find.byType(TalentResumeSection);
    expect(
      find.descendant(of: resume, matching: find.text('重试')),
      findsOneWidget,
    );
    source.resumeFails = false;
    await tester.tap(find.descendant(of: resume, matching: find.text('重试')));
    await tester.pumpAndSettle();
    expect(find.text('完整度 82%'), findsOneWidget);
    expect(source.resumeCalls, 2);
    expect(source.detailCalls, 1);
    await scrollTalentTo(tester, find.byType(TalentRecommendationSection));
    expect(find.text('推荐理由'), findsOneWidget);
    expect(find.textContaining('合成推荐理由：具备Dart项目经验'), findsOneWidget);
    expect(source.reportCalls, 0);
  });
  testWidgets('岗位分析失败不冒用历史评分，重试仅加载岗位分析', (tester) async {
    final source = TalentFakeSource()
      ..matchFails = true
      ..resume = {};
    await pumpTalentWidget(
      tester,
      TalentDetailPage(
        talent: const {'talentId': 11},
        source: source,
        jobContext: talentTestJob,
      ),
    );
    expect(find.text('88 分'), findsNothing);
    final match = find.byType(TalentMatchAnalysisSection);
    final retry = find.descendant(of: match, matching: find.text('重试'));
    await scrollTalentTo(tester, retry);
    source.matchFails = false;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(source.matchCalls, 2);
    expect(source.detailCalls, 1);
    expect(
      find.byKey(const ValueKey('radar-score-skillMatch')),
      findsOneWidget,
    );
    expect(find.text('75.0'), findsOneWidget);
    expect(find.text('— 资料不足或不适用，不计入综合分'), findsOneWidget);
  });
  testWidgets('无必备技能时不展示服务返回的零分，无报告显示空态', (tester) async {
    final source = TalentFakeSource()
      ..resume = {}
      ..report = null
      ..match = const TalentMatchData(
        requiredSkills: [],
        result: {'skillMatch': 0},
      );
    await pumpTalentWidget(
      tester,
      TalentDetailPage(
        talent: const {'talentId': 11},
        source: source,
        jobContext: talentTestJob,
      ),
    );
    expect(find.text('尚未分析，请在求职者列表点击AI辅助筛选'), findsOneWidget);
    expect(find.text('技能重合度：0%'), findsNothing);
    await scrollTalentTo(tester, find.byType(TalentRecommendationSection));
    expect(find.text('暂无推荐理由'), findsOneWidget);
    expect(source.invites, isEmpty);
  });
  testWidgets('简历加载中独立显示，退出后迟到响应不更新已销毁页面', (tester) async {
    final source = TalentFakeSource()
      ..resumePending = Completer<Map<String, dynamic>>();
    tester.view.physicalSize = const Size(480, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: TalentDetailPage(talent: const {'talentId': 11}, source: source),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(TalentResumeSection),
        matching: find.byType(LinearProgressIndicator),
      ),
      findsOneWidget,
    );
    final statusBadge = find.byType(TalentStatusBadge);
    expect(statusBadge, findsOneWidget);
    final statusLabel = find.descendant(
      of: statusBadge,
      matching: find.text('面试中'),
    );
    final statusIcon = find.descendant(
      of: statusBadge,
      matching: find.byIcon(Icons.arrow_forward),
    );
    expect(statusLabel, findsOneWidget);
    expect(statusIcon, findsOneWidget);
    expect(
      tester.widget<Text>(statusLabel).style?.color,
      AppColors.interactive,
    );
    expect(tester.widget<Icon>(statusIcon).color, AppColors.interactive);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    source.resumePending!.complete(talentResumeJson());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('空评分与报告四态独立，报告失败可重试且只显示实际字段', (tester) async {
    final state = TalentSectionState<Map<String, dynamic>>(
      loading: false,
      error: '合成报告失败',
    );
    await pumpTalentWidget(
      tester,
      TalentRecommendationSection(state: state, onRetry: () {}),
    );
    expect(find.text('合成报告失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    state.error = null;
    state.data = {'source': 'llm', 'recommendation': '实际推荐理由'};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TalentRecommendationSection(state: state, onRetry: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('实际推荐理由'), findsOneWidget);
    expect(find.textContaining('报告状态：'), findsNothing);
    expect(find.textContaining('发送时间：'), findsNothing);
  });
}
