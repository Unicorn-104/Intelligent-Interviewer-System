import 'package:enterprise_recruiter/features/enterprise/jobs/job_detail_page.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/job_interviews_page.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/widgets/job_candidates_tab.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/job_detail_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('岗位详情两 Tab、求职者 AI 筛选和独立面试入口', (tester) async {
    final source = DetailFakeSource(
      scoreResult: [
        {'resultId': 11, 'totalScore': 92},
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: JobDetailPage(
          job: {'posId': 1, 'title': 'Java工程师'},
          source: source,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('基础信息'), findsOneWidget);
    expect(find.text('面试安排'), findsOneWidget);
    await tester.tap(find.text('求职者'));
    await tester.pumpAndSettle();
    expect(find.byType(JobCandidatesTab), findsOneWidget);
    expect(find.text('候选人甲'), findsOneWidget);
    expect(find.text('AI筛选'), findsNothing);
    expect(find.text('AI辅助筛选'), findsOneWidget);
    expect(source.scoreCalls, 1);
    expect(find.text('通用评分，非岗位维度'), findsNothing);
    expect(find.text('AI 结果仅供参考'), findsNothing);
    expect(find.text('AI辅助筛选'), findsOneWidget);
    expect(source.screenCalls, 0);
    await tester.tap(find.text('基础信息'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('job-interviews-entry')));
    await tester.pumpAndSettle();
    expect(find.byType(JobInterviewsPage), findsOneWidget);
  });

  testWidgets('initialTab 1 和旧索引 2 均进入合并后的求职者页', (tester) async {
    for (final tab in [1, 2]) {
      final source = DetailFakeSource();
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: AppTheme.light,
          home: JobDetailPage(
            job: {'posId': 1, 'title': 'Java工程师'},
            source: source,
            initialTab: tab,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(JobCandidatesTab), findsOneWidget);
      expect(find.text('AI辅助筛选'), findsOneWidget);
      expect(tester.widget<TabBar>(find.byType(TabBar)).tabs, hasLength(2));
    }
  });
}
