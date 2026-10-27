import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';
import 'package:intelligent_interviewer/features/jobs/data/job_api.dart';
import 'package:intelligent_interviewer/features/jobs/data/job_favorite_api.dart';
import 'package:intelligent_interviewer/features/messages/domain/app_message.dart';
import 'package:intelligent_interviewer/features/messages/domain/shared_job_card.dart';
import 'package:intelligent_interviewer/features/messages/presentation/shared_job_detail_screen.dart';
import 'package:intelligent_interviewer/screens/job_detail_screen.dart';
import 'package:intelligent_interviewer/theme/app_theme.dart';
import 'package:intelligent_interviewer/screens/hr_chat_screen.dart';
import 'package:intelligent_interviewer/features/messages/data/message_api.dart';
import 'package:intelligent_interviewer/features/messages/presentation/shared_job_card_view.dart';

const session = AuthSession(
  token: 'synthetic-session',
  userId: 101,
  userName: 'synthetic',
  nickName: '合成求职者',
);

class JobClient extends ApiClient {
  final gets = <String>[], posts = <String>[];
  Object? applyError;
  Map<String, dynamic> detail = {
    'id': 7,
    'title': '求职者实时岗位',
    'companyName': '合成企业',
    'companyId': 1,
    'workCity': '杭州',
    'salaryMin': 22000,
    'salaryMax': 33000,
    'experienceRequired': '3年',
    'educationRequired': 3,
    'statusCode': 1,
    'appliedFlag': 0,
    'responsibilities': ['合成岗位职责'],
    'requirements': ['合成任职要求'],
    'skills': ['Dart'],
  };
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    String? token,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    gets.add(path);
    expect(token, 'synthetic-session');
    return {
      'code': 200,
      'data': path.contains('favorite') ? {'favorited': false} : detail,
    };
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    String? token,
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    posts.add(path);
    expect(token, 'synthetic-session');
    if (applyError != null) throw applyError!;
    return {'code': 200};
  }
}

Future<void> mount(WidgetTester tester, JobClient client) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: SharedJobDetailScreen(
        positionId: 7,
        session: session,
        api: JobApi(client),
        favoriteApi: JobFavoriteApi(client),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class CardMessages extends MessageApi {
  CardMessages(super.client);
  @override
  Future<List<ChatMessage>> fetchHrChat(String token, int sessionId) async => [
    ChatMessage(
      messageId: 71,
      senderId: 9,
      content: jsonEncode({
        'kind': 'job_card',
        'version': 1,
        'positionId': 7,
        'title': '企业发送时快照',
        'company': '合成企业',
      }),
      mine: false,
      createdAt: DateTime(2026, 10, 27),
      type: 6,
    ),
  ];
}

void main() {
  test('卡片ID与协议校验，普通JSON不被识别为岗位且不信任企业专用路由', () {
    final content = jsonEncode({
      'kind': 'job_card',
      'version': 1,
      'positionId': 7,
      'title': '发送时快照',
      'salaryMin': 20000,
      'salaryMax': 30000,
    });
    expect(SharedJobCard.parse(6, content)?.positionId, 7);
    expect(SharedJobCard.parse(1, content), isNull);
    expect(
      ChatMessage.fromJson({'type': 6, 'content': content}).jobCard?.title,
      '发送时快照',
    );
    expect(SharedJobCard.parse(6, 'invalid'), isNull);
  });
  test('点击详情读取C-APP岗位数据，重新对齐最新薪资和本人投递状态', () async {
    final client = JobClient();
    addTearDown(client.close);
    final job = await JobApi(client).fetchSharedJob('synthetic-session', 7);
    expect(client.gets, ['/agent/v1/jobs/7']);
    expect(job.title, '求职者实时岗位');
    expect(job.salaryMin, 22000);
    expect(job.description, contains('合成岗位职责'));
    expect(job.applied, isFalse);
    client.detail['appliedFlag'] = 1;
    expect(
      (await JobApi(client).fetchSharedJob('synthetic-session', 7)).applied,
      isTrue,
    );
    client.detail['id'] = 99;
    await expectLater(
      JobApi(client).fetchSharedJob('synthetic-session', 7),
      throwsA(isA<ApiException>()),
    );
  });
  testWidgets('求职者聊天点击岗位卡片进入本端详情，并读取最新岗位信息', (tester) async {
    final client = JobClient();
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HrChatScreen(
          session: session,
          conversation: AppMessage(
            sourceId: 8,
            category: AppMessageCategory.hr,
            title: '合成招聘者',
            content: '',
            occurredAt: DateTime(2026),
            unreadCount: 1,
          ),
          messageApi: CardMessages(client),
          sharedJobApi: JobApi(client),
          pollInterval: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SharedJobCardView), findsOneWidget);
    await tester.tap(find.text('查看岗位 · 前往投递'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byType(SharedJobDetailScreen), findsOneWidget);
    expect(find.byType(JobDetailScreen), findsOneWidget);
    expect(
      tester.widget<JobDetailScreen>(find.byType(JobDetailScreen)).job.title,
      '求职者实时岗位',
    );
    expect(client.gets, contains('/agent/v1/jobs/7'));
    expect(client.posts, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('卡片详情复用求职者JobDetailScreen，确认后调用本人投递接口', (tester) async {
    final client = JobClient();
    addTearDown(client.close);
    await mount(tester, client);
    expect(find.byType(JobDetailScreen), findsOneWidget);
    expect(find.text('求职者实时岗位'), findsWidgets);
    await tester.tap(find.text('立即投递'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(client.posts, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, '确认投递'));
    await tester.pumpAndSettle();
    expect(client.posts, ['/app/jobs/7/apply']);
    expect(find.text('已投递'), findsOneWidget);
    expect(client.gets.every((path) => !path.contains('/enterprise/')), isTrue);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('取消投递不提交，停招或已有投递时禁止再次投递', (tester) async {
    final client = JobClient();
    addTearDown(client.close);
    await mount(tester, client);
    await tester.tap(find.text('立即投递'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('暂不投递'));
    await tester.pumpAndSettle();
    expect(client.posts, isEmpty);
    await tester.pumpWidget(const SizedBox());
    client.detail['statusCode'] = 2;
    await mount(tester, client);
    expect(find.text('暂不可投递'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
    client.detail['statusCode'] = 1;
    client.detail['appliedFlag'] = 1;
    await mount(tester, client);
    expect(find.text('已投递'), findsOneWidget);
    expect(client.posts, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('投递超时结果不明时禁止重发，不伪造成功', (tester) async {
    final client = JobClient()
      ..applyError = const ApiException('synthetic timeout');
    addTearDown(client.close);
    await mount(tester, client);
    await tester.tap(find.text('立即投递'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(FilledButton, '确认投递'));
    await tester.pumpAndSettle();
    expect(find.textContaining('投递结果待核对'), findsOneWidget);
    expect(client.posts.length, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
