import 'package:enterprise_recruiter/features/enterprise/talent/talent_detail_page.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_greeting_sheet.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_interview_invite_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/talent_detail_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('受控候选人详情：实际字段边界、模板预览和空面试官保护', (tester) async {
    final source = TalentFakeSource()..people = [];
    await tester.pumpWidget(
      MaterialApp(
        home: TalentDetailPage(
          talent: const {'talentId': 11, 'name': '合成候选人'},
          source: source,
          jobContext: talentTestJob,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('当前招聘阶段：技术面试'), findsOneWidget);
    await scrollTalentTo(tester, find.text('通用评分，非岗位维度'));
    expect(find.text('项目：暂无分析'), findsOneWidget);
    expect(find.text('技能重合度：75%'), findsOneWidget);
    await scrollTalentTo(tester, find.byKey(const Key('talent-greeting')));
    await tester.tap(find.byKey(const Key('talent-greeting')));
    await tester.pumpAndSettle();
    expect(find.byType(TalentGreetingSheet), findsOneWidget);
    expect(find.text('模板草稿，非实时 AI 生成'), findsOneWidget);
    await tester.tap(find.text('关闭预览'));
    await tester.pumpAndSettle();
    await scrollTalentTo(
      tester,
      find.byKey(const Key('talent-invite')),
      delta: -250,
    );
    await tester.tap(find.byKey(const Key('talent-invite')));
    await tester.pumpAndSettle();
    expect(find.byType(TalentInterviewInviteSheet), findsOneWidget);
    expect(find.text('暂无可用面试官'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('invite-submit')))
          .onPressed,
      isNull,
    );
    expect(source.invites, isEmpty);
  });
}
