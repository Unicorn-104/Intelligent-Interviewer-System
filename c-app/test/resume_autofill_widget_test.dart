import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';
import 'package:intelligent_interviewer/features/resume/domain/app_resume.dart';
import 'package:intelligent_interviewer/screens/resume_screen.dart';

void main() {
  testWidgets('AI result directly fills education work and project cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final draft = AppResume.fromJson({
      'resumeName': '合成简历',
      'structureMethod': 'AI',
      'educations': [
        {'school': '示例大学', 'major': '计算机', 'degree': 3},
      ],
      'works': [
        {'company': '示例科技公司', 'position': '研发工程师'},
      ],
      'projects': [
        {'name': '示例订单项目', 'role': '后端开发'},
      ],
      'skills': [
        {'name': 'Java', 'level': null},
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ResumeEditorScreen(
          session: const AuthSession(
            token: 'synthetic-session',
            userId: 17,
            userName: 'test',
            nickName: '测试',
          ),
          resume: draft,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('示例大学'), findsOneWidget);
    expect(find.text('示例科技公司'), findsOneWidget);
    expect(find.text('研发工程师'), findsOneWidget);
    expect(find.text('示例订单项目'), findsOneWidget);
    expect(find.text('点击添加'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
