import 'dart:async';

import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/schedule/data/reschedule_review_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/schedule/reschedule_review_page.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/jd_http_fixture.dart';

Map<String, dynamic> syntheticRequest({
  int id = 1,
  String status = 'pending',
}) => {
  'requestId': id,
  'appointmentId': 21,
  'status': status,
  'candidateName': '合成候选人',
  'positionName': '合成岗位',
  'originalStartTime': '2099-01-02 09:00:00',
  'originalEndTime': '2099-01-02 09:45:00',
  'newStartTime': '2099-01-03 09:00:00',
  'newEndTime': '2099-01-03 09:45:00',
  'reason': '合成申请原因',
  'requestedAt': '2026-10-23 10:00:00',
  'interviewerName': '合成面试官',
  if (status != 'pending') ...{
    'reviewNote': '合成审批说明',
    'reviewedAt': '2026-10-23 11:00:00',
    'reviewerName': '合成HR',
  },
};

class ReviewFixture extends RescheduleReviewDataSource {
  final calls = <(String?, int)>[];
  final decisions = <(int, String, String?)>[];
  List<RescheduleRequest> rows = [
    RescheduleRequest.fromJson(syntheticRequest()),
  ];
  Object? loadError, reviewError;
  Completer<RescheduleRequest>? reviewGate;
  final pending = <String, Completer<RescheduleReviewResult>>{};
  bool paginate = false;
  @override
  Future<RescheduleReviewResult> load({String? status, int page = 1}) async {
    calls.add((status, page));
    if (loadError != null) throw loadError!;
    if (pending[status] case final gate?) return gate.future;
    final filtered = rows
        .where((row) => status == null || row.status == status)
        .toList();
    if (paginate) {
      return RescheduleReviewResult(
        rows: [RescheduleRequest.fromJson(syntheticRequest(id: page))],
        total: 2,
      );
    }
    return RescheduleReviewResult(rows: filtered, total: filtered.length);
  }

  @override
  Future<RescheduleRequest> review(
    int id,
    String decision, {
    String? note,
  }) async {
    decisions.add((id, decision, note));
    if (reviewError != null) throw reviewError!;
    if (reviewGate != null) return reviewGate!.future;
    final row = RescheduleRequest.fromJson(
      syntheticRequest(id: id, status: decision),
    );
    rows = [row];
    return row;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('真实接口契约', () {
    late JdHttpFixture http;
    late RescheduleReviewDataSource source;
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({
        'enterprise_access_token': 'synthetic-token',
      });
      http = JdHttpFixture();
      source = RescheduleReviewDataSource(client: http.client);
    });
    tearDown(() => http.close());
    test('分页状态发送真实接口，不传企业或候选人归属参数', () async {
      http.adapter.body = {
        'code': 200,
        'rows': [syntheticRequest()],
        'total': 21,
      };
      final result = await source.load(status: 'pending', page: 2);
      expect(result.total, 21);
      expect(result.rows.single.id, 1);
      final request = http.adapter.requests.single;
      expect(request.path, '/enterprise/interview/reschedule-requests');
      expect(request.queryParameters, {
        'status': 'pending',
        'pageNum': 2,
        'pageSize': 20,
      });
      expect(
        request.headers['authorization'] ?? request.headers['Authorization'],
        'Bearer synthetic-token',
      );
    });
    test('通过和驳回PUT到专用审批接口，不调用直接改期接口', () async {
      for (final decision in ['approved', 'rejected']) {
        http.adapter.body = {
          'code': 200,
          'data': syntheticRequest(status: decision),
        };
        final row = await source.review(1, decision, note: ' 合成说明 ');
        expect(row.status, decision);
        final request = http.adapter.requests.last;
        expect(
          request.path,
          '/enterprise/interview/reschedule-requests/1/review',
        );
        expect(request.method, 'PUT');
        expect(request.data, {'decision': decision, 'note': '合成说明'});
      }
    });
    test('坏响应不能误报为空列表或审批成功', () async {
      for (final body in [
        {'code': 200},
        {
          'code': 200,
          'rows': [syntheticRequest(status: 'approved')],
          'total': 1,
        },
        {
          'code': 200,
          'rows': [
            {'requestId': 1},
          ],
          'total': 1,
        },
      ]) {
        http.adapter.body = body;
        await expectLater(
          source.load(status: 'pending'),
          throwsFormatException,
        );
      }
      http.adapter.body = {
        'code': 200,
        'data': syntheticRequest(id: 2, status: 'approved'),
      };
      await expectLater(source.review(1, 'approved'), throwsFormatException);
      await expectLater(source.review(1, 'rejected'), throwsFormatException);
      await expectLater(source.load(status: 'unknown'), throwsFormatException);
    });
    test('未部署、未登录和权限不足均明确展示', () {
      expect(
        RescheduleReviewDataSource.errorMessage(
          const ApiException('x', code: 404),
        ),
        contains('尚未部署'),
      );
      expect(
        RescheduleReviewDataSource.errorMessage(
          const ApiException('x', code: 401),
        ),
        contains('登录已失效'),
      );
      expect(
        RescheduleReviewDataSource.errorMessage(
          const ApiException('x', code: 403),
        ),
        contains('暂无审批权限'),
      );
    });
  });

  Future<void> mount(
    WidgetTester tester,
    ReviewFixture source, {
    Size size = const Size(430, 900),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: RescheduleReviewPage(source: source),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('展示真实返回，不标演示；取消不发请求，通过后刷新真实状态', (tester) async {
    final source = ReviewFixture();
    await mount(tester, source);
    expect(find.text('演示数据'), findsNothing);
    expect(find.text('合成候选人 · 合成岗位'), findsOneWidget);
    await tap(tester, 'reschedule-review-approve-1');
    expect(source.decisions, isEmpty);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(source.decisions, isEmpty);
    await tap(tester, 'reschedule-review-approve-1');
    await tap(tester, 'reschedule-review-confirm');
    expect(source.decisions, [(1, 'approved', '')]);
    expect(find.byKey(const Key('reschedule-review-approve-1')), findsNothing);
    expect(find.text('审批说明：合成审批说明'), findsOneWidget);
  });
  testWidgets('驳回说明必填，确定才写入一次并显示原安排不变', (tester) async {
    final source = ReviewFixture();
    await mount(tester, source);
    await tap(tester, 'reschedule-review-reject-1');
    await tap(tester, 'reschedule-review-confirm');
    expect(find.text('请填写驳回说明'), findsOneWidget);
    expect(source.decisions, isEmpty);
    await tester.enterText(
      find.byKey(const Key('reschedule-review-note')),
      '合成驳回说明',
    );
    await tap(tester, 'reschedule-review-confirm');
    expect(source.decisions, [(1, 'rejected', '合成驳回说明')]);
    expect(find.text('申请已驳回，原面试安排不变'), findsOneWidget);
  });
  testWidgets('提交期间禁重复操作，结果不确定时不自动重发', (tester) async {
    final source = ReviewFixture()..reviewGate = Completer<RescheduleRequest>();
    await mount(tester, source);
    await tap(tester, 'reschedule-review-approve-1');
    await tap(tester, 'reschedule-review-confirm');
    expect(source.decisions, hasLength(1));
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('reschedule-review-approve-1')),
          )
          .onPressed,
      isNull,
    );
    source.reviewGate!.completeError(const ApiException('合成超时'));
    await tester.pumpAndSettle();
    expect(find.textContaining('审批结果待核对：'), findsOneWidget);
    expect(find.byKey(const Key('reschedule-review-approve-1')), findsNothing);
    await tap(tester, 'reschedule-review-check-1');
    expect(source.decisions, hasLength(1));
    expect(find.byKey(const Key('reschedule-review-approve-1')), findsNothing);
  });
  testWidgets('冲突原因明确展示，必须刷新确认待审批才能人工恢复操作', (tester) async {
    final source = ReviewFixture()..reviewError = const ApiException('合成时段冲突');
    await mount(tester, source);
    await tap(tester, 'reschedule-review-approve-1');
    await tap(tester, 'reschedule-review-confirm');
    expect(find.text('合成时段冲突'), findsOneWidget);
    final restore = find.widgetWithText(TextButton, '人工核对后恢复操作');
    expect(tester.widget<TextButton>(restore).onPressed, isNull);
    await tap(tester, 'reschedule-review-check-1');
    expect(tester.widget<TextButton>(restore).onPressed, isNotNull);
    await tester.ensureVisible(restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();
    expect(source.decisions, hasLength(1));
    await tester.tap(find.text('已核对，恢复操作'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('reschedule-review-approve-1')),
      findsOneWidget,
    );
    expect(source.decisions, hasLength(1));
  });

  testWidgets('状态切换隔离迟到响应，关闭后不setState', (tester) async {
    final source = ReviewFixture();
    await mount(tester, source);
    source.pending['pending'] = Completer<RescheduleReviewResult>();
    await tester.tap(find.byKey(const Key('reschedule-review-filter-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('reschedule-review-filter-2')));
    await tester.pumpAndSettle();
    expect(find.text('暂无改期申请'), findsOneWidget);
    source.pending['pending']!.complete(
      RescheduleReviewResult(rows: source.rows, total: 1),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reschedule-review-card-1')), findsNothing);
    source.pending['rejected'] = Completer<RescheduleReviewResult>();
    await tester.tap(find.byKey(const Key('reschedule-review-filter-3')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    source.pending['rejected']!.complete(
      const RescheduleReviewResult(rows: [], total: 0),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('分页、错误重试和真实空态均可达', (tester) async {
    final source = ReviewFixture()..loadError = const ApiException('合成错误');
    await mount(tester, source);
    expect(find.text('审批记录加载失败'), findsOneWidget);
    source.loadError = null;
    source.paginate = true;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    await tap(tester, 'reschedule-review-more');
    expect(source.calls.last, (null, 2));
    expect(find.byKey(const Key('reschedule-review-card-2')), findsOneWidget);
    source.paginate = false;
    source.rows = [];
    await tap(tester, 'reschedule-review-refresh');
    expect(find.text('暂无改期申请'), findsOneWidget);
  });
  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('审批在$size双倍字号和键盘下不溢出', (tester) async {
      await mount(tester, ReviewFixture(), size: size, scale: 2);
      expect(tester.takeException(), isNull);
      await tap(tester, 'reschedule-review-reject-1');
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height < 500 ? 100 : 220,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(
        find.byKey(const Key('reschedule-review-note')),
        '合成原因',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('reschedule-review-confirm')),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
