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

void main() {
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
    await scrollTalentTo(tester, find.text('通用评分，非岗位维度'));
    expect(find.text('88 分'), findsOneWidget);
    await scrollTalentTo(tester, find.text('岗位技能分析'));
    expect(find.text('选择岗位后查看'), findsOneWidget);
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
    expect(find.text('候选人已有报告，未提供岗位归属信息'), findsOneWidget);
    expect(find.text('报告正文：合成报告正文'), findsOneWidget);
  });
  testWidgets('岗位分析失败保留通用评分，重试仅加载岗位分析', (tester) async {
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
    expect(find.text('88 分'), findsOneWidget);
    final match = find.byType(TalentMatchAnalysisSection);
    final retry = find.descendant(of: match, matching: find.text('重试'));
    await scrollTalentTo(tester, retry);
    source.matchFails = false;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(source.matchCalls, 2);
    expect(source.detailCalls, 1);
    expect(find.text('技能重合度：75%'), findsOneWidget);
    expect(find.text('项目：暂无分析'), findsOneWidget);
    expect(find.text('学历：暂无分析'), findsOneWidget);
    expect(find.text('行业：暂无分析'), findsOneWidget);
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
    expect(find.text('暂无岗位技能依据'), findsOneWidget);
    expect(find.text('技能重合度：0%'), findsNothing);
    await scrollTalentTo(tester, find.byType(TalentRecommendationSection));
    expect(find.text('暂无候选人推荐报告'), findsOneWidget);
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
    state.data = {'content': '实际内容'};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TalentRecommendationSection(state: state, onRetry: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('报告正文：实际内容'), findsOneWidget);
    expect(find.textContaining('报告状态：'), findsNothing);
    expect(find.textContaining('发送时间：'), findsNothing);
  });
}
