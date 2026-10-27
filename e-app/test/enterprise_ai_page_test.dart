import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_recruiter/features/enterprise/assistant/enterprise_ai_page.dart';
import 'package:enterprise_recruiter/features/enterprise/assistant/enterprise_ai_data_source.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';

import 'support/fake_enterprise_ai_source.dart';

Future<void> mount(
  WidgetTester tester,
  FakeEnterpriseAiSource source, {
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: EnterpriseAiPage(source: source),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('新对话和历史入口独立，打开或预填建议不会触发模型', (tester) async {
    final source = FakeEnterpriseAiSource();
    await mount(tester, source);
    expect(find.text('AI 招聘助手'), findsOneWidget);
    await tester.tap(find.byKey(const Key('enterprise-ai-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enterprise-ai-history')));
    await tester.pumpAndSettle();
    expect(find.text('暂无历史对话'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭历史'));
    await tester.pumpAndSettle();
    expect(source.creates, 0);
    expect(source.starts, 0);
  });
  testWidgets('真实历史可打开，确认删除当前会话回到新对话', (tester) async {
    final source = FakeEnterpriseAiSource()
      ..history = [EnterpriseAiSession(1, '合成历史主题', updatedAt: DateTime.now())]
      ..rows = [
        const EnterpriseAiMessage(11, 'user', '合成历史问题'),
        const EnterpriseAiMessage(12, 'assistant', '合成历史回答', state: 'C'),
      ];
    await mount(tester, source);
    expect(find.text('合成历史问题'), findsOneWidget);
    await tester.tap(find.byKey(const Key('enterprise-ai-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('enterprise-ai-history-1')));
    await tester.pumpAndSettle();
    expect(find.text('合成历史问题'), findsOneWidget);
    await tester.tap(find.byKey(const Key('enterprise-ai-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('对话操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除对话'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(source.deleted, [1]);
    expect(find.text('合成历史问题'), findsNothing);
    expect(source.starts, 0);
  });
  testWidgets('核对已发送请求后清空原草稿而非重复发送', (tester) async {
    final source = FakeEnterpriseAiSource()..timeout = true;
    await mount(tester, source);
    final input = find.byKey(const Key('enterprise-ai-input'));
    await tester.enterText(input, '合成核对问题');
    await tester.tap(find.byKey(const Key('enterprise-ai-send')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).enabled, isFalse);
    await tester.tap(find.byKey(const Key('enterprise-ai-verify')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, isEmpty);
    expect(find.text('合成回答'), findsOneWidget);
    expect(source.starts, 1);
  });
  for (final scale in [1.0, 1.6]) {
    testWidgets('320dp及字号$scale时欢迎页、历史、键盘布局无溢出', (tester) async {
      final source = FakeEnterpriseAiSource();
      await mount(tester, source, width: 320, scale: scale);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('enterprise-ai-history')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('关闭历史'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.tap(find.byKey(const Key('enterprise-ai-input')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = tester.getRect(
        find.byKey(const Key('enterprise-ai-send')),
      );
      expect(button.bottom, lessThanOrEqualTo(544));
    });
  }
  testWidgets('长Markdown、代码与表格只展示，不自动下载模型图片', (tester) async {
    final source = FakeEnterpriseAiSource()
      ..history = [const EnterpriseAiSession(1, '合成Markdown')]
      ..rows = [
        const EnterpriseAiMessage(
          12,
          'assistant',
          '# 合成招聘建议\n\n- 第一项\n- 第二项\n\n| 项目 | 建议 |\n|---|---|\n| JD | 明确职责 |\n\n```text\n岗位草稿\n```\n![不下载远程图片](https://example.invalid/image.png)',
          state: 'C',
        ),
      ];
    await mount(tester, source, width: 320, scale: 1.6);
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsNothing);
    expect(source.starts, 0);
  });
  testWidgets('气泡随流式片段即时增长，完成后恢复输入', (tester) async {
    final source = FakeEnterpriseAiSource()
      ..answer = const EnterpriseAiRun(12, 1, 'R', '');
    await mount(tester, source);
    await tester.enterText(
      find.byKey(const Key('enterprise-ai-input')),
      '合成实时输出问题',
    );
    await tester.tap(find.byKey(const Key('enterprise-ai-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    source.emit(const EnterpriseAiRun(12, 1, 'R', '第一段实时内容'));
    await tester.pump();
    expect(find.text('第一段实时内容'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('enterprise-ai-input')))
          .enabled,
      isFalse,
    );
    source.emit(const EnterpriseAiRun(12, 1, 'R', '第一段实时内容，第二段继续补充'));
    await tester.pump();
    expect(find.text('第一段实时内容，第二段继续补充'), findsOneWidget);
    source.emit(const EnterpriseAiRun(12, 1, 'C', '第一段实时内容，第二段继续补充。'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('enterprise-ai-input')))
          .enabled,
      isTrue,
    );
    expect(source.starts, 1);
    expect(source.polls, 0);
    expect(tester.takeException(), isNull);
  });
}
