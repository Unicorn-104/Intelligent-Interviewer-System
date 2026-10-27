import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/data/message_data_source.dart';

import 'support/jd_http_fixture.dart';

import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/models/message_view_data.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/models/shared_job_card.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/widgets/share_job_sheet.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/widgets/shared_job_card_view.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/conversation_page.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';

import 'message_center_page_test.dart' show FakeMessageSource, sessionJson;

Map<String, dynamic> job([int id = 7]) => {
  'positionId': id,
  'title': '合成岗位$id',
  'company': '合成企业',
  'city': '杭州',
  'salaryMin': 20000,
  'salaryMax': 30000,
  'education': 3,
};

class JobSource extends FakeMessageSource {
  final reads = <(String?, int)>[];
  final cards = <(int?, int, int, String)>[];
  Object? jobError, cardError;
  List<Map<String, dynamic>> jobs = [job()];
  @override
  Future<List<Map<String, dynamic>>> loadShareableJobs({
    String? keyword,
    int page = 1,
  }) async {
    reads.add((keyword, page));
    if (jobError != null) throw jobError!;
    return jobs;
  }

  @override
  Future<int> sendJobCard({
    int? sessionId,
    required int peerId,
    required int positionId,
    required String requestId,
  }) async {
    cards.add((sessionId, peerId, positionId, requestId));
    if (cardError != null) throw cardError!;
    messages = [
      ...messages,
      ConversationMessage.fromJson({
        'messageId': 71,
        'type': 6,
        'isMine': true,
        'content': jsonEncode({
          ...job(positionId),
          'kind': 'job_card',
          'version': 1,
          'requestId': requestId,
        }),
      }),
    ];
    return 8;
  }
}

Future<void> mount(
  WidgetTester tester,
  JobSource source, {
  Size size = const Size(430, 900),
}) async {
  tester.view.physicalSize = size;
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

Future<void> openPicker(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('chat-more-toggle')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('chat-send-job')));
  await tester.pumpAndSettle();
}

void main() {
  test('岗位发送协议只传真实岗位与会话标识，不传自拟卡片内容', () async {
    FlutterSecureStorage.setMockInitialValues({
      'enterprise_access_token': 'synthetic',
    });
    final http = JdHttpFixture();
    addTearDown(http.close);
    final source = MessageDataSource(client: http.client);
    const request = '1234567890abcdef12345678';
    http.adapter.body = {
      'code': 200,
      'data': {'sessionId': 8, 'messageId': 71, 'requestId': request},
    };
    expect(
      await source.sendJobCard(
        sessionId: 8,
        peerId: 12,
        positionId: 7,
        requestId: request,
      ),
      8,
    );
    expect(http.adapter.requests.single.path, '/enterprise/chat/job-cards');
    expect(http.adapter.requests.single.data, {
      'sessionId': 8,
      'peerId': 12,
      'positionId': 7,
      'requestId': request,
    });
    http.adapter.body = {
      'code': 200,
      'data': {'sessionId': 99, 'messageId': 71, 'requestId': request},
    };
    await expectLater(
      source.sendJobCard(
        sessionId: 8,
        peerId: 12,
        positionId: 7,
        requestId: request,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('岗位卡协议独立于普通JSON文本，坏卡片不抛异常', () {
    final text = jsonEncode({...job(), 'kind': 'job_card', 'version': 1});
    expect(SharedJobCard.parse(6, text)?.positionId, 7);
    expect(SharedJobCard.parse(1, text), isNull);
    for (final text in [
      'bad',
      '[]',
      '{"kind":"job_card","version":9}',
      '{"kind":"job_card","version":1,"positionId":0,"title":"x"}',
    ]) {
      expect(SharedJobCard.parse(6, text), isNull);
    }
  });
  testWidgets('工具栏含发送岗位，选择确认后仅发一张真实卡片', (tester) async {
    final source = JobSource();
    await mount(tester, source);
    await openPicker(tester);
    expect(find.byType(ShareJobSheet), findsOneWidget);
    expect(source.cards, isEmpty);
    await tester.tap(find.text('合成岗位7'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认发送'));
    await tester.pumpAndSettle();
    expect(source.cards.length, 1);
    expect(source.cards.single.$1, 8);
    expect(source.cards.single.$2, 12);
    expect(source.cards.single.$3, 7);
    expect(source.cards.single.$4, matches(RegExp(r'^[0-9a-f]{24}$')));
    expect(find.byType(SharedJobCardView), findsOneWidget);
    expect(source.sends, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('取消确认不发送，停招或无岗位显示真实空态，搜索显式读取', (tester) async {
    final source = JobSource();
    await mount(tester, source);
    await openPicker(tester);
    await tester.tap(find.text('合成岗位7'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(source.cards, isEmpty);
    source.jobs = [];
    await tester.enterText(find.byType(TextField).last, '不存在');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('暂无可发送的在招岗位'), findsOneWidget);
    expect(source.cards, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('发送结果不确定保留核对提示且不自动重发', (tester) async {
    final source = JobSource()
      ..cardError = const ApiException('synthetic timeout');
    await mount(tester, source);
    await openPicker(tester);
    await tester.tap(find.text('合成岗位7'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认发送'));
    await tester.pumpAndSettle();
    expect(source.cards.length, 1);
    expect(find.textContaining('岗位卡片发送结果待核对'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(source.cards.length, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('读取失败可重试，320dp大字卡片面板没有溢出', (tester) async {
    final source = JobSource()..jobError = const ApiException('合成岗位读取失败');
    await mount(tester, source, size: const Size(320, 850));
    await openPicker(tester);
    expect(find.text('合成岗位读取失败'), findsOneWidget);
    source.jobError = null;
    await tester.tap(find.text('重新读取岗位'));
    await tester.pumpAndSettle();
    expect(find.text('合成岗位7'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
