import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:enterprise_recruiter/api/talent_api.dart' as talent_api;
import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/core/network/enterprise_api_client.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/talent_detail_page.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/talent_resume_pdf_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/talent_detail_fixture.dart';

/// 字节级 HTTP 适配器：返回可配置的 PDF 字节与响应头，并记录请求。
class PdfHttpAdapter implements HttpClientAdapter {
  int status = 200;
  List<int>? bytes;
  Map<String, List<String>> headers = const {};
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromBytes(bytes ?? const <int>[], status, headers: {
      Headers.contentTypeHeader: ['application/pdf'],
      ...headers,
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('原始简历字节下载', () {
    late PdfHttpAdapter adapter;
    late EnterpriseApiClient client;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({
        'enterprise_access_token': 'synthetic-test-token',
      });
      adapter = PdfHttpAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://synthetic.invalid'));
      dio.httpClientAdapter = adapter;
      client = EnterpriseApiClient(dio: dio);
    });

    test('携带 Bearer Token 请求企业端 PDF 地址并原样返回字节', () async {
      final bytes = Uint8List.fromList([
        ...ascii.encode('%PDF-1.7\n'),
        0,
        255,
        128,
      ]);
      adapter
        ..bytes = bytes
        ..headers = {Headers.contentTypeHeader: ['application/pdf']};
      final got = await talent_api.getTalentResumePdf(7, client: client);
      expect(got, bytes);
      final request = adapter.requests.single;
      expect(request.path, '/enterprise/talent/7/resume/pdf');
      expect(request.method, 'GET');
      expect(request.headers['Authorization'], 'Bearer synthetic-test-token');
      expect(request.headers['Accept'], 'application/pdf');
    });

    test('HTTP 401 映射为登录失效提示', () async {
      adapter
        ..status = 401
        ..bytes = utf8.encode(jsonEncode({'code': 401, 'msg': 'Expired'}))
        ..headers = {Headers.contentTypeHeader: [Headers.jsonContentType]};
      await expectLater(
        talent_api.getTalentResumePdf(7, client: client),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('重新登录'),
          ),
        ),
      );
    });

    test('HTTP 200 的错误信封按 msg 展示业务提示', () async {
      adapter
        ..bytes = utf8.encode(
          jsonEncode({'code': 500, 'msg': '该简历未保存原始 PDF'}),
        )
        ..headers = {Headers.contentTypeHeader: [Headers.jsonContentType]};
      await expectLater(
        talent_api.getTalentResumePdf(7, client: client),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            '该简历未保存原始 PDF',
          ),
        ),
      );
    });

    test('拒绝非 PDF 响应与超过 10MB 的响应', () async {
      adapter
        ..bytes = utf8.encode('not a pdf')
        ..headers = {Headers.contentTypeHeader: ['application/pdf']};
      await expectLater(
        talent_api.getTalentResumePdf(7, client: client),
        throwsA(isA<ApiException>()),
      );

      adapter.bytes = Uint8List(10 * 1024 * 1024 + 1);
      await expectLater(
        talent_api.getTalentResumePdf(7, client: client),
        throwsA(isA<ApiException>()),
      );
      expect(adapter.requests, hasLength(2));
    });
  });

  group('资料卡原始简历入口', () {
    testWidgets('候选人未保存原始 PDF 时不展示入口', (tester) async {
      final source = TalentFakeSource();
      await pumpTalentWidget(
        tester,
        TalentDetailPage(
          talent: const {'talentId': 11, 'name': '合成候选人'},
          source: source,
        ),
      );
      expect(find.text('原始简历'), findsNothing);
    });

    testWidgets('已保存原始 PDF 时展示入口并跳转到预览页', (tester) async {
      final source = TalentFakeSource()..resume['fileName'] = '个人简历.pdf';
      await pumpTalentWidget(
        tester,
        TalentDetailPage(
          talent: const {'talentId': 11, 'name': '合成候选人'},
          source: source,
        ),
      );
      expect(find.text('原始简历'), findsOneWidget);
      await tester.tap(find.text('原始简历'));
      await tester.pumpAndSettle();
      final page = tester.widget<TalentResumePdfPage>(
        find.byType(TalentResumePdfPage),
      );
      expect(page.talentId, 11);
      expect(page.fileName, '个人简历.pdf');
      expect(find.text('个人简历.pdf'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(TalentResumePdfPage), findsNothing);
    });
  });

  group('原始简历预览页', () {
    testWidgets('加载失败展示友好错误，重试重新调用加载器', (tester) async {
      var calls = 0;
      Future<Uint8List> loader() async {
        calls++;
        throw ApiException(
          calls == 1 ? '原始 PDF 不存在，请稍后重试' : '合成第二次失败',
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: TalentResumePdfPage(
            talentId: 7,
            fileName: '个人简历.pdf',
            loader: loader,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('原始 PDF 不存在，请稍后重试'), findsOneWidget);
      await tester.tap(find.text('重新加载'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('合成第二次失败'), findsOneWidget);
    });

    testWidgets('离开加载中的页面不更新已销毁状态', (tester) async {
      final pending = Completer<Uint8List>();
      await tester.pumpWidget(
        MaterialApp(
          home: TalentResumePdfPage(
            talentId: 7,
            loader: () => pending.future,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      pending.completeError(const ApiException('synthetic failure'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
