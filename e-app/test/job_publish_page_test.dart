import 'dart:async';

import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/job_publish_page.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Map<String, dynamic>> options() async => {
  'company': {'id': 2, 'name': '测试企业', 'city': '上海'},
  'departments': ['产品研发部'],
};

Future<void> openPage(
  WidgetTester tester, {
  Future<Map<String, dynamic>> Function(Map<String, Object?>)? submit,
  Future<Map<String, dynamic>> Function()? load,
}) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: JobPublishPage(loadOptions: load ?? options, submitJob: submit),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String value) async {
  final field = find.byKey(Key(key));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, value);
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester) async {
  await enter(tester, 'job-title', 'Flutter 开发工程师');
  await enter(tester, 'job-department', '产品研发部');
  await enter(tester, 'job-salary-min', '15000.50');
  await enter(tester, 'job-salary-max', '25000');
  await enter(tester, 'job-responsibilities', '负责移动端开发\n参与代码评审');
  await enter(tester, 'job-requirements', '熟悉 Flutter\n具备良好的协作能力');
}

void main() {
  testWidgets('必填校验阻止空岗位进入预览', (tester) async {
    await openPage(tester);
    await tester.tap(find.byKey(const Key('job-publish-action')));
    await tester.pumpAndSettle();
    expect(find.text('请填写岗位名称'), findsOneWidget);
    expect(find.text('确认发布'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('预览保留真实输入并阻止重复提交', (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    var calls = 0;
    Map<String, Object?>? body;
    await openPage(
      tester,
      submit: (payload) {
        calls++;
        body = payload;
        return pending.future;
      },
    );
    await fill(tester);
    await tester.tap(find.byKey(const Key('job-publish-action')));
    await tester.pumpAndSettle();
    expect(find.text('确认发布'), findsOneWidget);
    expect(find.text('Flutter 开发工程师'), findsOneWidget);
    await tester.tap(find.text('返回修改'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('job-title')), findsOneWidget);
    expect(
      (tester.widget<TextFormField>(
        find.byKey(const Key('job-title')),
      )).controller!.text,
      'Flutter 开发工程师',
    );
    await tester.tap(find.byKey(const Key('job-publish-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('job-publish-action')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('job-publish-action')));
    await tester.pump();
    expect(calls, 1);
    expect(body!['city'], '上海');
    expect(body!['salaryMin'], '15000.50');
    expect(body!['responsibilities'], ['负责移动端开发', '参与代码评审']);
    expect(body!['companyId'], isNull);
    pending.completeError(const ApiException('发布失败，请稍后重试'));
    await tester.pumpAndSettle();
    expect(find.text('确认发布'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('反向薪资范围不允许预览', (tester) async {
    await openPage(tester);
    await fill(tester);
    await enter(tester, 'job-salary-max', '10000');
    await tester.tap(find.byKey(const Key('job-publish-action')));
    await tester.pumpAndSettle();
    expect(find.text('最高月薪不得低于最低月薪'), findsOneWidget);
    expect(find.text('确认发布'), findsNothing);
  });

  testWidgets('面议不提交隐藏薪资', (tester) async {
    Map<String, Object?>? body;
    await openPage(
      tester,
      submit: (payload) async {
        body = payload;
        throw const ApiException('测试返回');
      },
    );
    await fill(tester);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('job-publish-action')));
    await tester.pumpAndSettle();
    expect(find.text('薪资面议'), findsOneWidget);
    await tester.tap(find.byKey(const Key('job-publish-action')));
    await tester.pumpAndSettle();
    expect(body!['salaryMin'], isNull);
    expect(body!['salaryMax'], isNull);
  });

  testWidgets('企业准入失败显示服务端提示与重试入口', (tester) async {
    await openPage(
      tester,
      load: () async {
        throw const ApiException('请先完成企业绑定并通过审核，再发布岗位', code: 403);
      },
    );
    expect(find.text('暂时无法发布岗位'), findsOneWidget);
    expect(find.text('请先完成企业绑定并通过审核，再发布岗位'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.byKey(const Key('job-publish-action')), findsNothing);
  });

  testWidgets('返回键提示未发布内容', (tester) async {
    await openPage(tester);
    await enter(tester, 'job-title', '未发布岗位');
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('离开岗位发布？'), findsOneWidget);
    await tester.tap(find.text('继续填写'));
    await tester.pumpAndSettle();
    expect(
      (tester.widget<TextFormField>(
        find.byKey(const Key('job-title')),
      )).controller!.text,
      '未发布岗位',
    );
  });

  testWidgets('成功响应缺少编号时阻止再次发布', (tester) async {
    var calls = 0;
    await openPage(
      tester,
      submit: (_) async {
        calls++;
        return {};
      },
    );
    await fill(tester);
    await tester.tap(find.byKey(const Key('job-publish-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('job-publish-action')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('返回岗位列表'), findsOneWidget);
    expect(find.text('确认发布'), findsNothing);
    expect(find.text('返回修改'), findsNothing);
  });

  testWidgets('窄屏横屏与键盘弹出不溢出', (tester) async {
    await openPage(tester);
    for (final size in [const Size(320, 700), const Size(900, 400)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('job-requirements')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('job-requirements')));
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height < 500 ? 120 : 300,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.testTextInput.hide();
      tester.view.resetViewInsets();
    }
  });
}
