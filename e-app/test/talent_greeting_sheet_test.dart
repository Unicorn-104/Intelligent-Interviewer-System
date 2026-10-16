import 'package:enterprise_recruiter/features/enterprise/talent/widgets/talent_greeting_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/talent_detail_fixture.dart';

void main() {
  testWidgets('读取已有文案，编辑后模板覆盖需确认，取消保留，不发送消息', (tester) async {
    final source = TalentFakeSource();
    await pumpTalentWidget(
      tester,
      TalentGreetingSheet(
        candidateId: 11,
        name: '合成候选人',
        source: source,
        job: talentTestJob,
      ),
    );
    expect(source.greetingCalls, 1);
    expect(find.text('模板草稿，非实时 AI 生成'), findsOneWidget);
    const aiMessage = 'AI 结果仅供参考，评分和报告基于模型分析，不构成录用结论';
    final infoIcon = find.byIcon(Icons.info_outline);
    expect(infoIcon, findsOneWidget);
    expect(find.text(aiMessage), findsNothing);
    await tester.tap(infoIcon);
    await tester.pumpAndSettle();
    expect(find.text(aiMessage), findsOneWidget);
    Tooltip.dismissAllToolTips();
    await tester.pumpAndSettle();
    expect(find.text(aiMessage), findsNothing);
    expect(infoIcon, findsOneWidget);
    await tester.enterText(find.byType(TextField), '人工编辑的草稿');
    await tester.pump();
    expect(find.text('人工编辑的草稿'), findsNWidgets(2));
    await tester.tap(find.text('生成模板草稿'));
    await tester.pumpAndSettle();
    expect(find.text('替换当前招呼语草稿？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '人工编辑的草稿',
    );
    await tester.tap(find.text('生成模板草稿'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('替换'));
    await tester.pumpAndSettle();
    final text = tester
        .widget<TextField>(find.byType(TextField))
        .controller!
        .text;
    expect(text, contains('合成候选人'));
    expect(text, contains('合成测试岗位'));
    expect(find.text('当前内容：本地模板草稿'), findsOneWidget);
    expect(source.invites, isEmpty);
    expect(source.greetingCalls, 1);
    expect(find.text('发送'), findsNothing);
  });
  testWidgets('无已有文案仍可生成本地模板且无岗位上下文可用', (tester) async {
    final source = TalentFakeSource()..greeting = null;
    await pumpTalentWidget(
      tester,
      TalentGreetingSheet(candidateId: 11, name: '合成候选人', source: source),
    );
    expect(find.text('暂无已有招呼语'), findsOneWidget);
    await tester.tap(find.text('生成模板草稿'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      contains('合适的职业机会'),
    );
  });
}
