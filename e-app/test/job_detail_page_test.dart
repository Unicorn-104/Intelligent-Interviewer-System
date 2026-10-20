import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/job_detail_page.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/job_interviews_page.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/widgets/job_basic_info_tab.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/widgets/job_candidates_tab.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';

import 'support/job_detail_fixture.dart';

Future<void> pumpDetail(
  WidgetTester tester,
  DetailFakeSource source, {
  int initialTab = 0,
}) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: JobDetailPage(
        job: {'posId': 1, 'title': 'Java工程师'},
        source: source,
        initialTab: initialTab,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('加号节点直接新增，保存后刷新节点，旧编辑按钮已移除', (tester) async {
    final source = DetailFakeSource();
    await pumpDetail(tester, source);
    expect(find.byKey(const Key('job-workflow-edit')), findsNothing);
    await tester.tap(find.byKey(const Key('job-workflow-placeholder')));
    await tester.pumpAndSettle();
    expect(find.text('新增招聘流程'), findsOneWidget);
    expect(find.byKey(const Key('job-publish-stage-delete')), findsNothing);
    await tester.tap(find.byKey(const Key('job-publish-stage-save')));
    await tester.pumpAndSettle();
    final stages = source.savedWorkflows.single['stages'] as List;
    expect(stages.length, 2);
    expect(stages.first['name'], '初筛');
    expect(stages.last['name'], 'HR 综合面试');
    expect(source.workflowCalls, 2);
  });

  testWidgets('最后一个阶段删除不发请求，规则选项紧凑且互斥规则保留', (tester) async {
    final source = DetailFakeSource();
    await pumpDetail(tester, source);
    await tester.tap(find.byKey(const Key('job-workflow-node-0')));
    await tester.pumpAndSettle();
    for (final label in ['必选阶段', '允许跳过', '未通过可终止流程']) {
      final tile = find.ancestor(
        of: find.text(label),
        matching: find.byType(CheckboxListTile),
      );
      expect(tester.getSize(tile).height, lessThanOrEqualTo(40));
    }
    await tester.tap(find.text('允许跳过'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.ancestor(
              of: find.text('必选阶段'),
              matching: find.byType(CheckboxListTile),
            ),
          )
          .value,
      isFalse,
    );
    final remove = find.byKey(const Key('job-publish-stage-delete'));
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text('至少保留一个阶段，请先添加新的阶段'), findsOneWidget);
    expect(source.savedWorkflows, isEmpty);
    await tester.tap(find.byKey(const Key('job-publish-stage-cancel')));
    await tester.pumpAndSettle();
    expect(source.savedWorkflows, isEmpty);
  });

  testWidgets('长按节点保留流程排序管理入口', (tester) async {
    await pumpDetail(tester, DetailFakeSource());
    await tester.longPress(find.byKey(const Key('job-workflow-node-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('job-workflow-add-stage')), findsOneWidget);
    expect(find.byKey(const Key('job-workflow-save')), findsOneWidget);
  });

  testWidgets('点击流程节点直接编辑阶段，保存沿用原接口', (tester) async {
    final source = DetailFakeSource();
    await pumpDetail(tester, source);
    final interviews = find.byKey(const Key('job-interviews-entry'));
    final edit = find.byKey(const Key('job-workflow-node-0'));
    expect(edit, findsOneWidget);
    expect(find.text('面试安排'), findsNothing);
    expect(find.text('查看本岗位的面试记录，支持日期范围筛选。'), findsNothing);
    expect(find.byKey(const Key('job-workflow-node-0')), findsOneWidget);
    expect(find.text('可继续添加'), findsOneWidget);
    expect(find.byKey(const Key('job-workflow-edit')), findsNothing);
    expect(
      tester.getBottomLeft(edit).dy,
      lessThan(tester.getTopLeft(interviews).dy),
    );
    expect(source.savedWorkflows, isEmpty);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.text('编辑招聘流程'), findsOneWidget);
    expect(find.byKey(const Key('job-workflow-name')), findsNothing);
    await tester.tap(find.byKey(const Key('job-publish-stage-save')));
    await tester.pumpAndSettle();
    expect(source.savedWorkflows, hasLength(1));
    expect(source.savedWorkflows.single['templateName'], '默认流程');
    expect(
      (source.savedWorkflows.single['stages'] as List).single['name'],
      'HR 综合面试',
    );
    expect(source.workflowCalls, 2);
    expect(find.text('编辑招聘流程'), findsNothing);
  });

  testWidgets('取消编辑不保存，原流程展开后不再出现重复编辑入口', (tester) async {
    final source = DetailFakeSource();
    await pumpDetail(tester, source);
    final edit = find.byKey(const Key('job-workflow-node-0'));
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(source.savedWorkflows, isEmpty);
    final flow = find.byKey(const PageStorageKey('job-workflow-expansion-1'));
    await tester.scrollUntilVisible(
      flow,
      350,
      scrollable: find
          .descendant(
            of: find.byType(JobBasicInfoTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(flow);
    await tester.pumpAndSettle();
    await tester.tap(flow);
    await tester.pumpAndSettle();
    expect(find.text('1. 初筛'), findsOneWidget);
    expect(
      find.descendant(
        of: flow,
        matching: find.byKey(const Key('job-workflow-edit')),
      ),
      findsNothing,
    );
  });

  testWidgets('320dp窄屏流程节点和面试安排入口可见且不溢出', (tester) async {
    await pumpDetail(tester, DetailFakeSource());
    tester.view.physicalSize = const Size(320, 700);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('job-interviews-entry')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('job-workflow-placeholder')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('仅保留两个 Tab，求职者页合入 AI 能力且进入时不自动筛选', (tester) async {
    final source = DetailFakeSource(
      scoreResult: [
        {'resultId': 1, 'totalScore': 88},
      ],
    );
    await pumpDetail(tester, source);
    expect(find.byType(JobBasicInfoTab), findsOneWidget);
    expect(find.byType(JobCandidatesTab), findsNothing);
    expect(tester.widget<TabBar>(find.byType(TabBar)).tabs, hasLength(2));
    expect(find.text('AI筛选'), findsNothing);
    expect(source.scoreCalls, 0);
    expect(source.screenCalls, 0);
    await tester.tap(find.text('求职者'));
    await tester.pumpAndSettle();
    expect(find.byType(JobCandidatesTab), findsOneWidget);
    expect(find.text('AI辅助筛选'), findsOneWidget);
    expect(find.byKey(const Key('job-rescreen')), findsOneWidget);
    expect(source.screenCalls, 0);
    expect(source.scoreCalls, 1);
  });

  testWidgets('AI 评分失败保留同批候选人并显示重试，不清空名单', (tester) async {
    final source = DetailFakeSource(scoreFailure: true);
    await pumpDetail(tester, source, initialTab: 1);
    expect(find.text('候选人甲'), findsOneWidget);
    expect(find.text('候选人乙'), findsOneWidget);
    expect(find.text('加载筛选结果失败，重试'), findsOneWidget);
    expect(find.text('通用评分，非岗位维度'), findsNothing);
    expect(find.text('AI 结果仅供参考'), findsNothing);
    expect(find.text('AI辅助筛选'), findsOneWidget);
  });

  testWidgets('AI辅助筛选点击即执行，不弹出确认框', (tester) async {
    final source = DetailFakeSource();
    await pumpDetail(tester, source, initialTab: 1);
    expect(source.screenCalls, 0);
    await tester.tap(find.byKey(const Key('job-rescreen')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('job-rescreen-confirm')), findsNothing);
    expect(source.screenCalls, 1);
  });

  testWidgets('AI后台分析轮询只读进度，不重复提交，完成后刷新结果', (tester) async {
    final source = DetailFakeSource()..asyncScreening = true;
    source.screeningStatuses = [
      {'taskId': 1, 'processing': true, 'state': 'processing'},
      {'taskId': 1, 'processing': false, 'state': 'completed'},
    ];
    await pumpDetail(tester, source, initialTab: 1);
    await tester.tap(find.byKey(const Key('job-rescreen')));
    await tester.pump();
    expect(find.text('筛选中…'), findsOneWidget);
    await tester.tap(find.byKey(const Key('job-rescreen')));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(source.screenCalls, 1);
    expect(source.statusCalls, 2);
    expect(source.scoreCalls, 2);
    expect(find.text('AI辅助筛选'), findsOneWidget);
  });

  testWidgets('AI后台失败保留名单并显示错误，不自动重发任务', (tester) async {
    final source = DetailFakeSource()..asyncScreening = true;
    source.screeningStatuses = [
      {
        'taskId': 1,
        'processing': false,
        'state': 'failed',
        'error': '模型暂不可用，原有结果未变更',
      },
    ];
    await pumpDetail(tester, source, initialTab: 1);
    await tester.tap(find.byKey(const Key('job-rescreen')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(source.screenCalls, 1);
    expect(source.statusCalls, 1);
    expect(find.text('候选人甲'), findsOneWidget);
    expect(find.text('模型暂不可用，原有结果未变更'), findsOneWidget);
  });

  testWidgets('JD 与招聘流程折叠状态跨 Tab 保持', (tester) async {
    final source = DetailFakeSource();
    await pumpDetail(tester, source);
    final jd = find.byKey(const PageStorageKey('job-jd-expansion-1'));
    final flow = find.byKey(const PageStorageKey('job-workflow-expansion-1'));
    expect(jd, findsOneWidget);
    final basicScrollable = find
        .descendant(
          of: find.byType(JobBasicInfoTab),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      jd,
      300,
      scrollable: basicScrollable,
      maxScrolls: 20,
    );
    await tester.ensureVisible(jd);
    await tester.pumpAndSettle();
    await tester.tap(jd);
    await tester.pumpAndSettle();
    expect(find.text('重新解析'), findsOneWidget);
    await tester.scrollUntilVisible(
      flow,
      400,
      scrollable: find
          .descendant(
            of: find.byType(JobBasicInfoTab),
            matching: find.byType(Scrollable),
          )
          .first,
      maxScrolls: 20,
    );
    expect(flow, findsOneWidget);
    await tester.tap(find.text('求职者'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('基础信息'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('重新解析'),
      -400,
      scrollable: find
          .descendant(
            of: find.byType(JobBasicInfoTab),
            matching: find.byType(Scrollable),
          )
          .first,
      maxScrolls: 20,
    );
    expect(find.text('重新解析'), findsOneWidget);
  });

  testWidgets('面试入口保持独立，旧 initialTab 2 兼容进入合并后的求职者页', (tester) async {
    final source = DetailFakeSource();
    await pumpDetail(tester, source, initialTab: 2);
    expect(find.byType(JobInterviewsPage), findsNothing);
    expect(find.byType(JobCandidatesTab), findsOneWidget);
    expect(find.text('AI辅助筛选'), findsOneWidget);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    await tester.tap(find.text('基础信息'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('job-interviews-entry')));
    await tester.pumpAndSettle();
    expect(find.byType(JobInterviewsPage), findsOneWidget);
    expect(find.textContaining('面试安排'), findsWidgets);
  });
}
