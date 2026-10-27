import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/profile/company_info_page.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';

Map<String, dynamic> companyJson() => {
  'id': 2,
  'name': '测试企业',
  'industry': '互联网',
  'size': '100-499人',
  'city': '杭州',
  'address': '西湖区',
  'website': 'https://example.com',
  'intro': '专注招聘的企业',
  'logoUrl': '',
  'verifyStatus': 1,
  'status': 1,
};

Future<void> pumpPage(
  WidgetTester tester, {
  Future<Map<String, dynamic>> Function()? load,
  Future<Map<String, dynamic>> Function(Map<String, Object?> body)? save,
}) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: CompanyInfoPage(
        load: load ?? () async => companyJson(),
        save: save,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('查看模式展示企业对外资料与认证状态', (tester) async {
    await pumpPage(tester);
    expect(find.text('企业信息'), findsOneWidget);
    expect(find.byKey(const Key('company-info-name')), findsOneWidget);
    expect(find.text('测试企业'), findsOneWidget);
    expect(find.text('已认证'), findsOneWidget);
    expect(find.text('求职者可见'), findsOneWidget);
    expect(find.text('互联网'), findsOneWidget);
    expect(find.text('100-499人'), findsOneWidget);
    expect(find.text('杭州'), findsOneWidget);
    expect(find.text('西湖区'), findsOneWidget);
    expect(find.text('专注招聘的企业'), findsOneWidget);
  });

  testWidgets('编辑保存提交修剪后的字段并刷新为最新值', (tester) async {
    Map<String, Object?>? saved;
    var info = companyJson();
    await pumpPage(
      tester,
      load: () async => info,
      save: (body) async {
        saved = body;
        info = {
          ...companyJson(),
          'name': body['name'],
          'industry': body['industry'],
          'city': body['city'],
        };
        return info;
      },
    );
    await tester.tap(find.byKey(const Key('company-info-edit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('company-info-field-name')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('company-info-field-name')),
      ' 测试企业科技 ',
    );
    await tester.enterText(
      find.byKey(const Key('company-info-field-industry')),
      '人工智能',
    );
    await tester.enterText(
      find.byKey(const Key('company-info-field-city')),
      ' 上海 ',
    );
    await tester.tap(find.byKey(const Key('company-info-save')));
    await tester.pumpAndSettle();
    expect(saved?['name'], '测试企业科技');
    expect(saved?['industry'], '人工智能');
    expect(saved?['city'], '上海');
    expect(saved?['size'], '100-499人');
    expect(find.text('企业信息已更新'), findsOneWidget);
    expect(find.text('测试企业科技'), findsOneWidget);
    expect(find.text('人工智能'), findsOneWidget);
    expect(find.byKey(const Key('company-info-field-name')), findsNothing);
  });

  testWidgets('名称为空时阻止保存并提示', (tester) async {
    var saved = false;
    await pumpPage(
      tester,
      save: (_) async {
        saved = true;
        return companyJson();
      },
    );
    await tester.tap(find.byKey(const Key('company-info-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('company-info-field-name')),
      '   ',
    );
    await tester.tap(find.byKey(const Key('company-info-save')));
    await tester.pumpAndSettle();
    expect(saved, isFalse);
    expect(find.text('企业名称不能为空'), findsOneWidget);
  });

  testWidgets('取消编辑不保存，保存失败保留编辑态并提示', (tester) async {
    await pumpPage(
      tester,
      save: (_) async => throw const ApiException('企业名称已被使用'),
    );
    await tester.tap(find.byKey(const Key('company-info-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('company-info-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('company-info-field-name')), findsNothing);

    await tester.tap(find.byKey(const Key('company-info-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('company-info-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('company-info-field-name')), findsOneWidget);
    expect(find.text('企业名称已被使用'), findsOneWidget);
  });
}
