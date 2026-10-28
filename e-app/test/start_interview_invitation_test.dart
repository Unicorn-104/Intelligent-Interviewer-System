import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/dashboard/home_models.dart';
import 'package:enterprise_recruiter/features/enterprise/interview/start_interview_invitation.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/conversation_page.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/models/message_view_data.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'message_center_page_test.dart' show FakeMessageSource;

Map<String, dynamic> interviewRow({bool withoutCandidateUser = false}) => {
  'appointmentId': 7,
  'positionId': 100,
  'candidateId': 200,
  'candidateName': '若依',
  'positionTitle': '示例岗位',
  'stageId': 31,
  'stageType': 2,
  'stageName': 'AI技术面试',
  'interviewerId': 9,
  if (!withoutCandidateUser) 'candidateUserId': 12,
  'startTime': '2026-10-28 20:00',
  'endTime': '2026-10-28 20:30',
  'status': 1,
};

HomeInterview interview(Map<String, dynamic> raw) => HomeInterview(
  raw: raw,
  startTime: DateTime.utc(2026, 10, 28, 12),
  status: 1,
);

const expectedInvite =
    '【面试邀请·AI技术面试·AI+单面试官】示例企业 示例岗位 视频面试，'
    '请点击链接进入：http://localhost:5180/conference-join?token=t123';

class InviteSource extends FakeMessageSource {
  int? existingSession;
  Object? findFailure, newFailure;
  final newConversations = <(int, String)>[];
  @override
  Future<int?> findPeerSession(int peerId) async {
    if (findFailure != null) throw findFailure!;
    return existingSession;
  }

  @override
  Future<int> startPeerConversation(int peerId, String content) async {
    if (newFailure != null) throw newFailure!;
    newConversations.add((peerId, content));
    messages = [
      ...messages,
      ConversationMessage.fromJson({
        'messageId': messages.length + 1,
        'type': 1,
        'content': content,
        'isMine': true,
        'sendTime': '2026-10-28 20:00',
      }),
    ];
    return 55;
  }
}

class InviteHarness {
  InviteHarness({this.linkFailure, this.linkResult = const {}});
  final Object? linkFailure;
  final Map<String, dynamic> linkResult;
  final linkCalls = <Map<String, Object?>>[];

  Future<Map<String, dynamic>> createLink({
    required int peerUserId,
    required int positionId,
    int? stageId,
    int? durationMinutes,
    int? mode,
    List<int>? interviewerIds,
  }) async {
    linkCalls.add({
      'peerUserId': peerUserId,
      'positionId': positionId,
      'stageId': stageId,
      'durationMinutes': durationMinutes,
      'mode': mode,
      'interviewerIds': interviewerIds,
    });
    if (linkFailure != null) throw linkFailure!;
    return {
      'token': 't123',
      'mode': 2,
      'companyName': '示例企业',
      'positionTitle': '示例岗位',
      ...linkResult,
    };
  }
}

Future<void> mountInvite(
  WidgetTester tester,
  InviteSource source,
  InviteHarness harness, {
  Map<String, dynamic>? raw,
}) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => startInterviewInvitation(
                context,
                interview(raw ?? interviewRow()),
                source: source,
                createLink: harness.createLink,
              ),
              child: const Text('开始面试'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('开始面试'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('已有会话时按PC格式生成链接并发送邀请，随后打开会话', (tester) async {
    final source = InviteSource()..existingSession = 8;
    final harness = InviteHarness();
    await mountInvite(tester, source, harness);
    expect(harness.linkCalls.single, {
      'peerUserId': 12,
      'positionId': 100,
      'stageId': 31,
      'durationMinutes': 30,
      'mode': 2,
      'interviewerIds': [9],
    });
    expect(source.sends, [expectedInvite]);
    expect(source.newConversations, isEmpty);
    final page = tester.widget<ChatPage>(find.byType(ChatPage));
    expect(page.session['sessionId'], 8);
    expect(page.session['peerId'], 12);
    expect(page.session['peerName'], '若依');
    expect(
      find.byKey(const ValueKey('chat-enter-interview-2')),
      findsOneWidget,
    );
    expect(find.textContaining('conference-join'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('没有会话时新建会话发送邀请', (tester) async {
    final source = InviteSource();
    final harness = InviteHarness();
    await mountInvite(tester, source, harness);
    expect(harness.linkCalls.single['mode'], 2);
    expect(source.sends, isEmpty);
    expect(source.newConversations, [(12, expectedInvite)]);
    final page = tester.widget<ChatPage>(find.byType(ChatPage));
    expect(page.session['sessionId'], 55);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('面试信息不完整时不调接口直接提示', (tester) async {
    final source = InviteSource();
    final harness = InviteHarness();
    await mountInvite(
      tester,
      source,
      harness,
      raw: interviewRow(withoutCandidateUser: true),
    );
    expect(harness.linkCalls, isEmpty);
    expect(source.sends, isEmpty);
    expect(find.text('面试信息不完整，无法发起面试邀请'), findsOneWidget);
    expect(find.byType(ChatPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('编程实操纯AI面试无需面试官，接口传空面试官列表', (tester) async {
    final source = InviteSource();
    final harness = InviteHarness();
    await mountInvite(
      tester,
      source,
      harness,
      raw: {...interviewRow(), 'stageType': 4, 'stageName': '编程实操'}
        ..remove('interviewerId'),
    );
    expect(harness.linkCalls.single['mode'], 1);
    expect(harness.linkCalls.single['interviewerIds'], isEmpty);
    expect(find.byType(ChatPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('人工面试未指派面试官时提示且不调接口', (tester) async {
    final source = InviteSource();
    final harness = InviteHarness();
    await mountInvite(
      tester,
      source,
      harness,
      raw: {...interviewRow(), 'stageType': 3, 'stageName': 'HR综合面试'}
        ..remove('interviewerId'),
    );
    expect(harness.linkCalls, isEmpty);
    expect(find.text('该面试未指派面试官，无法发起面试'), findsOneWidget);
    expect(find.byType(ChatPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('会议链接生成失败时提示原因且不发送消息', (tester) async {
    final source = InviteSource()..existingSession = 8;
    final harness = InviteHarness(
      linkFailure: const ApiException('后端繁忙，请稍后重试'),
    );
    await mountInvite(tester, source, harness);
    expect(harness.linkCalls.length, 1);
    expect(source.sends, isEmpty);
    expect(find.text('发起面试失败：后端繁忙，请稍后重试'), findsOneWidget);
    expect(find.byType(ChatPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('链接缺少令牌时不发送并提示重试', (tester) async {
    final source = InviteSource()..existingSession = 8;
    final harness = InviteHarness(linkResult: const {'token': ''});
    await mountInvite(tester, source, harness);
    expect(source.sends, isEmpty);
    expect(find.text('会议链接生成异常，请稍后重试'), findsOneWidget);
    expect(find.byType(ChatPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('发送邀请失败时提示原因', (tester) async {
    final source = InviteSource()..findFailure = const ApiException('聊天服务不可用');
    final harness = InviteHarness();
    await mountInvite(tester, source, harness);
    expect(harness.linkCalls.length, 1);
    expect(source.sends, isEmpty);
    expect(find.text('面试邀请发送失败：聊天服务不可用'), findsOneWidget);
    expect(find.byType(ChatPage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
