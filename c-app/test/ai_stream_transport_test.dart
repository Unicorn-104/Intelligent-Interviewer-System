import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/ai/domain/ai_models.dart';

void main() {
  test(
    'authenticated SSE receives UTF8 and uses cursor without exposing token in URL',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
      addTearDown(() async {
        client.close();
        await server.close(force: true);
      });
      server.listen((request) async {
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer synthetic-token',
        );
        expect(request.uri.queryParameters['after'], '8');
        expect(request.uri.toString(), isNot(contains('synthetic-token')));
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write('id: 9\nevent: delta\ndata: {"text":"你好"}\n\n');
        await request.response.close();
      });
      final events = await decodeAiEvents(
        client.eventLines('/events?after=8', token: 'synthetic-token'),
      ).toList();
      expect(events.single.data['text'], '你好');
    },
  );

  test(
    'business 401 on SSE follows existing session-expiry notification',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
      addTearDown(() async {
        client.close();
        await server.close(force: true);
      });
      final expired = ApiClient.unauthorizedTokens.first;
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'code': 401, 'msg': '登录已失效'}));
        await request.response.close();
      });
      await expectLater(
        client.eventLines('/events', token: 'synthetic-token').toList(),
        throwsA(isA<ApiException>()),
      );
      expect(await expired, 'synthetic-token');
    },
  );
}
