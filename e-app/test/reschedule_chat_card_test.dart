import 'dart:async';
import 'dart:convert';

import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/conversation_page.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/models/message_view_data.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/widgets/reschedule_chat_card.dart';
import 'package:enterprise_recruiter/features/enterprise/schedule/data/reschedule_review_data_source.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'support/jd_http_fixture.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:enterprise_recruiter/features/enterprise/notification/data/message_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/models/chat_context.dart';
import 'package:enterprise_recruiter/features/enterprise/profile/models/profile_view_data.dart';

Map<String, dynamic> sessionJson() => {
  'sessionId': 8,
  'peerId': 12,
  'peerName': '合成候选人',
};

class CardMessageSource extends MessageDataSource {
  List<ConversationMessage> messages = [];
  @override
  Future<List<ConversationMessage>> loadMessages(int id) async => messages;
  @override
  Future<void> readSession(int id) async {}
  @override
  Future<List<ChatQuickReply>> loadQuickReplies() async => [];
  @override
  Future<ChatContext> loadChatContext(Map<String, dynamic> session) async =>
      ChatContext();
  @override
  Future<EnterpriseProfile> loadRecruiterProfile() async =>
      EnterpriseProfile.fromResponse({
        'data': {'userId': 99, 'nickName': '合成招聘者', 'avatar': ''},
      });
}

Map<String, dynamic> requestData({String status = 'pending'}) => {
  'kind': 'interview_reschedule',
  'version': 1,
  'requestId': 31,
  'appointmentId': 44,
  'requesterId': 12,
  'candidateName': '合成候选人',
  'positionName': '合成岗位',
  'originalStartTime': '2099-01-02 09:00:00',
  'originalEndTime': '2099-01-02 09:45:00',
  'newStartTime': '2099-01-03 10:00:00',
  'newEndTime': '2099-01-03 10:45:00',
  'reason': '合成申请原因',
  'status': status,
  'requestedAt': '2026-10-26 09:00:00',
  if (status != 'pending') 'reviewNote': '合成审批说明',
};

class CardReviewSource extends RescheduleReviewDataSource {
  Map<String, dynamic> row = requestData();
  final decisions = <String>[];
  final notes = <String?>[];
  Object? detailError, reviewError;
  Completer<RescheduleRequest>? gate;
  int details = 0;
  @override
  Future<Map<String, dynamic>> detail(int id, {int? candidateUserId}) async {
    details++;
    expect(id, 31);
    expect(candidateUserId, 12);
    if (detailError != null) throw detailError!;
    return row;
  }

  @override
  Future<RescheduleRequest> review(
    int id,
    String decision, {
    String? note,
  }) async {
    decisions.add(decision);
    notes.add(note);
    if (reviewError != null) throw reviewError!;
    if (gate != null) return gate!.future;
    row = requestData(status: decision);
    if (note != null) row['reviewNote'] = note;
    return RescheduleRequest.fromJson(row);
  }
}

Future<void> mountCard(
  WidgetTester tester,
  CardReviewSource source, {
  Map<String, dynamic>? data,
  bool canReview = true,
  VoidCallback? changed,
  double scale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: SingleChildScrollView(
          child: RescheduleChatCard(
            key: const ValueKey('card'),
            data: data ?? requestData(),
            peerUserId: 12,
            canReview: canReview,
            source: source,
            onChanged: changed ?? () {},
          ),
        ),
      ),
    ),
  ),
);

void main() {
  test('聊天审批详情使用登录鉴权和专用GET接口，不接受会话伪造申请人', () async {
    FlutterSecureStorage.setMockInitialValues({
      'enterprise_access_token': 'synthetic-session',
    });
    final http = JdHttpFixture();
    addTearDown(http.close);
    http.adapter.body = {'code': 200, 'data': requestData()};
    final source = RescheduleReviewDataSource(client: http.client);
    final row = await source.detail(31, candidateUserId: 12);
    expect(row['requestId'], 31);
    final request = http.adapter.requests.single;
    expect(request.path, '/enterprise/interview/reschedule-requests/31');
    expect(request.method, 'GET');
    expect(
      request.headers['Authorization'] ?? request.headers['authorization'],
      'Bearer synthetic-session',
    );
    for (final data in [
      {...requestData(), 'requesterId': 999},
      {...requestData(), 'requestId': 999},
    ]) {
      http.adapter.body = {'code': 200, 'data': data};
      await expectLater(
        source.detail(31, candidateUserId: 12),
        throwsA(isA<FormatException>()),
      );
    }
    expect(
      http.adapter.requests.every((request) => request.method == 'GET'),
      isTrue,
    );
  });

  testWidgets('同意申请先校验会话归属，只审批一次并移除按钮', (tester) async {
    final source = CardReviewSource()..gate = Completer<RescheduleRequest>();
    await mountCard(tester, source);
    await tester.tap(find.text('同意'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认同意'));
    await tester.pump();
    await tester.tap(find.text('处理中…'));
    await tester.pump();
    expect(source.decisions, ['approved']);
    expect(source.details, 1);
    source.gate!.complete(
      RescheduleRequest.fromJson(requestData(status: 'approved')),
    );
    await tester.pumpAndSettle();
    expect(find.text('改期申请已同意'), findsOneWidget);
    expect(find.text('同意'), findsNothing);
    expect(find.text('审批说明：合成审批说明'), findsOneWidget);
  });

  testWidgets('拒绝须填写原因，并发送给服务端', (tester) async {
    final source = CardReviewSource();
    await mountCard(tester, source);
    await tester.tap(find.text('拒绝'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认拒绝'));
    await tester.pumpAndSettle();
    expect(find.text('请填写拒绝原因'), findsOneWidget);
    expect(source.decisions, isEmpty);
    await tester.enterText(find.byType(TextField), ' 合成拒绝原因 ');
    await tester.tap(find.text('确认拒绝'));
    await tester.pumpAndSettle();
    expect(source.decisions, ['rejected']);
    expect(source.notes, ['合成拒绝原因']);
    expect(find.text('改期申请已拒绝'), findsOneWidget);
    expect(find.text('审批说明：合成拒绝原因'), findsOneWidget);
  });

  testWidgets('取消和其他招聘者已处理时不提交审批', (tester) async {
    final source = CardReviewSource();
    await mountCard(tester, source);
    await tester.tap(find.text('同意'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(source.decisions, isEmpty);
    source.row = requestData(status: 'rejected');
    await tester.tap(find.text('同意'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认同意'));
    await tester.pumpAndSettle();
    expect(source.decisions, isEmpty);
    expect(find.text('改期申请已拒绝'), findsOneWidget);
  });

  testWidgets('超时不自动重发，核对原申请后显示最终状态', (tester) async {
    final source = CardReviewSource()
      ..reviewError = TimeoutException('synthetic');
    await mountCard(tester, source);
    await tester.tap(find.text('同意'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认同意'));
    await tester.pumpAndSettle();
    expect(source.decisions, ['approved']);
    expect(find.text('核对申请状态'), findsOneWidget);
    expect(find.text('同意'), findsNothing);
    source.row = requestData(status: 'approved');
    await tester.tap(find.text('核对申请状态'));
    await tester.pumpAndSettle();
    expect(source.decisions, ['approved']);
    expect(find.text('改期申请已同意'), findsOneWidget);
  });

  testWidgets('读取失败和明确业务拒绝保留真实错误，不误报审批成功', (tester) async {
    final source = CardReviewSource()
      ..detailError = const ApiException('合成会话归属校验失败', code: 403);
    await mountCard(tester, source);
    await tester.tap(find.text('同意'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认同意'));
    await tester.pumpAndSettle();
    expect(source.decisions, isEmpty);
    expect(find.text('核对申请状态'), findsNothing);
    source.detailError = null;
    source.reviewError = const ApiException('合成面试时间冲突', code: 500);
    await tester.tap(find.text('同意'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认同意'));
    await tester.pumpAndSettle();
    expect(find.text('合成面试时间冲突'), findsOneWidget);
    expect(find.text('核对申请状态'), findsNothing);
    expect(find.text('同意'), findsOneWidget);
  });

  testWidgets('同一卡片刷新为已处理状态后不残留按钮，旧pending快照不回退', (tester) async {
    final source = CardReviewSource();
    await mountCard(tester, source);
    expect(find.text('同意'), findsOneWidget);
    await mountCard(tester, source, data: requestData(status: 'approved'));
    expect(find.text('同意'), findsNothing);
    expect(find.text('改期申请已同意'), findsOneWidget);
    await mountCard(tester, source);
    expect(find.text('同意'), findsNothing);
  });

  testWidgets('企业直接改期卡片显示完整区间且没有审批按钮', (tester) async {
    final source = CardReviewSource();
    await mountCard(
      tester,
      source,
      data: requestData(status: 'changed'),
      canReview: false,
    );
    expect(find.text('企业已调整面试时间'), findsOneWidget);
    expect(find.textContaining('2099-01-03 10:45:00'), findsOneWidget);
    expect(find.text('同意'), findsNothing);
    expect(find.text('拒绝'), findsNothing);
  });

  testWidgets('聊天轮询更新原卡片为已拒绝，320dp大字布局无溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = CardMessageSource();
    ConversationMessage message(String status) => ConversationMessage.fromJson({
      'messageId': 77,
      'type': 5,
      'isMine': false,
      'content': jsonEncode(requestData(status: status)),
      'sendTime': '2026-10-26 09:00',
    });
    source.messages = [message('pending')];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: ChatPage(
          session: sessionJson(),
          source: source,
          pollInterval: const Duration(seconds: 8),
          rescheduleSource: CardReviewSource(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('同意'), findsOneWidget);
    source.messages = [message('rejected')];
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(find.text('同意'), findsNothing);
    expect(find.text('改期申请已拒绝'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
