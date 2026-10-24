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
  testWidgets('岗位统计位于卡片右上，投递统计点击进入求职者且状态按钮独立', (tester) async {
    var opened = 0, applicants = 0, toggled = 0;
    await card(
      tester,
      {
        'applicantCount': 120,
        'viewCount': 705,
        'favoriteCount': 29,
        'salaryMin': 12500,
        'salaryMax': 20000,
        'education': 3,
        'experience': '5-10年',
      },
      onOpen: () => opened++,
      onApplicants: () => applicants++,
      onToggle: () => toggled++,
    );
    expect(find.text('查看详情'), findsNothing);
    expect(find.text('看过'), findsOneWidget);
    expect(find.text('投递过'), findsOneWidget);
    expect(find.text('感兴趣'), findsOneWidget);
    expect(find.text('705'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('29'), findsOneWidget);
    final stats = tester.getRect(
      find.byKey(const ValueKey('job-statistics-1')),
    );
    final title = tester.getRect(find.text('示例Java岗位'));
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('job-status-1')),
    );
    expect(stats.top, lessThan(title.bottom));
    expect(
      stats.right,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('job-list-card-1'))).right -
            16,
      ),
    );
    expect((button.child as Text).data, '在招');
    expect(button.style!.backgroundColor!.resolve({}), AppColors.success);
    expect(button.style!.foregroundColor!.resolve({}), AppColors.canvas);
    expect(
      tester.getSize(find.byKey(const ValueKey('job-status-1'))).height,
      greaterThanOrEqualTo(46),
    );
    await tester.tap(find.byKey(const ValueKey('job-applicants-1')));
    expect((opened, applicants, toggled), (0, 1, 0));
    await tester.tap(find.byKey(const ValueKey('job-status-1')));
    expect((opened, applicants, toggled), (0, 1, 1));
    await tester.tap(find.text('示例Java岗位'));
    expect((opened, applicants, toggled), (1, 1, 1));
  });

  testWidgets('接口缺少看过和感兴趣统计时显示占位符，不伪造为0', (tester) async {
    await card(tester, {'applicantCount': 2});
    expect(find.byKey(const ValueKey('job-stat-views-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('job-stat-interests-1')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  for (final entry in [
    (0, '停招', AppColors.hairline, AppColors.textSecondary),
    (1, '在招', AppColors.success, AppColors.canvas),
    (2, '暂停', AppColors.hairline, AppColors.textSecondary),
  ]) {
    testWidgets('状态${entry.$1}以${entry.$2}文案和颜色表达', (tester) async {
      await card(tester, {'status': entry.$1});
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('job-status-1')),
      );
      expect((button.child as Text).data, entry.$2);
      expect(button.style!.backgroundColor!.resolve({}), entry.$3);
      expect(button.style!.foregroundColor!.resolve({}), entry.$4);
      expect(find.text('已下线'), findsNothing);
      expect(find.text('下线'), findsNothing);
      expect(find.text('上线'), findsNothing);
    });
  }

  testWidgets('缺失数隐藏角标，未知状态不允许改动', (tester) async {
    await card(tester, {'status': null});
    expect(find.byKey(const ValueKey('job-applicants-1')), findsOneWidget);
    expect(find.text('状态未知'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('job-status-1')))
          .onPressed,
      isNull,
    );
  });

  for (final count in [0, null, -1]) {
    testWidgets('unknown applicant count disables candidate navigation', (
      tester,
    ) async {
      var opened = 0, applicants = 0;
      await card(
        tester,
        {'applicantCount': count},
        onOpen: () => opened++,
        onApplicants: () => applicants++,
      );
      final button = tester.widget<InkWell>(
        find.byKey(const ValueKey('job-applicants-1')),
      );
      expect(button.onTap == null, count == null || count < 0);
      expect(
        find.byKey(const ValueKey('job-applicants-circle-1')),
        findsNothing,
      );
      final cardRect = tester.getRect(
        find.byKey(const ValueKey('job-list-card-1')),
      );
      await tester.tapAt(Offset(cardRect.left + 20, cardRect.top + 35));
      expect((opened, applicants), (1, 0));
    });
  }

  for (final count in [1, 9, 10, 99, 100, 120]) {
    testWidgets('投递统计$count显示真实数字并保留候选人入口', (tester) async {
      var opened = 0;
      await card(tester, {
        'applicantCount': count,
      }, onApplicants: () => opened++);
      expect(find.text('$count'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('job-applicants-circle-1')),
        findsNothing,
      );
      expect(find.byTooltip('投递过 $count 人'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('job-applicants-1')));
      expect(opened, 1);
    });
  }

  testWidgets('处理中禁用状态按钮', (tester) async {
    await card(tester, {}, changing: true);
    expect(find.text('处理中…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('job-status-1')))
          .onPressed,
      isNull,
    );
  });

  for (final size in [const Size(320, 640), const Size(900, 420)]) {
    testWidgets('卡片在 $size 下长标题省略、标签不溢出', (tester) async {
      const title = '这是一个很长很长很长的Java开发工程师岗位名称';
      await card(tester, {
        'title': title,
        'applicantCount': 120,
        'education': 3,
        'experience': '3-5年',
        'salaryMin': 8500,
        'salaryMax': 12000,
        'jdJson': '{"skills":["Spring","Dart","Python"]}',
      }, size: size);
      expect(tester.widget<Text>(find.text(title).first).maxLines, 1);
      expect(find.text('Spring'), findsOneWidget);
      expect(find.text('Dart'), findsOneWidget);
      expect(find.text('Python'), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('job-status-1'))).height,
        greaterThanOrEqualTo(46),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
