import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/features/ai/domain/ai_models.dart';
import 'package:intelligent_interviewer/features/ai/presentation/ai_chat_screen.dart';
import 'package:intelligent_interviewer/features/ai/presentation/ai_markdown_content.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';
import 'package:intelligent_interviewer/theme/app_theme.dart';

import 'ai_agent_test.dart' show FakeAiApi;

const _answer = '# 模拟分析\n\n**技能优势**\n\n- 补充项目成果';

class _MarkdownApi extends FakeAiApi {
  @override
  Future<Map<String, dynamic>> messages(
    String token,
    String id, {
    int? before,
  }) async {
    final result = await super.messages(token, id, before: before);
    if (completed) {
      result['items'] = [
        {'role': 'user', 'content': '**请分析**'},
        {'role': 'assistant', 'content': _answer},
      ];
    }
    return result;
  }
}

Finder _selectable(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is SelectableText &&
      (widget.data ?? widget.textSpan?.toPlainText()) == text,
);

Future<void> _openChat(WidgetTester tester, _MarkdownApi api) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: AiChatScreen(
        api: api,
        conversation: const AiSession('session', '模拟会话'),
        session: const AuthSession(
          token: 'synthetic-token',
          userId: 17,
          userName: 'test',
          nickName: 'test',
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('saved assistant formats Markdown and user text stays literal', (
    tester,
  ) async {
    final api = _MarkdownApi()..completed = true;
    addTearDown(() async {
      api.client.close();
      await api.stream.close();
    });
    await _openChat(tester, api);
    expect(_selectable('**请分析**'), findsOneWidget);
    expect(_selectable('模拟分析'), findsOneWidget);
    expect(_selectable('技能优势'), findsOneWidget);
    expect(_selectable('补充项目成果'), findsOneWidget);
    final heading = tester.widget<SelectableText>(_selectable('模拟分析'));
    final styles = <TextStyle>[];
    heading.textSpan!.visitChildren((span) {
      if (span.style != null) styles.add(span.style!);
      return true;
    });
    expect(styles.any((style) => style.fontSize == 20), isTrue);
    final strong = tester.widget<SelectableText>(_selectable('技能优势'));
    styles.clear();
    strong.textSpan!.visitChildren((span) {
      if (span.style != null) styles.add(span.style!);
      return true;
    });
    expect(styles.any((style) => style.fontWeight == FontWeight.w600), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'streaming partial Markdown completes and survives history reload',
    (tester) async {
      final api = _MarkdownApi()..active = true;
      addTearDown(() async {
        api.client.close();
        await api.stream.close();
      });
      await _openChat(tester, api);
      api.stream.add(const AiEvent(1, 'delta', {'text': '# 模拟分析\n\n**技能'}));
      await tester.pump();
      expect(_selectable('模拟分析'), findsOneWidget);
      expect(tester.takeException(), isNull);
      api.stream.add(const AiEvent(2, 'delta', {'text': '优势**\n\n- 补充项目成果'}));
      await tester.pump();
      expect(_selectable('技能优势'), findsOneWidget);
      expect(_selectable('补充项目成果'), findsOneWidget);
      api.active = false;
      api.completed = true;
      await tester.runAsync(() async {
        api.stream.add(const AiEvent(3, 'done', {'status': 'COMPLETED'}));
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(_selectable('技能优势'), findsOneWidget);
      expect(find.byTooltip('发送'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('wide table and code scroll on narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: const [
              AiMarkdownContent(
                content:
                    '## 模拟建议\n\n'
                    '> 分步完善内容\n\n'
                    '```text\n'
                    'a_very_long_line_of_code_that_should_scroll_horizontally_1234567890\n'
                    '```\n\n'
                    '| 技能及相关项目经历 | 可以补充的量化成果 | 下一步行动计划 |\n'
                    '| --- | --- | --- |\n'
                    '| 模拟项目 | 模拟成果 | 模拟计划 |\n\n'
                    '![模拟图片](https://example.invalid/image.png)',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_selectable('模拟图片'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    final horizontal = find.byWidgetPredicate(
      (widget) => widget is Scrollable && widget.axis == Axis.horizontal,
    );
    expect(horizontal, findsNWidgets(2));
    for (final element in horizontal.evaluate()) {
      final state = tester.state<ScrollableState>(
        find.byWidget(element.widget),
      );
      expect(state.position.maxScrollExtent, greaterThan(0));
    }
    await tester.drag(horizontal.last, const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(horizontal.last).position.pixels,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);
  });
}
