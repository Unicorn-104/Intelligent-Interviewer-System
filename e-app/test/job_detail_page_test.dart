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
    // 未打开面试安排页，页面内仅按钮标签一处「面试安排」。
    expect(find.text('面试安排'), findsOneWidget);
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

  testWidgets('取消编辑不保存，招聘流程折叠模块已移除', (tester) async {
    final source = DetailFakeSource();
    await pumpDetail(tester, source);
    final edit = find.byKey(const Key('job-workflow-node-0'));
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(source.savedWorkflows, isEmpty);
    expect(find.byKey(const PageStorageKey('job-workflow-expansion-1')), findsNothing);
    expect(find.text('招聘流程'), findsNothing);
    expect(find.byKey(const Key('job-workflow-node-0')), findsOneWidget);
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
        {'resultId': 11, 'totalScore': 88},
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
    expect(find.text('增量分析'), findsOneWidget);
    expect(find.byKey(const Key('job-rescreen')), findsOneWidget);
    expect(source.screenCalls, 0);
    expect(source.scoreCalls, 1);
    expect(find.text('88.0'), findsOneWidget);
    expect(find.byKey(const Key('job-refresh-analysis')), findsNothing);
  });

  testWidgets('AI 评分失败保留同批候选人并显示重试，不清空名单', (tester) async {
    final source = DetailFakeSource(scoreFailure: true);
    await pumpDetail(tester, source, initialTab: 1);
    expect(find.text('候选人甲'), findsOneWidget);
    expect(find.text('候选人乙'), findsOneWidget);
    expect(find.text('加载筛选结果失败，重试'), findsOneWidget);
    expect(find.text('通用评分，非岗位维度'), findsNothing);
    expect(find.text('AI 结果仅供参考'), findsNothing);
    expect(find.text('增量分析'), findsOneWidget);
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

  testWidgets('增量分析先读取已有结果，完整时不调用模型且下拉菜单在按钮内', (tester) async {
    final source = DetailFakeSource(
      scoreResult: [
        {'resultId': 11, 'source': 'llm', 'totalScore': 88},
        {'resultId': 12, 'source': 'llm', 'totalScore': 79},
      ],
    );
    await pumpDetail(tester, source, initialTab: 1);
    expect(source.scoreCalls, 1);
    expect(source.screenCalls, 0);
    expect(find.byKey(const Key('job-refresh-analysis')), findsNothing);
    expect(find.text('刷新结果'), findsNothing);
    expect(find.text('88.0'), findsOneWidget);

    final button = find.byKey(const Key('job-rescreen'));
    final menu = find.byKey(const Key('job-analysis-menu'));
    expect(
      tester.getTopLeft(menu).dx,
      greaterThan(tester.getTopLeft(button).dx),
    );
    expect(
      tester.getTopRight(menu).dx,
      lessThan(tester.getTopRight(button).dx + 64),
    );

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(source.scoreCalls, 2);
    expect(source.scoreCallsAtStart, 0);
    expect(source.screenCalls, 0);
    expect(find.text('已读取已有分析结果，没有待补充的求职者'), findsOneWidget);
  });

  testWidgets('增量分析优先刷新数据库，存在未分析求职者时才启动任务', (tester) async {
    final source = DetailFakeSource();
    await pumpDetail(tester, source, initialTab: 1);
    expect(source.scoreCalls, 1);
    await tester.tap(find.byKey(const Key('job-rescreen')));
    await tester.pumpAndSettle();
    expect(source.scoreCalls, 3);
    expect(source.scoreCallsAtStart, 2);
    expect(source.screenCalls, 1);
  });

  testWidgets('已有结果加载失败时增量按钮不擅自触发模型', (tester) async {
    final source = DetailFakeSource(scoreFailure: true);
    await pumpDetail(tester, source, initialTab: 1);
    await tester.tap(find.byKey(const Key('job-rescreen')));
    await tester.pumpAndSettle();
    expect(source.scoreCalls, 2);
    expect(source.screenCalls, 0);
    expect(source.fullScreenCalls, 0);
  });

  testWidgets('全量分析需二次确认并调用独立全量入口', (tester) async {
    final source = DetailFakeSource();
    await pumpDetail(tester, source, initialTab: 1);
    await tester.tap(find.byKey(const Key('job-analysis-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全量分析（耗时较长）'));
    await tester.pumpAndSettle();
    expect(find.textContaining('会耗费大量时间和模型调用额度'), findsOneWidget);
    expect(source.fullScreenCalls, 0);
    await tester.tap(find.byKey(const Key('job-full-analysis-confirm')));
    await tester.pumpAndSettle();
    expect(source.fullScreenCalls, 1);
    expect(source.screenCalls, 0);
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
    expect(find.text('分析中…'), findsOneWidget);
    await tester.tap(find.byKey(const Key('job-rescreen')));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(source.screenCalls, 1);
    expect(source.statusCalls, 2);
    expect(source.scoreCalls, 3);
    expect(find.text('增量分析'), findsOneWidget);
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

  testWidgets('JD画像与招聘流程模块已彻底移除，页面以技能模块结束', (tester) async {
    final source = DetailFakeSource();
    await pumpDetail(tester, source);
    final basicScrollable = find
        .descendant(
          of: find.byType(JobBasicInfoTab),
          matching: find.byType(Scrollable),
        )
        .first;
    expect(find.byKey(const PageStorageKey('job-jd-expansion-1')), findsNothing);
    expect(find.byKey(const PageStorageKey('job-workflow-expansion-1')), findsNothing);
    expect(find.text('JD画像'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('技能'),
      400,
      scrollable: basicScrollable,
      maxScrolls: 20,
    );
    expect(find.text('技能'), findsOneWidget);
    expect(find.text('JD画像'), findsNothing);
    expect(find.text('招聘流程'), findsNothing);
    expect(find.text('Java · 必备'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('job-basic-published')),
      -400,
      scrollable: basicScrollable,
      maxScrolls: 20,
    );
  });

  testWidgets('面试入口保持独立，旧 initialTab 2 兼容进入合并后的求职者页', (tester) async {
    final source = DetailFakeSource();
    await pumpDetail(tester, source, initialTab: 2);
    expect(find.byType(JobInterviewsPage), findsNothing);
    expect(find.byType(JobCandidatesTab), findsOneWidget);
    expect(find.text('增量分析'), findsOneWidget);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    await tester.tap(find.text('基础信息'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('job-interviews-entry')));
    await tester.pumpAndSettle();
    expect(find.byType(JobInterviewsPage), findsOneWidget);
    expect(find.textContaining('面试安排'), findsWidgets);
  });
}
