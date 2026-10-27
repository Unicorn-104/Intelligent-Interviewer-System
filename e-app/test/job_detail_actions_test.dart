import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/job_detail_page.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';

import 'support/job_detail_fixture.dart';

/// 岗位详情动作区：预览打开求职者视角页面，删除经确认后调用接口并返回列表。
Future<void> pumpDetail(WidgetTester tester, DetailFakeSource source) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => TextButton(
              key: const Key('open-detail'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => JobDetailPage(
                    job: {'posId': 1, 'title': 'Java工程师'},
                    source: source,
                  ),
                ),
              ),
              child: const Text('打开岗位'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-detail')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('预览按钮打开求职者视角预览页，不触发真实投递', (tester) async {
    final source = DetailFakeSource();
    await pumpDetail(tester, source);
    await tester.tap(find.byKey(const Key('job-preview-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('job-preview-banner')), findsOneWidget);
    expect(find.text('求职者视角预览 · 与求职者端岗位详情同源数据'), findsOneWidget);
    expect(find.byKey(const Key('job-preview-title')), findsOneWidget);
    expect(find.text('18K-28K·月薪'), findsOneWidget);
    expect(find.text('杭州 · 3-5年 · 本科'), findsOneWidget);
    expect(find.text('开发接口\n维护服务'), findsOneWidget);
    expect(find.text('• 熟悉Java'), findsOneWidget);
    expect(find.byKey(const Key('job-preview-company-card')), findsOneWidget);
    expect(find.text('测试企业'), findsOneWidget);
    final apply = tester.widget<FilledButton>(
      find.byKey(const Key('job-preview-apply')),
    );
    expect(apply.onPressed, isNull);
    expect(find.textContaining('预览，求职者端可操作'), findsOneWidget);
    expect(source.previewCalls, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('job-preview-banner')), findsNothing);
  });

  testWidgets('删除岗位经确认后调用接口并返回列表，取消不删除', (tester) async {
    final source = DetailFakeSource();
    await pumpDetail(tester, source);
    await tester.tap(find.byKey(const Key('job-delete-entry')));
    await tester.pumpAndSettle();
    expect(find.textContaining('删除后不可恢复'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(source.deletedJobs, isEmpty);
    expect(find.byType(JobDetailPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('job-delete-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('job-delete-confirm')));
    await tester.pumpAndSettle();
    expect(source.deletedJobs, [1]);
    expect(find.byType(JobDetailPage), findsNothing);
    expect(find.byKey(const Key('open-detail')), findsOneWidget);
  });

  testWidgets('删除被后端拒绝时留在详情页并提示原因', (tester) async {
    final source = DetailFakeSource()..deleteFailure = true;
    await pumpDetail(tester, source);
    await tester.tap(find.byKey(const Key('job-delete-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('job-delete-confirm')));
    await tester.pumpAndSettle();
    expect(find.byType(JobDetailPage), findsOneWidget);
    expect(find.textContaining('无法删除'), findsOneWidget);
    expect(source.deletedJobs, isEmpty);
  });

  testWidgets('基础信息资料卡高亮发布日期与投递人数', (tester) async {
    final source = DetailFakeSource();
    await pumpDetail(tester, source);
    expect(find.byKey(const Key('job-basic-published')), findsOneWidget);
    expect(find.text('发布日期：2026-10-16'), findsOneWidget);
    expect(find.byKey(const Key('job-basic-applicants')), findsOneWidget);
    expect(find.text('投递人数：2'), findsOneWidget);
  });
}
