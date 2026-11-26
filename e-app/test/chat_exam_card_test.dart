import 'package:enterprise_recruiter/features/enterprise/notification/conversation_page.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/models/message_view_data.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'message_center_page_test.dart' show FakeMessageSource, sessionJson;

const examContent =
    '【笔试邀请·Java后端笔试试卷】Java工程师，作答时间 2026-11-26 10:00 ~ '
    '2026-11-26 11:00，试卷时长 60 分钟。请点击链接进入：'
    'https://app.local/user/exam?scheduleId=12';

Future<void> mountChat(WidgetTester tester, FakeMessageSource source) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ChatPage(
        session: sessionJson(),
        source: source,
        pollInterval: Duration.zero,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('笔试通知显示邀请卡片并隐藏原始链接', (tester) async {
    final source = FakeMessageSource();
    source.messages = [
      ConversationMessage.fromJson({
        'messageId': 1,
        'type': 5,
        'content': examContent,
        'isMine': true,
        'sendTime': '2026-11-26 09:30',
      }),
      ConversationMessage.fromJson({
        'messageId': 2,
        'type': 5,
        'content': examContent,
        'isMine': false,
        'sendTime': '2026-11-26 09:31',
      }),
      ConversationMessage.fromJson({
        'messageId': 3,
        'type': 1,
        'content': '普通聊天内容',
        'isMine': false,
        'sendTime': '2026-11-26 09:32',
      }),
    ];
    await mountChat(tester, source);
    expect(find.byKey(const ValueKey('chat-exam-card-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-exam-card-2')), findsOneWidget);
    expect(find.text('笔试邀请'), findsNWidgets(2));
    expect(find.text('Java后端笔试试卷'), findsNWidgets(2));
    expect(find.textContaining('请点击链接进入'), findsNothing);
    expect(find.textContaining('scheduleId'), findsNothing);
    expect(find.text('已发送 · 求职者可点击进入考试'), findsOneWidget);
    expect(find.text('查看安排 · 进入考试'), findsOneWidget);
    expect(find.text('普通聊天内容'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
