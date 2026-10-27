import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/interviews/data/interview_api.dart';
import 'package:intelligent_interviewer/features/interviews/domain/interview_schedule.dart';
import 'package:intelligent_interviewer/features/interviews/presentation/reschedule_request_action.dart';
import 'package:intelligent_interviewer/theme/app_theme.dart';

Map<String, dynamic> record({
  int appointmentId = 44,
  int requestId = 31,
  String status = 'pending',
}) => {
  'requestId': requestId,
  'appointmentId': appointmentId,
  'status': status,
};

class RequestClient extends ApiClient {
  final paths = <String>[];
  final pages = <int, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    String? token,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    paths.add(path);
    expect(token, 'synthetic-session');
    return pages[int.parse(Uri.parse(path).queryParameters['pageNum']!)]!;
  }
}

class RequestApi extends InterviewApi {
  RequestApi(super.client);
  Map<String, dynamic>? row;
  Object? readError, submitError;
  Completer<Map<String, dynamic>?>? readGate;
  int sends = 0;
  String? reason;
  @override
  Future<Map<String, dynamic>?> findOwnReschedule(
    String token,
    int appointmentId,
  ) async {
    if (readError != null) throw readError!;
    if (readGate != null) return readGate!.future;
    return row;
  }

  @override
  Future<Map<String, dynamic>> submitReschedule(
    String token,
    int appointmentId,
    DateTime start,
    String reason,
  ) async {
    sends++;
    this.reason = reason;
    if (submitError != null) throw submitError!;
    row = record();
    return row!;
  }
}

Future<void> mount(WidgetTester tester, RequestApi api) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: RescheduleRequestAction(
        api: api,
        token: 'synthetic-session',
        appointment: const InterviewSchedule(
          appointmentId: 44,
          positionTitle: '合成岗位',
          companyName: '合成企业',
          statusText: '待面试',
          startAt: '2099-01-02 09:00:00',
          endAt: '2099-01-02 09:45:00',
        ),
      ),
    ),
  ),
);

void main() {
  test('申请记录超过100条时继续分页，不把旧预约的待处理申请误判为不存在', () async {
    final client = RequestClient();
    addTearDown(client.close);
    client.pages[1] = {
      'rows': List.generate(
        100,
        (i) => record(appointmentId: 100 + i, requestId: 100 + i),
      ),
      'total': 101,
    };
    client.pages[2] = {
      'rows': [record()],
      'total': 101,
    };
    final result = await InterviewApi(
      client,
    ).findOwnReschedule('synthetic-session', 44);
    expect(result?['requestId'], 31);
    expect(client.paths.length, 2);
    expect(Uri.parse(client.paths.last).queryParameters['pageNum'], '2');
  });

  test('损坏分页与空中间页不能被当作无申请', () async {
    final client = RequestClient();
    addTearDown(client.close);
    for (final page in [
      {'rows': <Object>[], 'total': 200},
      {
        'rows': [
          {'appointmentId': 44},
        ],
        'total': 1,
      },
      {
        'rows': [record(status: 'unknown')],
        'total': 1,
      },
      {'rows': <Object>[]},
    ]) {
      client.pages[1] = page;
      await expectLater(
        InterviewApi(client).findOwnReschedule('synthetic-session', 44),
        throwsA(isA<ApiException>()),
      );
    }
  });

  testWidgets('初始核对和核对失败时不允许重复申请，恢复后可以操作', (tester) async {
    final client = RequestClient();
    addTearDown(client.close);
    final api = RequestApi(client)
      ..readGate = Completer<Map<String, dynamic>?>();
    await mount(tester, api);
    expect(find.text('正在核对改期申请…'), findsOneWidget);
    expect(find.text('申请改期'), findsNothing);
    api.readGate!.completeError(const ApiException('合成网络异常'));
    await tester.pumpAndSettle();
    expect(find.text('刷新申请状态'), findsOneWidget);
    expect(find.text('申请改期'), findsNothing);
    api.readGate = null;
    await tester.tap(find.text('刷新申请状态'));
    await tester.pumpAndSettle();
    expect(find.text('申请改期'), findsOneWidget);
  });

  testWidgets('待处理申请能刷新到审批结果', (tester) async {
    final client = RequestClient();
    addTearDown(client.close);
    final api = RequestApi(client)..row = record();
    await mount(tester, api);
    await tester.pumpAndSettle();
    expect(find.text('改期申请已提交'), findsOneWidget);
    api.row = record(status: 'approved');
    await tester.tap(find.byTooltip('刷新申请状态'));
    await tester.pumpAndSettle();
    expect(find.text('改期申请已同意'), findsOneWidget);
    expect(api.sends, 0);
  });

  testWidgets('提交超时仅核对不重发，成功核对后显示原申请', (tester) async {
    final client = RequestClient();
    addTearDown(client.close);
    final api = RequestApi(client)..submitError = const ApiException('合成提交超时');
    await mount(tester, api);
    await tester.pumpAndSettle();
    await tester.tap(find.text('申请改期'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' 合成改期原因 ');
    await tester.tap(find.text('提交申请'));
    await tester.pumpAndSettle();
    expect(api.sends, 1);
    expect(api.reason, '合成改期原因');
    expect(find.text('刷新申请状态'), findsOneWidget);
    expect(find.text('申请改期'), findsNothing);
    api.row = record();
    await tester.tap(find.text('刷新申请状态'));
    await tester.pumpAndSettle();
    expect(find.text('改期申请已提交'), findsOneWidget);
    expect(api.sends, 1);
    expect(tester.takeException(), isNull);
  });
}
