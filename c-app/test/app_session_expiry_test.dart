import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/app.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/auth/data/auth_api.dart';
import 'package:intelligent_interviewer/features/auth/data/token_store.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';
import 'package:intelligent_interviewer/features/auth/presentation/auth_controller.dart';

class MemoryStore implements TokenStore {
  String? value = 'synthetic-active-session';
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async => value = token;
  @override
  Future<void> clear() async => value = null;
}

class SessionApi extends AuthApi {
  SessionApi(super.client);
  @override
  Future<AuthSession> getSession(String token) async => AuthSession(
    token: token,
    userId: 1,
    userName: 'synthetic',
    nickName: '测试',
  );
  @override
  Future<void> logout(String token) async {}
}

class StubHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class UnauthorizedResponse extends StreamView<List<int>>
    implements HttpClientResponse {
  UnauthorizedResponse()
    : super(
        Stream.value(utf8.encode(jsonEncode({'code': 401, 'msg': '登录状态已过期'}))),
      );
  @override
  int get statusCode => 200;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class UnauthorizedRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = StubHeaders();
  @override
  Future<HttpClientResponse> close() async => UnauthorizedResponse();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class UnauthorizedTransport implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => UnauthorizedRequest();
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets(
    'ignores old sessions, deduplicates 401 and clears detail routes on relogin',
    (tester) async {
      final transport = ApiClient(httpClient: UnauthorizedTransport());
      final store = MemoryStore();
      final controller = AuthController(
        api: SessionApi(transport),
        tokenStore: store,
        autoLoadCaptcha: false,
      );
      await tester.pumpWidget(
        IntelligentInterviewerApp(authController: controller),
      );
      await tester.pumpAndSettle();

      Future<void> expire(String token) async {
        await expectLater(
          transport.get('/synthetic-expiry', token: token),
          throwsA(isA<ApiException>()),
        );
      }

      await expire('synthetic-old-session');
      await tester.pumpAndSettle();
      expect(find.text('登录状态已过期'), findsNothing);
      final context = tester.element(find.text('首页').last);
      unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('合成详情页')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await Future.wait([
        expire('synthetic-active-session'),
        expire('synthetic-active-session'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('登录状态已过期'), findsOneWidget);
      await tester.tap(find.text('重新登录'));
      await tester.pumpAndSettle();
      expect(controller.session, isNull);
      expect(store.value, isNull);
      expect(find.text('合成详情页'), findsNothing);
      expect(find.text('欢迎回来'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      transport.close();
    },
  );
}
