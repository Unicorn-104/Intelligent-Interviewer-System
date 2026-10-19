import 'dart:async';

import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/message_center_page.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/system_notifications_page.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/data/message_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/models/message_view_data.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> sessionJson() => {
  'sessionId': 8,
  'peerId': 12,
  'peerName': '合成候选人',
  'lastMessage': '已收到面试安排',
  'lastMessageAt': '2026-10-18 09:30',
  'unread': 2,
};
Map<String, dynamic> noticeJson(int id) => {
  'messageId': id,
  'title': '合成系统通知$id',
  'content': '合成通知正文$id',
  'isRead': 0,
  'createdAt': '2026-10-18 09:00',
};

class FakeMessageSource extends MessageDataSource {
  List<MessageSession> sessions = [MessageSession.fromJson(sessionJson())];
  List<SystemMessage> notices = [SystemMessage.fromJson(noticeJson(4))];
  List<ConversationMessage> messages = [
    ConversationMessage.fromJson({
      'messageId': 1,
      'type': 1,
      'content': '真实接口合成消息',
      'isMine': false,
      'sendTime': '2026-10-18 09:30',
    }),
  ];
  bool sessionFail = false,
      notificationFail = false,
      historyFail = false,
      readFail = false,
      readAllFail = false;
  bool notificationMore = false;
  List<SystemMessage>? nextNotices;
  final noticeCursors = <int?>[];
  ApiException? sendFailure;
  Completer<void>? sendGate, readAllGate;
  final sends = <String>[], readNotices = <int>[];
  int historyCalls = 0,
      readCalls = 0,
      readAllCalls = 0,
      allNoticesCalls = 0,
      noticeCalls = 0;
  @override
  Future<List<MessageSession>> loadSessions() async {
    if (sessionFail) throw const ApiException('合成会话失败');
    return sessions;
  }

  @override
  Future<NotificationSlice> loadNotifications({int? beforeId}) async {
    noticeCalls++;
    noticeCursors.add(beforeId);
    if (notificationFail) throw const ApiException('合成通知失败');
    return NotificationSlice(
      beforeId == null ? notices : (nextNotices ?? []),
      notices.where((n) => !n.isRead).length,
      beforeId == null && notificationMore,
    );
  }

  @override
  Future<List<ConversationMessage>> loadMessages(int id) async {
    historyCalls++;
    if (historyFail) throw const ApiException('合成历史失败');
    return messages;
  }

  @override
  Future<void> readSession(int id) async {
    readCalls++;
    if (readFail) throw const ApiException('合成已读失败');
    sessions = sessions.map((s) => s.id == id ? s.read : s).toList();
  }

  @override
  Future<List<String>> loadQuickReplies() async => ['合成快捷回复'];
  @override
  Future<void> send(int id, String content) async {
    sends.add(content);
    if (sendFailure != null) throw sendFailure!;
    await sendGate?.future;
    messages = [
      ...messages,
      ConversationMessage.fromJson({
        'messageId': messages.length + 1,
        'type': 1,
        'content': content,
        'isMine': true,
        'sendTime': '2026-10-18 09:31',
      }),
    ];
  }

  @override
  Future<void> readAllSessions() async {
    readAllCalls++;
    await readAllGate?.future;
    sessions = sessions.map((s) => s.read).toList();
  }

  @override
  Future<void> readAllNotifications() async {
    allNoticesCalls++;
    if (readAllFail) throw const ApiException('合成通知已读失败');
    notices = notices.map((n) => n.read).toList();
  }

  @override
  Future<void> readNotification(int id) async {
    readNotices.add(id);
    notices = notices.map((n) => n.id == id ? n.read : n).toList();
  }
}

Future<void> mountMessages(
  WidgetTester tester,
  FakeMessageSource source, {
  bool chat = false,
  Size size = const Size(430, 900),
  Duration poll = Duration.zero,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: chat
          ? ChatPage(session: sessionJson(), source: source, pollInterval: poll)
          : MessageCenterPage(source: source),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('系统通知游标加载更多保留已有记录并去重', (tester) async {
    final source = FakeMessageSource()
      ..notificationMore = true
      ..notices = [
        SystemMessage.fromJson(noticeJson(8)),
        SystemMessage.fromJson(noticeJson(6)),
      ]
      ..nextNotices = [
        SystemMessage.fromJson(noticeJson(6)),
        SystemMessage.fromJson(noticeJson(4)),
      ];
    await mountMessages(tester, source);
    await tester.tap(find.byKey(const Key('messages-system')));
    await tester.pumpAndSettle();
    final more = find.text('加载更多通知');
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(source.noticeCursors.last, 6);
    expect(find.byKey(const ValueKey('system-message-8')), findsOneWidget);
    expect(find.byKey(const ValueKey('system-message-6')), findsOneWidget);
    expect(find.byKey(const ValueKey('system-message-4')), findsOneWidget);
    expect(find.text('加载更多通知'), findsNothing);
  });

  testWidgets('消息中心显示真实会话系统通知和未读，不再显示演示数据', (tester) async {
    final source = FakeMessageSource();
    await mountMessages(tester, source);
    expect(find.text('合成候选人'), findsOneWidget);
    expect(find.text('已收到面试安排'), findsOneWidget);
    expect(find.text('系统通知'), findsOneWidget);
    expect(find.text('演示数据'), findsNothing);
    expect(source.readCalls, 0);
    expect(source.readAllCalls, 0);
    await tester.tap(find.byKey(const Key('messages-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('企业端 AI Agent 会话功能开发中'), findsOneWidget);
    expect(source.sends, isEmpty);
  });
  testWidgets('全部已读调用现有IM和系统接口，防重复且成功后回读', (tester) async {
    final source = FakeMessageSource()..readAllGate = Completer<void>();
    await mountMessages(tester, source);
    final read = find.byKey(const Key('messages-read-all'));
    await tester.tap(read);
    await tester.pump();
    expect(tester.widget<TextButton>(read).onPressed, isNull);
    expect(source.readAllCalls, 1);
    source.readAllGate!.complete();
    await tester.pumpAndSettle();
    expect(source.allNoticesCalls, 1);
    expect(source.notices.single.isRead, isTrue);
    expect(source.sessions.single.unread, 0);
    expect(find.text('消息已全部标为已读'), findsOneWidget);
  });
  testWidgets('部分全部已读失败不得假报成功，刷新后保留真实未读状态', (tester) async {
    final source = FakeMessageSource()..readAllFail = true;
    await mountMessages(tester, source);
    await tester.tap(find.byKey(const Key('messages-read-all')));
    await tester.pumpAndSettle();
    expect(find.text('合成通知已读失败'), findsOneWidget);
    expect(find.text('消息已全部标为已读'), findsNothing);
    expect(source.sessions.single.unread, 0);
    expect(source.notices.single.isRead, isFalse);
  });
  testWidgets('接口失败显示错误并重试，空会话不造假，通知失败不清空会话', (tester) async {
    final source = FakeMessageSource()..notificationFail = true;
    await mountMessages(tester, source);
    expect(find.textContaining('合成通知失败'), findsOneWidget);
    expect(find.text('合成候选人'), findsOneWidget);
    source.notificationFail = false;
    source.sessions = [];
    source.notices = [];
    await tester.tap(find.text('重试加载消息'));
    await tester.pumpAndSettle();
    expect(find.text('暂无消息'), findsOneWidget);
  });
  testWidgets('打开会话读取真实历史后标为已读，快捷回复填入不自动发送', (tester) async {
    final source = FakeMessageSource();
    await mountMessages(tester, source);
    await tester.tap(find.byKey(const ValueKey('message-session-8')));
    await tester.pumpAndSettle();
    expect(find.text('真实接口合成消息'), findsOneWidget);
    expect(source.readCalls, 1);
    await tester.tap(find.text('合成快捷回复'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('chat-input')))
          .controller!
          .text,
      '合成快捷回复',
    );
    expect(source.sends, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(source.sessions.single.unread, 0);
  });
  testWidgets('发送成功才清空输入、回读服务器记录，没有模拟自动回复', (tester) async {
    final source = FakeMessageSource()..sendGate = Completer<void>();
    await mountMessages(tester, source, chat: true);
    await tester.enterText(find.byKey(const Key('chat-input')), '合成发送消息');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();
    expect(source.sends, ['合成发送消息']);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('chat-send'))).onPressed,
      isNull,
    );
    expect(source.messages, hasLength(1));
    source.sendGate!.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('chat-input')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.text('合成发送消息'), findsOneWidget);
    expect(source.messages, hasLength(2));
    await tester.pump(const Duration(seconds: 2));
    expect(source.messages, hasLength(2));
  });
  testWidgets('历史加载失败不标为已读，发送业务失败保留输入且可重试', (tester) async {
    final source = FakeMessageSource()..historyFail = true;
    await mountMessages(tester, source, chat: true);
    expect(source.readCalls, 0);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('chat-send'))).onPressed,
      isNull,
    );
    source.historyFail = false;
    await tester.tap(find.byKey(const Key('chat-refresh')));
    await tester.pumpAndSettle();
    source.sendFailure = const ApiException('合成发送拒绝', code: 500);
    await tester.enterText(find.byKey(const Key('chat-input')), '保留的消息');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(find.text('合成发送拒绝'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('chat-input')))
          .controller!
          .text,
      '保留的消息',
    );
    expect(source.messages, hasLength(1));
  });
  testWidgets('发送网络结果不确定禁用重发，必须刷新核对后继续', (tester) async {
    final source = FakeMessageSource()
      ..sendFailure = const ApiException('网络异常');
    await mountMessages(tester, source, chat: true);
    await tester.enterText(find.byKey(const Key('chat-input')), '可能已发送');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(find.textContaining('发送结果待核对'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('chat-send'))).onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('chat-verify-result')));
    await tester.pumpAndSettle();
    expect(source.sends, hasLength(1));
    expect(find.byKey(const Key('chat-resume-edit')), findsOneWidget);
  });
  testWidgets('系统通知列表读取并点击后标记该条已读，详情显示实际内容', (tester) async {
    final source = FakeMessageSource();
    await mountMessages(tester, source);
    await tester.tap(find.byKey(const Key('messages-system')));
    await tester.pumpAndSettle();
    expect(find.byType(SystemNotificationsPage), findsOneWidget);
    expect(source.readNotices, isEmpty);
    await tester.tap(find.byKey(const ValueKey('system-message-4')));
    await tester.pumpAndSettle();
    expect(source.readNotices, [4]);
    expect(find.text('合成通知正文4'), findsWidgets);
    expect(source.notices.single.isRead, isTrue);
  });
  testWidgets('聊天定时回读离开页面停止轮询', (tester) async {
    final source = FakeMessageSource();
    await mountMessages(
      tester,
      source,
      chat: true,
      poll: const Duration(seconds: 8),
    );
    final calls = source.historyCalls;
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(source.historyCalls, greaterThan(calls));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 16));
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('消息列表和聊天在 $size 及键盘出现时无溢出', (tester) async {
      final source = FakeMessageSource();
      await mountMessages(tester, source, size: size);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('message-session-8')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height < 500 ? 100 : 220,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
