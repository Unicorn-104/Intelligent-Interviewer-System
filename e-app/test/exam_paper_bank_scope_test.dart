import 'package:enterprise_recruiter/features/enterprise/exam/exam_paper_create_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> _questions() => [
  {
    'questionId': 101,
    'companyId': null,
    'content': '平台单选题',
    'type': 1,
    'score': 5,
  },
  {
    'questionId': 201,
    'companyId': 1,
    'content': '企业单选题',
    'type': 1,
    'score': 5,
  },
];

void main() {
  testWidgets('only checked question banks enter the random draw scope', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, Object?>? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: ExamPaperCreatePage(
          jobs: const [
            {'posId': 1, 'title': 'AI应用开发'},
          ],
          loadQuestions: () async => _questions(),
          submitPaper:
              ({
                required String name,
                required int positionId,
                required int durationMin,
                required String mode,
                List<Map<String, dynamic>>? rule,
                List<String>? bankScopes,
                List<Map<String, dynamic>>? questions,
              }) async {
                submitted = {'name': name, 'mode': mode, 'scopes': bankScopes};
                return 1;
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('仅从已勾选的题库中随机抽取题目，至少保留一个题库'), findsOneWidget);
    expect(_checkbox(tester, 'platform').value, isTrue);
    expect(_checkbox(tester, 'enterprise').value, isTrue);
    expect(find.text('1题'), findsNWidgets(2));

    await tester.ensureVisible(
      find.byKey(const Key('exam-paper-bank-enterprise')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exam-paper-bank-enterprise')));
    await tester.pump();
    expect(_checkbox(tester, 'platform').value, isTrue);
    expect(_checkbox(tester, 'enterprise').value, isFalse);

    await tester.ensureVisible(
      find.byKey(const Key('exam-paper-bank-platform')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exam-paper-bank-platform')));
    await tester.pump();
    expect(_checkbox(tester, 'platform').value, isTrue);
    expect(find.text('至少选择一个题库'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    await tester.ensureVisible(
      find.byKey(const Key('exam-paper-bank-enterprise')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exam-paper-bank-enterprise')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('exam-paper-bank-platform')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exam-paper-bank-platform')));
    await tester.pump();
    expect(_checkbox(tester, 'platform').value, isFalse);
    expect(_checkbox(tester, 'enterprise').value, isTrue);

    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('exam-paper-name')), '企业题库专属卷');
    await tester.tap(find.byKey(const Key('exam-paper-save')));
    await tester.pumpAndSettle();

    expect(submitted?['mode'], 'random');
    expect(submitted?['scopes'], ['enterprise']);
  });
}

CheckboxListTile _checkbox(WidgetTester tester, String scope) {
  return tester.widget<CheckboxListTile>(
    find.byKey(Key('exam-paper-bank-$scope')),
  );
}
