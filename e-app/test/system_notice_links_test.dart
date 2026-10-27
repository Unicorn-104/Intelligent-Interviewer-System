import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/data/message_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/models/message_view_data.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/system_notifications_page.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/system_notice_destination.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/widgets/system_notice_highlights.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/talent_detail_page.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/job_interviews_page.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/data/talent_detail_data_source.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';

import 'message_center_page_test.dart' show FakeMessageSource;
import 'support/talent_detail_fixture.dart';
import 'support/jd_http_fixture.dart';

Map<String, dynamic> target(String kind) => {
  'messageId': 21,
  'kind': kind,
  'candidateId': 11,
  'positionId': 7,
  'positionTitle': '合成岗位',
  'candidateName': '合成候选人',
  if (kind == 'candidate') 'applicationId': 31,
  if (kind == 'interview') ...{
    'appointmentId': 41,
    'status': 1,
    'interviewerId': 9,
    'startTime': '2099-01-02 14:00:00',
    'endTime': '2099-01-02 14:45:00',
  },
  if (kind == 'report') ...{
    'evaluationId': 61,
    'sessionId': 51,
    'overallScore': 86,
    'summary': '合成真实报告内容',
    'dimensionScores': '{"技术":86}',
  },
};

class LinkSource extends FakeMessageSource {
  LinkSource(String kind) {
    result = target(kind);
    notices = [
      SystemMessage.fromJson({
        'messageId': 21,
        'title': '合成业务通知',
        'content': '候选人：合成候选人\n岗位：合成岗位\n面试将于2099-01-02 14:00开始。',
        'createdAt': '2026-10-27 12:00:00',
        'isRead': 0,
        'targetUrl':
            '/enterprise/system-events/${kind == 'candidate'
                ? 'applications/31'
                : kind == 'report'
                ? 'reports/61'
                : 'interviews/41/status/1'}',
      }),
    ];
  }
  late Map<String, dynamic> result;
  Object? failure;
  int resolutions = 0;
  Completer<Map<String, dynamic>>? gate;
  @override
  Future<Map<String, dynamic>> loadNotificationDestination(int id) async {
    resolutions++;
    expect(id, 21);
    if (failure != null) throw failure!;
    return gate?.future ?? result;
  }

  final talent = TalentFakeSource();
  @override
  TalentDetailDataSource get candidateDetailsSource => talent;
}

Future<void> mount(WidgetTester tester, LinkSource source) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: SystemNotificationsPage(source: source),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('关键字段与时间高亮但完整原文和普通说明保持不变', () {
    const text = '候选人：合成候选人\n岗位：合成岗位\n面试将于2099-01-02 14:00开始，状态已确认。';
    final spans = systemNoticeSpans(text).cast<TextSpan>();
    expect(spans.map((s) => s.text).join(), text);
    for (final keyword in ['合成候选人', '合成岗位', '2099-01-02 14:00', '已确认']) {
      final span = spans.singleWhere((s) => s.text == keyword);
      expect(span.style?.color, AppColors.interactive);
      expect(span.style?.fontWeight, FontWeight.w600);
    }
    expect(spans.first.style, isNull);
  });

  test('鉴权通知详情接口按通知ID查询，坏响应不冒充有效业务ID', () async {
    FlutterSecureStorage.setMockInitialValues({
      'enterprise_access_token': 'synthetic',
    });
    final http = JdHttpFixture();
    addTearDown(http.close);
    http.adapter.body = {'code': 200, 'data': target('candidate')};
    final source = MessageDataSource(client: http.client);
    final result = await source.loadNotificationDestination(21);
    expect(result['candidateId'], 11);
    expect(
      http.adapter.requests.single.path,
      '/enterprise/system-notices/21/destination',
    );
    expect(http.adapter.requests.single.method, 'GET');
    http.adapter.body = {
      'code': 200,
      'data': {...target('candidate'), 'messageId': 99},
    };
    await expectLater(
      source.loadNotificationDestination(21),
      throwsA(isA<FormatException>()),
    );
  });

  test('无效类型或缺少业务ID不能导航', () {
    for (final data in [
      <String, dynamic>{},
      {...target('candidate'), 'candidateId': 0},
      {...target('report'), 'kind': 'external'},
    ]) {
      expect(
        () => SystemNoticeDestination(data),
        throwsA(isA<FormatException>()),
      );
    }
  });

  testWidgets('投递通知的查看详情跳到当前投递候选人及对应岗位', (tester) async {
    final source = LinkSource('candidate');
    await mount(tester, source);
    expect(source.resolutions, 0);
    await tester.tap(find.byKey(const ValueKey('system-notice-details-21')));
    await tester.pumpAndSettle();
    final page = tester.widget<TalentDetailPage>(find.byType(TalentDetailPage));
    expect(page.talent['talentId'], 11);
    expect(page.jobContext?.positionId, 7);
    expect(source.readNotices, [21]);
    expect(source.sends, isEmpty);
    expect(source.resolutions, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('面试通知进入具体预约，加载时再次校验原通知而非展示全企业列表', (tester) async {
    final source = LinkSource('interview');
    await mount(tester, source);
    await tester.tap(find.byKey(const ValueKey('system-notice-details-21')));
    await tester.pumpAndSettle();
    expect(find.byType(JobInterviewsPage), findsOneWidget);
    final page = tester.widget<JobInterviewsPage>(
      find.byType(JobInterviewsPage),
    );
    expect(page.positionId, 7);
    expect(source.resolutions, greaterThanOrEqualTo(2));
    expect(find.textContaining('合成候选人'), findsWidgets);
    expect(source.sends, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('报告通知进入服务端真实报告，没有演示内容或生成操作', (tester) async {
    final source = LinkSource('report');
    await mount(tester, source);
    await tester.tap(find.byKey(const ValueKey('system-notice-details-21')));
    await tester.pumpAndSettle();
    expect(find.text('面试报告'), findsOneWidget);
    expect(find.text('合成真实报告内容'), findsOneWidget);
    expect(find.text('演示数据'), findsNothing);
    expect(source.sends, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('删除或权限错误留在通知页，展示错误且不错误标记已读', (tester) async {
    final source = LinkSource('candidate')
      ..failure = const ApiException('关联记录已删除或不属于当前企业', code: 500);
    await mount(tester, source);
    await tester.tap(find.byKey(const ValueKey('system-notice-details-21')));
    await tester.pumpAndSettle();
    expect(find.byType(SystemNotificationsPage), findsOneWidget);
    expect(find.byType(TalentDetailPage), findsNothing);
    expect(find.text('关联记录已删除或不属于当前企业'), findsOneWidget);
    expect(source.readNotices, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('关联读取中防止重复点击且不发业务写请求', (tester) async {
    final source = LinkSource('report')
      ..gate = Completer<Map<String, dynamic>>();
    await mount(tester, source);
    await tester.tap(find.byKey(const ValueKey('system-notice-details-21')));
    await tester.pump();
    expect(source.resolutions, 1);
    source.gate!.complete(target('report'));
    await tester.pumpAndSettle();
    expect(source.resolutions, 1);
    expect(source.sends, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}
