import 'package:enterprise_recruiter/features/enterprise/jobs/widgets/job_list_card.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> card(
  WidgetTester tester,
  Map<String, dynamic> raw, {
  VoidCallback? onOpen,
  VoidCallback? onApplicants,
  VoidCallback? onToggle,
  bool changing = false,
  Size size = const Size(420, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: JobListCard(
            job: {
              'posId': 1,
              'title': '示例Java岗位',
              'dept': '研发',
              'city': '杭州',
              'status': 1,
              ...raw,
            },
            onOpen: onOpen ?? () {},
            onApplicants: onApplicants ?? () {},
            onToggle: onToggle ?? () {},
            changing: changing,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('卡片、徽标、状态按钮点击彼此独立，没有查看详情文字按钮', (tester) async {
    var opened = 0;
    var applicants = 0;
    var toggled = 0;
    await card(
      tester,
      {'applicantCount': 120, 'salaryMin': 12500, 'salaryMax': 20000},
      onOpen: () => opened++,
      onApplicants: () => applicants++,
      onToggle: () => toggled++,
    );
    expect(find.text('查看详情'), findsNothing);
    expect(find.text('12.5-20K·月薪'), findsOneWidget);
    expect(find.text('99+'), findsOneWidget);
    final badge = find.byKey(const ValueKey('job-applicants-1'));
    final semantic = tester.widget<Semantics>(
      find.ancestor(of: badge, matching: find.byType(Semantics)).first,
    );
    expect(semantic.properties.label, '累计投递 120 人，查看求职者');
    await tester.tap(badge);
    expect((opened, applicants, toggled), (0, 1, 0));
    await tester.tap(find.byKey(const ValueKey('job-status-1')));
    expect((opened, applicants, toggled), (0, 1, 1));
    await tester.tap(find.text('示例Java岗位'));
    expect((opened, applicants, toggled), (1, 1, 1));
  });

  for (final entry in [(0, '已下线', '上线'), (1, '在招', '下线'), (2, '暂停', '上线')]) {
    testWidgets('状态 ${entry.$1} 对应 ${entry.$2} 和 ${entry.$3}', (tester) async {
      await card(tester, {'status': entry.$1, 'applicantCount': 0});
      expect(find.text(entry.$2), findsOneWidget);
      expect(find.text(entry.$3), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      final badgeY = tester
          .getCenter(find.byKey(const ValueKey('job-applicants-1')))
          .dy;
      final statusY = tester.getCenter(find.text(entry.$2)).dy;
      expect(statusY, greaterThan(badgeY));
    });
  }

  testWidgets('缺失数显示破折号，未知状态不允许改动', (tester) async {
    await card(tester, {'status': null});
    expect(find.text('—'), findsOneWidget);
    expect(find.text('状态未知'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('job-status-1')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('处理中禁用状态按钮', (tester) async {
    await card(tester, {}, changing: true);
    expect(find.text('处理中…'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
  });

  for (final size in [const Size(320, 640), const Size(900, 420)]) {
    testWidgets('卡片在 $size 下长标题省略、标签不溢出', (tester) async {
      const title = '这是一个很长很长很长的Java开发工程师岗位名称';
      await card(tester, {
        'title': title,
        'education': 3,
        'experience': '3-5年',
        'salaryMin': 8500,
        'salaryMax': 12000,
        'jdJson': '{"skills":["Spring","Dart","Python"]}',
      }, size: size);
      expect(tester.widget<Text>(find.text(title)).maxLines, 1);
      expect(find.text('Spring'), findsOneWidget);
      expect(find.text('Dart'), findsOneWidget);
      expect(find.text('Python'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
