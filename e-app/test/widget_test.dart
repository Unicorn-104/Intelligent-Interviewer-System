import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:enterprise_recruiter/widgets/page_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('空状态展示标题、说明和操作', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: PageMessage(
          icon: Icons.people_outline,
          title: '暂无候选人',
          message: '候选人进入流程后显示',
          actionLabel: '重试',
          onAction: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('暂无候选人'), findsOneWidget);
    expect(find.text('候选人进入流程后显示'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(tapped, isTrue);
  });
}
