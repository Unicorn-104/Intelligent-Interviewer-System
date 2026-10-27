import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/conversation_page.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/data/chat_attachment_picker.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/models/message_view_data.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'message_center_page_test.dart'
    show FakeMessageSource, mountMessages, sessionJson;

class ComposerSource extends FakeMessageSource {
  List<ChatQuickReply> replies = [
    const ChatQuickReply(id: 7, content: '合成常用语', category: '邀约'),
  ];
  final saves = <(int?, String)>[];
  bool quickFail = false, uploadFail = false;
  ApiException? saveError, attachmentError;
  Completer<void>? saveGate, uploadGate;
  ChatPickedAttachment? picked;
  final pickRequests = <bool>[];
  int uploads = 0, attachmentSends = 0;
  @override
  Future<List<ChatQuickReply>> loadQuickReplies() async {
    if (quickFail) throw const ApiException('合成常用语读取失败');
    return replies;
  }

  @override
  Future<void> saveQuickReply({
    ChatQuickReply? reply,
    required String content,
  }) async {
    saves.add((reply?.id, content));
    await saveGate?.future;
    if (saveError != null) throw saveError!;
    final next = ChatQuickReply(
      id: reply?.id ?? 8,
      content: content,
      category: reply?.category ?? '常用语',
    );
    replies = [
      for (final row in replies)
        if (row.id != next.id) row,
      next,
    ];
  }

  @override
  Future<ChatPickedAttachment?> pickAttachment({required bool image}) async {
    pickRequests.add(image);
    return picked;
  }

  @override
  Future<ChatUploadedAttachment> uploadAttachment(
    ChatPickedAttachment file,
  ) async {
    uploads++;
    await uploadGate?.future;
    if (uploadFail) throw const ApiException('合成附件上传失败');
    return ChatUploadedAttachment(
      name: file.name,
      url: '/profile/upload/synthetic.pdf',
      isImage: file.isImage,
    );
  }

  @override
  Future<void> sendAttachment(
    int sessionId,
    ChatUploadedAttachment file,
  ) async {
    attachmentSends++;
    if (attachmentError != null) throw attachmentError!;
    messages = [
      ...messages,
      ConversationMessage.fromJson({
        'messageId': messages.length + 1,
        'isMine': true,
        'type': file.isImage ? 2 : 3,
        'content': file.name,
        'attachmentUrl': file.url,
      }),
    ];
  }
}

void main() {
  Future<void> toggle(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  TextEditingController input(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!;
  ChatPickedAttachment file() => ChatPickedAttachment(
    name: 'synthetic.pdf',
    bytes: Uint8List.fromList(utf8.encode('%PDF-synthetic')),
    isImage: false,
  );

  testWidgets('默认常字与加号，聚焦改菜单图标，输入与清空切换发送和加号', (tester) async {
    await mountMessages(tester, ComposerSource(), chat: true);
    expect(find.text('常'), findsOneWidget);
    expect(find.byKey(const Key('chat-more-toggle')), findsOneWidget);
    expect(find.byKey(const Key('chat-send')), findsNothing);
    await toggle(tester, 'chat-input');
    expect(find.text('常'), findsNothing);
    expect(find.byIcon(Icons.short_text), findsOneWidget);
    await tester.enterText(find.byKey(const Key('chat-input')), '合成草稿');
    await tester.pump();
    expect(find.byKey(const Key('chat-send')), findsOneWidget);
    expect(find.byKey(const Key('chat-more-toggle')), findsNothing);
    await tester.enterText(find.byKey(const Key('chat-input')), '   ');
    await tester.pump();
    expect(find.byKey(const Key('chat-more-toggle')), findsOneWidget);
  });

  testWidgets('输入栏为无描边的灰色胶囊，发送按钮使用圆形纸飞机并保留无障碍提示', (tester) async {
    final source = ComposerSource();
    await mountMessages(tester, source, chat: true);
    final toolbar = tester.widget<DecoratedBox>(
      find.byKey(const Key('chat-composer-toolbar')),
    );
    final decoration = toolbar.decoration as BoxDecoration;
    expect(decoration.color, AppColors.background);
    expect(decoration.borderRadius, BorderRadius.circular(28));
    final field = tester.widget<TextField>(find.byKey(const Key('chat-input')));
    expect(field.decoration!.enabledBorder, InputBorder.none);
    expect(field.decoration!.focusedBorder, InputBorder.none);
    expect(field.decoration!.disabledBorder, InputBorder.none);
    expect(field.decoration!.fillColor, Colors.transparent);
    await tester.enterText(find.byKey(const Key('chat-input')), '合成发送内容');
    await tester.pump();
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.byTooltip('发送消息'), findsOneWidget);
    expect(find.text('发送'), findsNothing);
    final send = tester.widget<FilledButton>(
      find.byKey(const Key('chat-send')),
    );
    expect(send.style!.shape!.resolve({}), isA<CircleBorder>());
    expect(
      tester.getSize(find.byKey(const Key('chat-send'))).shortestSide,
      greaterThanOrEqualTo(46),
    );
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(source.sends, ['合成发送内容']);
    expect(find.byKey(const Key('chat-more-toggle')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('常用语点击立即发送但不清空手输草稿，发送中禁用防重复', (tester) async {
    final source = ComposerSource()..sendGate = Completer<void>();
    await mountMessages(tester, source, chat: true);
    await tester.enterText(find.byKey(const Key('chat-input')), '保留草稿');
    await tester.pump();
    await toggle(tester, 'chat-quick-toggle');
    await tester.tap(find.byKey(const Key('chat-quick-item-7')));
    await tester.pump();
    expect(source.sends, ['合成常用语']);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('chat-quick-send-7')))
          .onPressed,
      isNull,
    );
    source.sendGate!.complete();
    await tester.pumpAndSettle();
    expect(input(tester).text, '保留草稿');
  });

  testWidgets('常用语可新增并按真实模板ID编辑，保存中不能重复提交', (tester) async {
    final source = ComposerSource()..saveGate = Completer<void>();
    await mountMessages(tester, source, chat: true);
    await toggle(tester, 'chat-quick-toggle');
    await toggle(tester, 'chat-quick-add');
    expect(find.textContaining('共享模板'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('chat-quick-editor')),
      '合成新增常用语',
    );
    await tester.tap(find.byKey(const Key('chat-quick-save')));
    await tester.pump();
    expect(source.saves, [(null, '合成新增常用语')]);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('chat-quick-save')))
          .onPressed,
      isNull,
    );
    source.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('合成新增常用语'), findsOneWidget);
    await toggle(tester, 'chat-quick-manage');
    await toggle(tester, 'chat-quick-edit-7');
    await tester.enterText(
      find.byKey(const Key('chat-quick-editor')),
      '合成修改常用语',
    );
    await tester.tap(find.byKey(const Key('chat-quick-save')));
    await tester.pumpAndSettle();
    expect(source.saves.last, (7, '合成修改常用语'));
    expect(find.text('合成修改常用语'), findsOneWidget);
    expect(find.text('合成常用语'), findsNothing);
  });

  testWidgets('常用语读取失败可重试，未知保存结果不允许重复新增', (tester) async {
    final source = ComposerSource()..quickFail = true;
    await mountMessages(tester, source, chat: true);
    await toggle(tester, 'chat-quick-toggle');
    expect(find.text('常用语暂不可用'), findsOneWidget);
    source.quickFail = false;
    await tester.tap(find.text('重试读取常用语'));
    await tester.pumpAndSettle();
    expect(find.text('合成常用语'), findsOneWidget);
    await toggle(tester, 'chat-quick-add');
    source.saveError = const ApiException('合成超时');
    await tester.enterText(
      find.byKey(const Key('chat-quick-editor')),
      '合成新增常用语',
    );
    await tester.tap(find.byKey(const Key('chat-quick-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('保存结果待核对'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('chat-quick-save')))
          .onPressed,
      isNull,
    );
    expect(source.saves, hasLength(1));
    expect(source.sends, isEmpty);
  });

  testWidgets('表情在光标处插入与完整删除，表情键切为键盘并保留文本', (tester) async {
    final source = ComposerSource();
    await mountMessages(tester, source, chat: true);
    await tester.enterText(find.byKey(const Key('chat-input')), '甲乙');
    input(tester).selection = const TextSelection.collapsed(offset: 1);
    await toggle(tester, 'chat-emoji-toggle');
    expect(find.byKey(const Key('chat-emoji-panel')), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_alt_outlined), findsOneWidget);
    await toggle(tester, 'chat-emoji-😊');
    expect(input(tester).text, '甲😊乙');
    await toggle(tester, 'chat-emoji-delete');
    expect(input(tester).text, '甲乙');
    await tester.ensureVisible(find.byKey(const Key('chat-emoji-🌹')));
    await tester.pumpAndSettle();
    await toggle(tester, 'chat-emoji-🌹');
    await toggle(tester, 'chat-emoji-toggle');
    expect(find.byKey(const Key('chat-emoji-panel')), findsNothing);
    expect(input(tester).text, '甲🌹乙');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(source.sends, ['甲🌹乙']);
  });

  testWidgets('加号展开图片文件和岗位入口，面板切换互斥且返回先收起面板', (tester) async {
    await mountMessages(tester, ComposerSource(), chat: true);
    await toggle(tester, 'chat-more-toggle');
    expect(find.byKey(const Key('chat-attachment-panel')), findsOneWidget);
    expect(find.byKey(const Key('chat-pick-image')), findsOneWidget);
    expect(find.byKey(const Key('chat-pick-file')), findsOneWidget);
    expect(find.text('语音'), findsNothing);
    await toggle(tester, 'chat-quick-toggle');
    expect(find.byKey(const Key('chat-attachment-panel')), findsNothing);
    expect(find.byKey(const Key('chat-quick-panel')), findsOneWidget);
    await toggle(tester, 'chat-emoji-toggle');
    expect(find.byKey(const Key('chat-quick-panel')), findsNothing);
    expect(find.byKey(const Key('chat-emoji-panel')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-composer-panel')), findsNothing);
    expect(find.byType(ChatPage), findsOneWidget);
  });

  testWidgets('取消附件选择或确认不上传不发消息，确认发送文件后展示文件卡片', (tester) async {
    final source = ComposerSource();
    await mountMessages(tester, source, chat: true);
    await toggle(tester, 'chat-more-toggle');
    await toggle(tester, 'chat-pick-file');
    expect(source.uploads, 0);
    source.picked = file();
    await toggle(tester, 'chat-pick-file');
    expect(source.uploads, 0);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(source.uploads, 0);
    await toggle(tester, 'chat-pick-file');
    await toggle(tester, 'chat-confirm-attachment');
    expect(source.uploads, 1);
    expect(source.attachmentSends, 1);
    expect(find.byKey(const Key('chat-file-2')), findsOneWidget);
    expect(source.sends, isEmpty);
  });

  testWidgets('上传失败不能锁死文本发送，消息发送超时才进入人工核对', (tester) async {
    final source = ComposerSource()
      ..picked = file()
      ..uploadFail = true;
    await mountMessages(tester, source, chat: true);
    await toggle(tester, 'chat-more-toggle');
    await toggle(tester, 'chat-pick-file');
    await toggle(tester, 'chat-confirm-attachment');
    expect(source.attachmentSends, 0);
    expect(find.text('合成附件上传失败'), findsOneWidget);
    expect(find.byKey(const Key('chat-resume-edit')), findsNothing);
    source.uploadFail = false;
    source.attachmentError = const ApiException('合成发送超时');
    await toggle(tester, 'chat-pick-file');
    await toggle(tester, 'chat-confirm-attachment');
    expect(source.attachmentSends, 1);
    expect(find.textContaining('附件发送结果待核对'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('chat-pick-file')))
          .onPressed,
      isNull,
    );
  });

  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('四种输入状态在$size二倍字号及键盘下均不溢出', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ChatPage(
            session: sessionJson(),
            source: ComposerSource(),
            pollInterval: Duration.zero,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final key in [
        'chat-quick-toggle',
        'chat-more-toggle',
        'chat-emoji-toggle',
      ]) {
        await toggle(tester, key);
        expect(tester.takeException(), isNull, reason: key);
      }
      await toggle(tester, 'chat-emoji-toggle');
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height < 500 ? 100 : 220,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(
        find.byKey(const Key('chat-input')),
        '合成多行输入内容' * 6,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'keyboard');
    });
  }
}
