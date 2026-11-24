import 'package:enterprise_recruiter/features/enterprise/jobs/widgets/job_exam_invite_page.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('非笔试阶段求职者保留展示但置灰不可选，并支持筛选', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: JobExamInvitePage(
          positionId: 1,
          jobTitle: '产品经理',
          examStageId: 101,
          examStageNames: const {'笔试'},
          candidates: const [
            {
              'talId': 11,
              'name': '候选人甲',
              'currentStage': '笔试',
              'statusLabel': '招聘中',
            },
            {
              'talId': 12,
              'name': '候选人乙',
              'currentStage': 'HR 综合面试',
              'statusLabel': '招聘中',
            },
            {
              'talId': 13,
              'name': '候选人丙',
              'currentStage': null,
              'statusLabel': '已投递',
            },
          ],
          paperLoader: () async => [
            {
              'paperId': 1,
              'name': '产品笔试卷',
              'status': 1,
              'durationMin': 60,
              'totalScore': 100,
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('候选人甲'), findsOneWidget);
    expect(find.text('候选人乙'), findsOneWidget);
    expect(find.text('候选人丙'), findsOneWidget);

    final eligible = tester.widget<Checkbox>(
      find.byKey(const Key('job-exam-checkbox-11')),
    );
    expect(eligible.value, isTrue);
    expect(eligible.onChanged, isNotNull);

    for (final id in [12, 13]) {
      final locked = tester.widget<Checkbox>(
        find.byKey(Key('job-exam-checkbox-$id')),
      );
      expect(locked.value, isFalse);
      expect(locked.onChanged, isNull);
    }

    expect(find.text('已选 1 人'), findsOneWidget);

    await tester.tap(find.byKey(const Key('job-exam-filter-locked')));
    await tester.pumpAndSettle();
    expect(find.text('候选人甲'), findsNothing);
    expect(find.text('候选人乙'), findsOneWidget);
    expect(find.text('候选人丙'), findsOneWidget);

    await tester.tap(find.byKey(const Key('job-exam-filter-all')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('job-exam-search')), '乙');
    await tester.pumpAndSettle();
    expect(find.text('候选人甲'), findsNothing);
    expect(find.text('候选人乙'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('job-exam-search')), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('job-exam-clear')));
    await tester.pumpAndSettle();
    expect(find.text('已选 0 人'), findsOneWidget);

    await tester.tap(find.byKey(const Key('job-exam-select-eligible')));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 人'), findsOneWidget);
    expect(
      tester
          .widget<Checkbox>(find.byKey(const Key('job-exam-checkbox-11')))
          .value,
      isTrue,
    );
  });

  testWidgets('全部求职者都不在笔试阶段时仍展示名单并保持不可选', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: JobExamInvitePage(
          positionId: 1,
          jobTitle: '产品经理',
          examStageId: 101,
          examStageNames: const {'笔试'},
          candidates: const [
            {
              'talId': 21,
              'name': '候选人甲',
              'currentStage': 'HR 综合面试',
              'statusLabel': '招聘中',
            },
            {
              'talId': 22,
              'name': '候选人乙',
              'currentStage': 'HR 综合面试',
              'statusLabel': '招聘中',
            },
          ],
          paperLoader: () async => [
            {
              'paperId': 1,
              'name': '产品笔试卷',
              'status': 1,
              'durationMin': 60,
              'totalScore': 100,
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('候选人甲'), findsOneWidget);
    expect(find.text('候选人乙'), findsOneWidget);
    expect(find.textContaining('当前没有处于笔试阶段的求职者'), findsOneWidget);
    expect(find.text('已选 0 人'), findsOneWidget);

    for (final id in [21, 22]) {
      final locked = tester.widget<Checkbox>(
        find.byKey(Key('job-exam-checkbox-$id')),
      );
      expect(locked.value, isFalse);
      expect(locked.onChanged, isNull);
    }
  });

  test('通过阈值按试卷总分百分比折算', () {
    expect(examPassThresholdScore(100, 70), 70);
    expect(examPassThresholdScore(94, 70), closeTo(65.8, 0.001));
    expect(examPassThresholdScore(30, 100), 30);
    expect(examPassThresholdScore(0, 70), 70);
    expect(examPassThresholdScore(100, 0), 1);
  });

  testWidgets('展示流程配置的通过阈值百分比及折算合格线', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: JobExamInvitePage(
          positionId: 1,
          jobTitle: '前端开发工程师',
          examStageId: 101,
          examStageNames: const {'笔试'},
          examPassPercent: 70,
          candidates: const [
            {
              'talId': 31,
              'name': '候选人甲',
              'currentStage': '笔试',
              'statusLabel': '招聘中',
            },
          ],
          paperLoader: () async => [
            {
              'paperId': 1,
              'name': '前端笔试卷',
              'status': 1,
              'durationMin': 60,
              'totalScore': 94,
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('通过阈值 70%'), findsOneWidget);
    expect(find.textContaining('合格线 ≥ 65.8 分'), findsOneWidget);
  });
}
