import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/conversation_page.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/models/message_view_data.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'message_center_page_test.dart' show FakeMessageSource, sessionJson;

const inviteBody = '【面试邀请·AI技术面试·AI+单面试官】示例企业 示例岗位 视频面试，请点击链接进入';
const inviteUrl = 'http://localhost:5180/conference-join?token=token123';

Map<String, dynamic> sessionContext() => {
  'sessionId': 77,
  'appointmentId': 88,
  'candidateUserId': 104,
  'candidateName': '示例候选人',
  'positionTitle': '示例岗位',
  'interviewerName': '示例面试官',
  'appointmentStartAt': '2026-10-28 20:00',
  'appointmentEndAt': '2026-10-28 20:30',
  'status': 1,
  'mode': 2,
  'role': 'HR',
};

class InviteChatSource extends FakeMessageSource {
  Map<String, dynamic> currentSession = sessionContext();
  Object? sessionFailure;
  int sessionCalls = 0;
}

/// 记录「进入面试」收到的场次上下文，替代真实音视频会议室。
class FakeConferenceRoom extends StatelessWidget {
  const FakeConferenceRoom({super.key, required this.session});

  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Text('视频会议室#${session['sessionId']}'));
}

Future<void> mountChat(WidgetTester tester, InviteChatSource source) async {
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
        loadCurrentSession: () async {
          source.sessionCalls++;
          if (source.sessionFailure != null) throw source.sessionFailure!;
          return source.currentSession;
        },
        conferenceRoomBuilder: (session) =>
            FakeConferenceRoom(session: session),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('面试邀请消息显示进入面试按钮并隐藏原始链接，普通消息不受影响', (tester) async {
    final source = InviteChatSource();
    source.messages = [
      ConversationMessage.fromJson({
        'messageId': 1,
        'type': 1,
        'content': '$inviteBody：$inviteUrl',
        'isMine': true,
        'sendTime': '2026-10-28 20:00',
      }),
      ConversationMessage.fromJson({
        'messageId': 2,
        'type': 1,
        'content': '普通聊天内容',
        'isMine': false,
        'sendTime': '2026-10-28 20:01',
      }),
      ConversationMessage.fromJson({
        'messageId': 3,
        'type': 1,
        'content': '$inviteBody：/conference-join?token=relative123',
        'isMine': true,
        'sendTime': '2026-10-28 20:02',
      }),
    ];
    await mountChat(tester, source);
    expect(
      find.byKey(const ValueKey('chat-enter-interview-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chat-enter-interview-3')),
      findsOneWidget,
    );
    expect(find.textContaining('conference-join'), findsNothing);
    expect(find.textContaining('token123'), findsNothing);
    expect(find.text(inviteBody), findsNWidgets(2));
    expect(find.text('普通聊天内容'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-enter-interview-2')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('点击进入面试查询当前场次并直接打开视频会议室', (tester) async {
    final source = InviteChatSource();
    source.messages = [
      ConversationMessage.fromJson({
        'messageId': 1,
        'type': 1,
        'content': '$inviteBody：$inviteUrl',
        'isMine': true,
        'sendTime': '2026-10-28 20:00',
      }),
    ];
    await mountChat(tester, source);
    await tester.tap(find.byKey(const ValueKey('chat-enter-interview-1')));
    await tester.pumpAndSettle();
    expect(source.sessionCalls, 1);
    final page = tester.widget<FakeConferenceRoom>(
      find.byType(FakeConferenceRoom),
    );
    expect(page.session['sessionId'], 77);
    expect(page.session['candidateUserId'], 104);
    expect(page.session['role'], 'HR');
    expect(find.text('视频会议室#77'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('当前没有待开始或进行中的面试时提示去面试安排查看', (tester) async {
    final source = InviteChatSource()..currentSession = {};
    source.messages = [
      ConversationMessage.fromJson({
        'messageId': 1,
        'type': 1,
        'content': '$inviteBody：$inviteUrl',
        'isMine': true,
        'sendTime': '2026-10-28 20:00',
      }),
    ];
    await mountChat(tester, source);
    await tester.tap(find.byKey(const ValueKey('chat-enter-interview-1')));
    await tester.pumpAndSettle();
    expect(source.sessionCalls, 1);
    expect(find.text('当前没有待开始或进行中的面试，可在面试安排中查看'), findsOneWidget);
    expect(find.byType(FakeConferenceRoom), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('查询会话失败时提示原因且不打开会议室', (tester) async {
    final source = InviteChatSource()
      ..sessionFailure = const ApiException('合成查询失败');
    source.messages = [
      ConversationMessage.fromJson({
        'messageId': 1,
        'type': 1,
        'content': '$inviteBody：$inviteUrl',
        'isMine': true,
        'sendTime': '2026-10-28 20:00',
      }),
    ];
    await mountChat(tester, source);
    await tester.tap(find.byKey(const ValueKey('chat-enter-interview-1')));
    await tester.pumpAndSettle();
    expect(source.sessionCalls, 1);
    expect(find.text('查询面试状态失败：合成查询失败'), findsOneWidget);
    expect(find.byType(FakeConferenceRoom), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
