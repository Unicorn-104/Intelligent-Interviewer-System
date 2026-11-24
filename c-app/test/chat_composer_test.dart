import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/features/messages/data/chat_speech_input.dart';
import 'package:intelligent_interviewer/widgets/chat_composer.dart';
import 'package:intelligent_interviewer/theme/app_theme.dart';

class FakeSpeechEngine implements ChatSpeechEngine {
  bool available = true;
  List<String> languages = ['en-US', 'zh-CN'];
  Completer<bool>? initialization;
  void Function(String, bool)? result;
  String? chosenLocale;
  int starts = 0, cancels = 0;
  String finalText = '你好，我想了解这个岗位';
  @override
  Future<bool> initialize(void Function(String) onError) async =>
      initialization == null ? available : initialization!.future;
  @override
  Future<List<String>> locales() async => languages;
  @override
  Future<void> listen(
    String locale,
    void Function(String, bool) onResult,
  ) async {
    chosenLocale = locale;
    starts++;
    result = onResult;
  }

  @override
  Future<void> stop() async => result?.call(finalText, true);
  @override
  Future<void> cancel() async {
    cancels++;
  }
}

void main() {
  test('权限初始化期间取消不会在松手后开始收音', () async {
    final engine = FakeSpeechEngine()..initialization = Completer<bool>();
    final input = ChatSpeechInput(engine: engine);
    final starting = input.start();
    await input.finish(cancel: true);
    engine.initialization!.complete(true);
    await starting;
    expect(engine.starts, 0);
  });

  test('优先中文、松手返回最终文本、取消忽略迟到结果', () async {
    final engine = FakeSpeechEngine();
    final input = ChatSpeechInput(engine: engine);
    await input.start();
    engine.result!('你好', false);
    expect(await input.finish(), engine.finalText);
    expect(engine.chosenLocale, 'zh-CN');
    await input.start();
    await input.finish(cancel: true);
    engine.result!('迟到内容', true);
    expect(await input.finish(), isNull);
  });

  test('拒绝权限或无中文服务会明确报错且停止识别', () async {
    final engine = FakeSpeechEngine()..available = false;
    final input = ChatSpeechInput(engine: engine);
    await expectLater(input.start(), throwsFormatException);
    expect(engine.starts, 0);
    engine.available = true;
    engine.languages = ['en-US'];
    await expectLater(input.start(), throwsFormatException);
    expect(engine.starts, 0);
    expect(engine.cancels, 2);
  });

  Future<({TextEditingController controller, FakeSpeechEngine engine})> mount(
    WidgetTester tester,
    VoidCallback onSend,
  ) async {
    final controller = TextEditingController(text: '草稿：');
    addTearDown(controller.dispose);
    final engine = FakeSpeechEngine();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox()),
              ChatComposer(
                controller: controller,
                onSend: onSend,
                speechInput: ChatSpeechInput(engine: engine),
                onCamera: () {},
                actions: [ChatComposerAction('发送文件', Icons.attach_file, () {})],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (controller: controller, engine: engine);
  }

  testWidgets('语音只补入草稿并切回键盘，确认点击发送前不发消息', (tester) async {
    var sent = 0;
    final state = await mount(tester, () => sent++);
    state.controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.tap(find.byTooltip('切换语音输入'));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('按住 说话')),
    );
    await tester.pump();
    expect(state.engine.starts, 1);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.controller.text, '草稿：你好，我想了解这个岗位');
    expect(sent, 0);
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.byTooltip('发送'));
    expect(sent, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('上滑取消保留草稿，离开页面也停止收音', (tester) async {
    final state = await mount(tester, () {});
    await tester.tap(find.byTooltip('切换语音输入'));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('按住 说话')),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, -85));
    await tester.pump();
    expect(find.text('松开取消'), findsWidgets);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.controller.text, '草稿：');
    final next = await tester.startGesture(
      tester.getCenter(find.text('按住 说话')),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await next.up();
    expect(state.engine.cancels, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏与多行文字下相机、附件、发送按钮保持可用', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = await mount(tester, () {});
    state.controller.text = '第一行\n第二行\n第三行';
    await tester.pumpAndSettle();
    expect(find.byTooltip('拍照'), findsOneWidget);
    expect(find.byTooltip('更多功能'), findsOneWidget);
    expect(find.byTooltip('发送'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
