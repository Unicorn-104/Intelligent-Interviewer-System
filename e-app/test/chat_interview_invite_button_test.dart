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
  Map<String, dynamic> inviteSession = sessionContext();
  Object? inviteFailure;
  int inviteCalls = 0;
  String? lastToken;
}

/// 记录「进入面试」收到的场次上下文，替代真实音视频会议室。
class FakeConferenceRoom extends StatelessWidget {
  const FakeConferenceRoom({super.key, required this.session});

  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: const BackButton()),
    body: Text('视频会议室#${session['sessionId']}'),
  );
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
        joinInterviewInvite: (token) async {
          source.inviteCalls++;
          source.lastToken = token;
          if (source.inviteFailure != null) throw source.inviteFailure!;
          return source.inviteSession;
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
        'isMine': false,
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
        'isMine': false,
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

  testWidgets('点击进入面试按邀请 token 打开对应会议室', (tester) async {
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
    expect(source.inviteCalls, 1);
    expect(source.lastToken, 'token123');
    final page = tester.widget<FakeConferenceRoom>(
      find.byType(FakeConferenceRoom),
    );
    expect(page.session['sessionId'], 77);
    expect(page.session['candidateUserId'], 104);
    expect(page.session['role'], 'HR');
    expect(find.text('视频会议室#77'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('不同邀请 token 使用各自返回的场次', (tester) async {
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
        'messageId': 3,
        'type': 1,
        'content': '$inviteBody：/conference-join?token=relative123',
        'isMine': true,
        'sendTime': '2026-10-28 20:02',
      }),
    ];
    await mountChat(tester, source);
    await tester.tap(find.byKey(const ValueKey('chat-enter-interview-1')));
    await tester.pumpAndSettle();
    expect(source.lastToken, 'token123');
    expect(find.text('视频会议室#77'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    source.inviteSession = sessionContext()
      ..['sessionId'] = 157
      ..['candidateName'] = '若依'
      ..['positionTitle'] = 'a';
    await tester.tap(find.byKey(const ValueKey('chat-enter-interview-3')));
    await tester.pumpAndSettle();
    expect(source.lastToken, 'relative123');
    expect(find.text('视频会议室#157'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('历史面试邀请卡片不再展示无AI纯人工后缀', (tester) async {
    final source = InviteChatSource();
    source.messages = [
      ConversationMessage.fromJson({
        'messageId': 1,
        'type': 1,
        'content':
            '【面试邀请·HR 综合面试·无AI纯人工】示例企业 示例岗位 视频面试，'
            '请点击链接进入：$inviteUrl',
        'isMine': true,
        'sendTime': '2026-11-28 20:00',
      }),
    ];
    await mountChat(tester, source);
    expect(find.text('HR 综合面试'), findsOneWidget);
    expect(find.textContaining('无AI纯人工'), findsNothing);
    expect(find.textContaining('无 AI'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('面试已结束时提示本场面试已结束', (tester) async {
    final source = InviteChatSource()..inviteSession = {};
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
    expect(source.inviteCalls, 1);
    expect(source.lastToken, 'token123');
    expect(find.text('本场面试已结束'), findsOneWidget);
    expect(find.byType(FakeConferenceRoom), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('邀请 token 兑换失败时提示原因且不打开会议室', (tester) async {
    final source = InviteChatSource()
      ..inviteFailure = const ApiException('合成兑换失败');
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
    expect(source.inviteCalls, 1);
    expect(source.lastToken, 'token123');
    expect(find.text('进入面试失败，请重试'), findsOneWidget);
    expect(find.byType(FakeConferenceRoom), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
