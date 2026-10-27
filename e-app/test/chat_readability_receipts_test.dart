import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/conversation_page.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/models/message_view_data.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/widgets/chat_message_time.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/widgets/chat_bubble_border.dart';

import 'reschedule_chat_card_test.dart' show CardMessageSource, sessionJson;

ConversationMessage row(
  int id, {
  bool mine = false,
  String? status,
  String? content,
  String? time,
}) => ConversationMessage.fromJson({
  'messageId': id,
  'isMine': mine,
  'type': 1,
  'content': content ?? '合成消息$id',
  'sendTime': time ?? '2026-10-26 09:00:00',
  'deliveryStatus': status,
});

class ReceiptSource extends CardMessageSource {
  final acknowledgments = <(int, int)>[];
  bool failAck = false;
  @override
  Future<bool> acknowledgeRead(int session, int last) async {
    acknowledgments.add((session, last));
    if (failAck) throw const SocketException('synthetic');
    return true;
  }
}

Future<void> mount(
  WidgetTester tester,
  ReceiptSource source, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light.copyWith(
        textTheme: AppTheme.light.textTheme.apply(fontFamily: 'PreviewSans'),
        primaryTextTheme: AppTheme.light.primaryTextTheme.apply(
          fontFamily: 'PreviewSans',
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: const ValueKey('chat-preview'),
        child: ChatPage(
          session: sessionJson(),
          source: source,
          pollInterval: const Duration(seconds: 8),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final font = File(
      '${Platform.environment['WINDIR'] ?? 'C:/Windows'}/Fonts/msyh.ttc',
    );
    if (await font.exists()) {
      final loader = FontLoader('PreviewSans')
        ..addFont(font.readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      final icon = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (await icon.exists()) {
        await (FontLoader(
          'MaterialIcons',
        )..addFont(icon.readAsBytes().then(ByteData.sublistView))).load();
      }
    }
  });

  test('时间按首条、五分钟间隔与跨日分组，昨天按自然日期计算', () {
    expect(showChatTimestamp(DateTime(2026, 10, 26, 9), null), isTrue);
    expect(
      showChatTimestamp(
        DateTime(2026, 10, 26, 9, 4),
        DateTime(2026, 10, 26, 9),
      ),
      isFalse,
    );
    expect(
      showChatTimestamp(
        DateTime(2026, 10, 26, 9, 5),
        DateTime(2026, 10, 26, 9),
      ),
      isTrue,
    );
    expect(
      showChatTimestamp(DateTime(2026, 10, 26), DateTime(2026, 10, 25, 23, 59)),
      isTrue,
    );
    expect(
      chatTimestamp(
        DateTime.parse('2026-10-25T09:05:00+08:00'),
        now: DateTime.parse('2026-10-26T23:00:00+08:00'),
      ),
      '昨天 09:05',
    );
    expect(
      chatTimestamp(
        DateTime.parse('2025-10-25T09:05:00+08:00'),
        now: DateTime(2026, 10, 26),
      ),
      '2025年10月25日 09:05',
    );
  });

  testWidgets('深色16号字与浅绿白气泡，时间位于消息之间，长按查看完整时间', (tester) async {
    final source = ReceiptSource()
      ..messages = [
        row(1, content: '合成求职者消息'),
        row(2, mine: true, content: '合成招聘者回复', time: '2026-10-26 09:02:00'),
        row(3, time: '2026-10-26 09:08:00'),
      ];
    await mount(tester, source);
    final bubble = tester.widget<Container>(
      find.byKey(const ValueKey('chat-bubble-2')),
    );
    expect(
      (bubble.decoration as ShapeDecoration).color,
      const Color(0xFF95EC69),
    );
    final text = tester.widget<Text>(find.text('合成招聘者回复'));
    expect(text.style?.color, const Color(0xFF161616));
    expect(text.style?.fontSize, 16);
    expect(find.byKey(const ValueKey('chat-time-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-time-2')), findsNothing);
    expect(find.byKey(const ValueKey('chat-time-3')), findsOneWidget);
    await tester.longPress(find.text('合成招聘者回复'));
    await tester.pumpAndSettle();
    expect(find.text('消息时间'), findsOneWidget);
    expect(find.text('2026年10月26日 09:02:00'), findsOneWidget);
    expect(find.text('复制消息'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('仅服务端明确回执显示送达和已读，未知或对方消息不伪造状态', (tester) async {
    final source = ReceiptSource()
      ..messages = [
        row(1, status: 'received'),
        row(2, mine: true, status: 'delivered'),
        row(3, mine: true),
      ];
    await mount(tester, source);
    expect(find.text('送达'), findsOneWidget);
    expect(find.text('已读'), findsNothing);
    expect(find.byKey(const ValueKey('chat-receipt-1')), findsNothing);
    expect(find.byKey(const ValueKey('chat-receipt-3')), findsNothing);
    expect(source.acknowledgments, [(8, 3)]);
    source.messages = [
      row(1, status: 'received'),
      row(2, mine: true, status: 'read'),
      row(3, mine: true),
    ];
    await tester.tap(find.byKey(const Key('chat-refresh')));
    await tester.pumpAndSettle();
    expect(find.text('送达'), findsNothing);
    expect(find.text('已读'), findsOneWidget);
    expect(source.acknowledgments, [(8, 3)]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('回执确认失败不会伪造已读，下次刷新只重试确认', (tester) async {
    final source = ReceiptSource()
      ..failAck = true
      ..messages = [row(1, mine: true, status: 'delivered')];
    await mount(tester, source);
    expect(find.text('送达'), findsOneWidget);
    expect(find.text('已读'), findsNothing);
    source.failAck = false;
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(source.acknowledgments.length, greaterThanOrEqualTo(2));
    expect(find.text('送达'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('应用后台和被其他页面覆盖时不提交已读确认', (tester) async {
    final source = ReceiptSource()..messages = [row(1, status: 'received')];
    await mount(tester, source);
    expect(source.acknowledgments.length, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    source.messages = [row(2, status: 'received')];
    await tester.pump(const Duration(seconds: 8));
    expect(source.acknowledgments.length, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(source.acknowledgments.last, (8, 2));
    final context = tester.element(find.byType(ChatPage));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('合成覆盖页')),
      ),
    );
    await tester.pumpAndSettle();
    source.messages = [row(3, status: 'received')];
    await tester.pump(const Duration(seconds: 8));
    expect(source.acknowledgments.last, (8, 2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('查看旧历史时不确认新消息，返回底部后才确认最新快照', (tester) async {
    final source = ReceiptSource()
      ..messages = List.generate(
        15,
        (i) => row(i + 1, status: 'received', content: '合成历史消息 ' * 8),
      );
    await mount(tester, source);
    expect(source.acknowledgments.last, (8, 15));
    await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    source.messages = [...source.messages, row(16, status: 'received')];
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(source.acknowledgments.last, (8, 15));
    await tester.drag(find.byType(ListView).first, const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(source.acknowledgments.last, (8, 16));
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('长消息和状态在$size大字号下不溢出', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = ReceiptSource()
        ..messages = [
          row(1, mine: true, status: 'read', content: '合成中文长消息与时间查看 ' * 15),
        ];
      await mount(tester, source, scale: 1.8);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final width in [320.0, 430.0, 900.0]) {
    testWidgets('多行双向气泡在宽度$width下左右严格对齐且回执不占宽', (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = ReceiptSource()
        ..messages = [
          row(1, content: '白色消息第一行\n白色消息第二行'),
          row(2, mine: true, status: 'delivered', content: '绿色消息第一行\n绿色消息第二行'),
          row(3, mine: true, status: 'read', content: '短'),
          row(4, content: 'ok'),
        ];
      await mount(tester, source);
      final incoming = tester.getRect(
        find.byKey(const ValueKey('chat-bubble-1')),
      );
      final outgoing = tester.getRect(
        find.byKey(const ValueKey('chat-bubble-2')),
      );
      final ownShort = tester.getRect(
        find.byKey(const ValueKey('chat-bubble-3')),
      );
      final peerShort = tester.getRect(
        find.byKey(const ValueKey('chat-bubble-4')),
      );
      final status = tester.getRect(
        find.byKey(const ValueKey('chat-receipt-2')),
      );
      expect(outgoing.left, closeTo(incoming.left, .01));
      expect(outgoing.right, closeTo(incoming.right, .01));
      expect(ownShort.right, closeTo(outgoing.right, .01));
      expect(peerShort.left, closeTo(incoming.left, .01));
      expect(ownShort.width, lessThan(outgoing.width));
      expect(peerShort.width, lessThan(incoming.width));
      expect(status.right, lessThanOrEqualTo(outgoing.left - 5));
      expect(find.text('送达'), findsOneWidget);
      expect(find.text('已读'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final width in [320.0, 430.0, 900.0]) {
    testWidgets('完整句子在宽度$width不论是否换行都按气泡矩形对齐', (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = ReceiptSource()
        ..messages = [
          row(1, content: '您好，请问周五下午方便面试吗？'),
          row(2, mine: true, status: 'read', content: '可以的，下午三点我有时间。'),
          row(3, content: '好的，面试预计45分钟。\n请提前准备好项目介绍。'),
          row(4, mine: true, status: 'delivered', content: '收到，谢谢！我会准时参加。'),
        ];
      await mount(tester, source);
      final first = tester.getRect(find.byKey(const ValueKey('chat-bubble-1')));
      for (final id in [2, 3, 4]) {
        final body = tester.getRect(find.byKey(ValueKey('chat-bubble-$id')));
        expect(body.left, closeTo(first.left, .01));
        expect(body.right, closeTo(first.right, .01));
        if (id == 2 || id == 4) {
          final status = tester.getRect(
            find.byKey(ValueKey('chat-receipt-$id')),
          );
          expect(status.right, lessThanOrEqualTo(body.left - 5));
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('白色气泡尖角连接处连续填充，没有矩形边框穿过接缝', (tester) async {
    const shape = ChatBubbleBorder(mine: false);
    final path = shape.getOuterPath(const Rect.fromLTWH(10, 0, 100, 70));
    expect(path.computeMetrics().length, 1);
    expect(path.contains(const Offset(7, 24)), isTrue);
    expect(path.contains(const Offset(11, 24)), isTrue);
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = const ShapeDecoration(
        color: Colors.white,
        shape: shape,
      ).createBoxPainter(() {});
      painter.paint(
        canvas,
        const Offset(10, 0),
        const ImageConfiguration(size: Size(100, 70)),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(120, 70);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      for (final x in [8, 9, 10, 11, 12]) {
        final pixel = (24 * 120 + x) * 4;
        expect(bytes!.buffer.asUint8List().sublist(pixel, pixel + 4), [
          255,
          255,
          255,
          255,
        ]);
      }
      image.dispose();
      picture.dispose();
      painter.dispose();
    });
  });

  testWidgets('生成合成消息气泡预览', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    String time(int minute) =>
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} 09:${minute.toString().padLeft(2, '0')}:00';
    final source = ReceiptSource()
      ..messages = [
        row(1, content: '您好，请问周五下午方便面试吗？', time: time(0)),
        row(
          2,
          mine: true,
          status: 'read',
          content: '可以的，下午三点我有时间。',
          time: time(2),
        ),
        row(3, content: '好的，面试预计45分钟。\n请提前准备好项目介绍。', time: time(8)),
        row(
          4,
          mine: true,
          status: 'delivered',
          content: '收到，谢谢！我会准时参加。',
          time: time(9),
        ),
      ];
    await mount(tester, source);
    final expectedBody = tester.getRect(
      find.byKey(const ValueKey('chat-bubble-1')),
    );
    for (final id in [2, 3, 4]) {
      final body = tester.getRect(find.byKey(ValueKey('chat-bubble-$id')));
      expect(body.left, closeTo(expectedBody.left, .01));
      expect(body.right, closeTo(expectedBody.right, .01));
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('chat-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/chat-preview').create(recursive: true);
      await File('build/chat-preview/readable-chat.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  });
}
