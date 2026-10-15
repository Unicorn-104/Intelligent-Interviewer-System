import 'dart:convert';
import 'package:enterprise_recruiter/features/enterprise/dashboard/home_models.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/widgets/home_applications_section.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/widgets/home_section.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> showCard(
  WidgetTester tester,
  Map<String, dynamic> fields, {
  String? companyName = '示例企业',
  VoidCallback? onOpen,
  Size size = const Size(420, 900),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: HomeApplicationRow(
              application: HomeApplication({
                'posId': 1,
                'title': '示例Java岗位',
                'dept': '研发支持部',
                ...fields,
              }),
              companyName: companyName,
              onOpen: onOpen ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final scenario in <(Map<String, dynamic>, String)>[
    ({'salaryMin': 12500, 'salaryMax': 20000}, '12.5-20K·月薪'),
    ({'salaryMin': 8500, 'salaryMax': 12000}, '8.5-12K·月薪'),
    ({'salaryMin': 12000}, '12K起·月薪'),
    ({}, '面议'),
    ({'salaryMax': 20000}, '20K以内·月薪'),
    ({'salaryMin': '12500', 'salaryMax': '20000'}, '12.5-20K·月薪'),
  ]) {
    testWidgets('薪资保留一位去尾零 ${scenario.$2}', (tester) async {
      await showCard(tester, scenario.$1);
      expect(find.text(scenario.$2), findsOneWidget);
      final text = tester.widget<Text>(find.text(scenario.$2));
      expect(text.style!.color, AppColors.accentOrange);
      expect(text.style!.fontWeight, FontWeight.w600);
    });
  }

  testWidgets('企业名来自参数，学历经验和前两个真实技能展示并去重', (tester) async {
    await showCard(tester, {
      'education': 3,
      'experience': '3-5年',
      'jdJson': jsonEncode({
        'skills': [' Spring ', '', 'Spring', 'Dart', 'Python', null],
      }),
    });
    expect(find.text('示例企业 · 研发支持部'), findsOneWidget);
    for (final label in ['本科', '3-5年', 'Spring', 'Dart']) {
      expect(find.text(label), findsOneWidget);
      final text = tester.widget<Text>(find.text(label));
      expect(text.style!.color, AppColors.interactive);
      final container = tester.widget<Container>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.interactiveSoft);
      expect(decoration.borderRadius, BorderRadius.circular(4));
    }
    expect(find.text('Python'), findsNothing);
  });

  testWidgets('缺失企业名及无效 JD 不编造公司或技能', (tester) async {
    await showCard(tester, {
      'jdJson': '{broken',
      'education': 99,
    }, companyName: null);
    expect(find.text('研发支持部'), findsOneWidget);
    expect(find.byType(Wrap), findsNothing);
    expect(find.text('Spring'), findsNothing);
    expect(find.text('Dart'), findsNothing);
  });

  for (final scenario in <(Object?, String)>[
    (0, '累计投递 0 人'),
    (3, '累计投递 3 人'),
    (null, '累计投递 — 人'),
  ]) {
    testWidgets('投递数真实展示 ${scenario.$2}', (tester) async {
      var opened = 0;
      await showCard(tester, {
        'applicantCount': scenario.$1,
      }, onOpen: () => opened++);
      expect(find.text(scenario.$2, findRichText: true), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-job-1')));
      expect(opened, 1);
    });
  }

  for (final size in [const Size(320, 640), const Size(900, 420)]) {
    testWidgets('长标题和长标签在 $size 及大字体下不溢出', (tester) async {
      await showCard(
        tester,
        {
          'title': '这是需要单行省略的非常长的岗位名称Java开发工程师',
          'salaryMin': 12500,
          'salaryMax': 20000,
          'education': 3,
          'experience': '3-5年',
          'applicantCount': 3,
          'jdJson': {
            'skills': ['LongSkillNameWithManyCharacters', 'Dart'],
          },
        },
        size: size,
        scale: 1.5,
      );
      final title = tester.widget<Text>(
        find.text('这是需要单行省略的非常长的岗位名称Java开发工程师'),
      );
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('查看详情'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('HomeSection 默认包装保持兼容，关闭后只保留内容', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Column(
            children: [
              HomeSection(title: '近期面试', child: Text('面试内容')),
              HomeSection(
                title: '岗位投递概览',
                wrapInCard: false,
                child: Text('岗位内容'),
              ),
              HomeSection(title: '快捷统计', child: Text('统计内容')),
            ],
          ),
        ),
      ),
    );
    for (final title in ['近期面试', '快捷统计']) {
      expect(
        find.descendant(
          of: find.widgetWithText(HomeSection, title),
          matching: find.byType(Card),
        ),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: find.widgetWithText(HomeSection, '岗位投递概览'),
        matching: find.byType(Card),
      ),
      findsNothing,
    );
  });
}
