import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';
import 'package:intelligent_interviewer/features/resume/data/resume_api.dart';
import 'package:intelligent_interviewer/features/resume/domain/app_resume.dart';
import 'package:intelligent_interviewer/features/resume/presentation/resume_pdf_screen.dart';
import 'package:intelligent_interviewer/screens/resume_screen.dart';
import 'package:intelligent_interviewer/theme/app_theme.dart';

const session = AuthSession(
  token: 'synthetic-pdf-session',
  userId: 1,
  userName: 'synthetic',
  nickName: 'Test',
);

class PreviewApi extends ResumeApi {
  PreviewApi() : super(ApiClient());
  int calls = 0;
  int deleteCalls = 0;
  int listCalls = 0;
  ApiException? deleteError;
  final resumes = <AppResume>[
    AppResume(resumeId: 1, resumeName: 'Manual resume'),
    AppResume(
      resumeId: 7,
      resumeName: 'Imported resume',
      fileName: 'synthetic-very-long-original-resume-file-name.pdf',
      pdfUrl: '/app/resumes/7/pdf',
    ),
  ];
  Completer<Uint8List>? pending;

  @override
  Future<List<AppResume>> list(String token) async {
    listCalls++;
    return List.of(resumes);
  }

  @override
  Future<void> delete(String token, int resumeId) async {
    deleteCalls++;
    if (deleteError != null) throw deleteError!;
    resumes.removeWhere((resume) => resume.resumeId == resumeId);
  }

  @override
  Future<Uint8List> pdf(String token, int resumeId) async {
    calls++;
    if (pending != null) return pending!.future;
    throw const ApiException('原始 PDF 不存在，请刷新简历列表');
  }
}

void main() {
  HttpOverrides? previousOverrides;
  setUp(() {
    previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
  });
  tearDown(() => HttpOverrides.global = previousOverrides);

  test(
    'downloads original bytes with authorization on the existing endpoint',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
      addTearDown(client.close);
      addTearDown(() => server.close(force: true));
      final bytes = <int>[...ascii.encode('%PDF-1.7\n'), 0, 255, 128];
      final served = server.first.then((request) async {
        expect(request.uri.path, '/app/resumes/7/pdf');
        expect(request.uri.query, isEmpty);
        expect(
          request.headers.value('Authorization'),
          'Bearer synthetic-session',
        );
        request.response.headers.contentType = ContentType(
          'application',
          'pdf',
        );
        request.response.add(bytes);
        await request.response.close();
      });
      expect(await ResumeApi(client).pdf('synthetic-session', 7), bytes);
      await served;
    },
  );

  for (final httpStatus in [200, 401]) {
    test('propagates login expiry for HTTP $httpStatus', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
      addTearDown(client.close);
      addTearDown(() => server.close(force: true));
      final expiry = ApiClient.unauthorizedTokens.first;
      final served = server.first.then((request) async {
        request.response.statusCode = httpStatus;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'code': 401, 'msg': 'Expired'}));
        await request.response.close();
      });
      await expectLater(
        ResumeApi(client).pdf('expired-session', 7),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 401)),
      );
      expect(await expiry, 'expired-session');
      await served;
    });
  }

  for (final code in [403, 404, 500]) {
    test('maps server error $code without exposing diagnostics', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
      addTearDown(client.close);
      addTearDown(() => server.close(force: true));
      final served = server.first.then((request) async {
        request.response.statusCode = code;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({'code': code, 'msg': 'private diagnostics'}),
        );
        await request.response.close();
      });
      await expectLater(
        ResumeApi(client).pdf('synthetic', 7),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            isNot(contains('private diagnostics')),
          ),
        ),
      );
      await served;
    });
  }

  for (final invalid in ['empty', 'signature', 'oversized', 'redirect']) {
    test('rejects $invalid PDF response', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
      addTearDown(client.close);
      addTearDown(() => server.close(force: true));
      var requests = 0;
      final subscription = server.listen((request) async {
        requests++;
        request.response.headers.contentType = ContentType(
          'application',
          'pdf',
        );
        if (invalid == 'redirect') {
          request.response.statusCode = 302;
          request.response.headers.set('location', '/unexpected');
        } else if (invalid == 'signature') {
          request.response.write('not a PDF');
        } else if (invalid == 'oversized') {
          request.response.add(Uint8List(10 * 1024 * 1024 + 1));
        }
        try {
          await request.response.close();
        } on IOException {
          // The client closes rejected large responses before receiving them all.
        }
      });
      addTearDown(subscription.cancel);
      await expectLater(
        ResumeApi(client).pdf('synthetic', 7),
        throwsA(isA<ApiException>()),
      );
      expect(requests, 1);
    });
  }

  for (final width in [320.0, 430.0]) {
    testWidgets('only attached resumes open PDF and fit width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = PreviewApi();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ResumeScreen(session: session, api: api),
        ),
      );
      await tester.pumpAndSettle();
      final link = find.textContaining('查看原始 PDF：');
      expect(link, findsOneWidget);
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.byType(ResumePdfScreen), findsOneWidget);
      expect(api.calls, 1);
      expect(find.text('原始 PDF 不存在，请刷新简历列表'), findsOneWidget);
      await tester.tap(find.text('重新加载'));
      await tester.pumpAndSettle();
      expect(api.calls, 2);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Imported resume'), findsOneWidget);
    });
  }

  testWidgets('leaving a loading PDF does not update a disposed screen', (
    tester,
  ) async {
    final api = PreviewApi()..pending = Completer<Uint8List>();
    await tester.pumpWidget(
      MaterialApp(
        home: ResumePdfScreen(
          session: session,
          resume: AppResume(resumeId: 7),
          api: api,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    api.pending!.completeError(const ApiException('synthetic failure'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'confirms resume deletion, refreshes the list, and preserves cancellation',
    (tester) async {
      final api = PreviewApi();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ResumeScreen(session: session, api: api),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('简历操作').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除简历'));
      await tester.pumpAndSettle();
      expect(find.textContaining('已用于投递的简历不能删除'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(api.deleteCalls, 0);
      expect(find.text('Manual resume'), findsOneWidget);

      await tester.tap(find.byTooltip('简历操作').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除简历'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      expect(api.deleteCalls, 1);
      expect(api.listCalls, 2);
      expect(find.text('Manual resume'), findsNothing);
      expect(find.text('Imported resume'), findsOneWidget);
      expect(find.text('简历已删除'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows backend refusal and leaves a referenced resume visible', (
    tester,
  ) async {
    final api = PreviewApi()
      ..deleteError = const ApiException('该简历已关联投递记录，暂不能删除');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ResumeScreen(session: session, api: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('简历操作').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除简历'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(find.text('该简历已关联投递记录，暂不能删除'), findsOneWidget);
    expect(find.text('Manual resume'), findsOneWidget);
    expect(api.listCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
