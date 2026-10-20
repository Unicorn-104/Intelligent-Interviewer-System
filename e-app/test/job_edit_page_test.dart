import 'dart:async';

import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/job_detail_page.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/job_publish_page.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/data/job_detail_data_source.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/job_detail_fixture.dart';

class EditingSource extends JobDetailDataSource {
  String title = 'Java工程师';
  int detailLoads = 0, profileLoads = 0, workflowSaves = 0;
  bool fail = false, loadFail = false;
  Completer<void>? gate;
  final writes = <Map<String, Object?>>[];

  @override
  Future<Map<String, dynamic>> loadDetail(int id) async {
    detailLoads++;
    final data = jobDetailJson();
    (data['job'] as Map)['title'] = title;
    (data['job'] as Map)['experience'] = '8年以上（原值）';
    return data;
  }

  @override
  Future<Map<String, dynamic>> loadProfile(int id) async {
    profileLoads++;
    return profileJson();
  }

  @override
  Future<Map<String, dynamic>> loadWorkflow(int id) async => {'stages': []};
  @override
  Future<Map<String, dynamic>> loadEditingOptions(int id) async {
    if (loadFail) throw const ApiException('读取岗位失败');
    final detail = await loadDetail(id);
    return {
      'company': {'id': 2, 'name': '合成企业', 'city': '上海'},
      'departments': ['研发部'],
      'job': detail['job'],
      'skills': [
        {'name': 'Java', 'required': 1},
        {'name': 'Git', 'required': null},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> updateJob(
    int id,
    Map<String, Object?> body,
  ) async {
    writes.add(body);
    await gate?.future;
    if (fail) throw const ApiException('保存失败，请重试');
    title = body['title'] as String;
    return {'posId': id, 'title': title, 'status': 2};
  }

  @override
  Future<void> saveWorkflow(int id, Map<String, Object?> body) async {
    workflowSaves++;
  }
}

Future<void> mount(
  WidgetTester tester,
  EditingSource source, {
  Size size = const Size(430, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: JobDetailPage(job: const {'posId': 1}, source: source),
    ),
  );
  await tester.pumpAndSettle();
  final entry = find.byKey(const Key('job-edit-entry'));
  await tester.ensureVisible(entry);
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

Future<void> changeTitle(WidgetTester tester, String title) async {
  final field = find.byKey(const Key('job-title'));
  await tester.ensureVisible(field);
  await tester.enterText(field, title);
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('编辑回填真实字段及技能，确认前不写入，保存后刷新详情', (tester) async {
    final source = EditingSource();
    await mount(tester, source);
    expect(find.text('编辑岗位'), findsOneWidget);
    expect(find.byKey(const Key('job-publish-add-stage')), findsNothing);
    final title = find.byKey(const Key('job-title'));
    await tester.ensureVisible(title);
    expect(tester.widget<TextFormField>(title).controller!.text, 'Java工程师');
    await changeTitle(tester, '修改后的Java工程师');
    expect(source.writes, isEmpty);
    await tester.tap(find.byKey(const Key('job-publish-action')));
    await tester.pumpAndSettle();
    expect(find.text('预览修改'), findsWidgets);
    expect(source.writes, isEmpty);
    await tester.tap(find.byKey(const Key('job-publish-action')));
    await tester.pumpAndSettle();
    expect(source.writes, hasLength(1));
    final body = source.writes.single;
    expect(body['title'], '修改后的Java工程师');
    expect(body['city'], '杭州');
    expect(body['experience'], '8年以上（原值）');
    expect(body['salaryMin'], '18000');
    expect(body['status'], isNull);
    expect(body['companyId'], isNull);
    expect(body['skills'], [
      {'name': 'Java', 'required': 1},
      {'name': 'Git', 'required': null},
    ]);
    expect(source.workflowSaves, 0);
    expect(source.detailLoads, 3);
    expect(source.profileLoads, 2);
    expect(find.byType(JobPublishPage), findsNothing);
    expect(find.text('修改后的Java工程师'), findsWidgets);
  });

  testWidgets('保存中防重复和返回，失败保留修改并能重试', (tester) async {
    final source = EditingSource()..fail = true;
    await mount(tester, source);
    await changeTitle(tester, '失败后保留的标题');
    await tester.tap(find.byKey(const Key('job-publish-action')));
    await tester.pumpAndSettle();
    source.gate = Completer<void>();
    await tester.tap(find.byKey(const Key('job-publish-action')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('job-publish-action')));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(source.writes, hasLength(1));
    expect(find.byType(JobPublishPage), findsOneWidget);
    source.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(find.text('保存修改'), findsOneWidget);
    source.fail = false;
    await tester.tap(find.byKey(const Key('job-publish-action')));
    await tester.pumpAndSettle();
    expect(source.writes, hasLength(2));
    expect(find.byType(JobPublishPage), findsNothing);
  });

  testWidgets('放弃修改不写入，编辑数据加载失败可重试', (tester) async {
    final source = EditingSource()..loadFail = true;
    await mount(tester, source);
    expect(find.text('读取岗位失败'), findsOneWidget);
    expect(find.byKey(const Key('job-publish-action')), findsNothing);
    source.loadFail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    await changeTitle(tester, '不保存的标题');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('放弃岗位修改？'), findsOneWidget);
    await tester.tap(find.text('离开'));
    await tester.pumpAndSettle();
    expect(source.writes, isEmpty);
    expect(source.title, 'Java工程师');
  });

  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('岗位编辑在 $size 及键盘下无溢出', (tester) async {
      await mount(tester, EditingSource(), size: size);
      await changeTitle(tester, '较长岗位名称的编辑验证');
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('job-publish-action')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
