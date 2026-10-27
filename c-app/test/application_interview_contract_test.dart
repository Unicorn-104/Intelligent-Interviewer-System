import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/formatters/backend_date.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/applications/data/application_api.dart';
import 'package:intelligent_interviewer/features/applications/domain/job_application.dart';
import 'package:intelligent_interviewer/features/interviews/data/interview_api.dart';
import 'package:intelligent_interviewer/features/interviews/domain/interview_schedule.dart';

void main() {
  test(
    'uses PC GET paths, query names, bearer authentication and envelopes',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
      final paths = <Uri>[];
      final subscription = server.listen((request) async {
        paths.add(request.uri);
        expect(request.method, 'GET');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer synthetic-session',
        );
        final path = request.uri.path;
        final Object data;
        if (path == '/agent/v1/applications') {
          data = {
            'items': <Object>[],
            'page': 2,
            'size': 10,
            'total': 10,
            'hasNext': false,
          };
        } else if (path == '/agent/v1/applications/7') {
          data = {
            'id': 7,
            'status': 'interview',
            'statusText': '已约面',
            'timeline': [
              {
                'stage': '2',
                'state': 'current',
                'title': '面试中',
                'occurredAt': '2026-10-15T08:30:00+08:00',
              },
            ],
          };
        } else if (path == '/system/conference/schedule') {
          data = [
            {
              'appointmentId': 12,
              'sessionId': null,
              'startAt': '2026-12-31 09:00',
              'statusText': '待面试',
            },
          ];
        } else if (path == '/system/conference/session/9') {
          data = {
            'sessionId': 9,
            'roundNo': 2,
            'totalRounds': 3,
            'appointmentStartAt': '2026-12-31 09:00',
            'mode': 3,
          };
        } else {
          fail('Unexpected API path: $path');
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'code': 200, 'data': data}));
        await request.response.close();
      });
      try {
        final applications = ApplicationApi(client);
        final interviews = InterviewApi(client);
        final page = await applications.list(
          'synthetic-session',
          page: 2,
          status: 'interview',
        );
        expect(page.hasNext, false);
        expect(paths.last.queryParameters, {
          'page': '2',
          'size': '10',
          'status': 'interview',
        });
        final detail = await applications.detail('synthetic-session', 7);
        expect(detail.timeline.single.stateText, '进行中');
        expect(
          displayBackendDate(detail.timeline.single.occurredAt),
          '2026-10-15 08:30',
        );
        final schedule = await interviews.schedule(
          'synthetic-session',
          DateTime(2026, 12, 15),
        );
        expect(paths.last.queryParameters, {
          'from': '2026-12-01',
          'to': '2027-01-01',
        });
        expect(schedule.single.sessionId, isNull);
        expect(schedule.single.dayKey, '2026-12-31');
        final session = await interviews.detail('synthetic-session', 9);
        expect(session.roundNo, 2);
        expect(interviewModeLabel(session.mode), 'AI + 多面试官');
        await applications.list('synthetic-session');
        expect(paths.last.queryParameters.containsKey('status'), false);
      } finally {
        client.close();
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );

  test('candidate reschedule uses authenticated request and can verify its outcome', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
    final seen = <HttpRequest>[];
    final subscription = server.listen((request) async {
      seen.add(request);
      expect(request.headers.value(HttpHeaders.authorizationHeader), 'Bearer synthetic-session');
      request.response.headers.contentType = ContentType.json;
      if (request.method == 'POST') {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(body['newStartTime'], '2099-01-03 10:05');
        expect(body['reason'], '合成原因');
        request.response.write(jsonEncode({'code': 200, 'data': {'requestId': 9, 'appointmentId': 12, 'status': 'pending'}}));
      } else {
        expect(request.method, 'GET');
        request.response.write(jsonEncode({'code': 200, 'rows': [{'requestId': 9, 'appointmentId': 12, 'status': 'pending'}], 'total': 1}));
      }
      await request.response.close();
    });
    try {
      final api = InterviewApi(client);
      final submitted = await api.submitReschedule('synthetic-session', 12, DateTime(2099, 1, 3, 10, 5), ' 合成原因 ');
      expect(submitted['status'], 'pending');
      final existing = await api.findOwnReschedule('synthetic-session', 12);
      expect(existing?['requestId'], 9);
      expect(seen.map((request) => request.method), ['POST', 'GET']);
    } finally {
      client.close();
      await subscription.cancel();
      await server.close(force: true);
    }
  });

  test(
    '401 envelopes preserve codes and notify only the supplied session',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
      final notification = ApiClient.unauthorizedTokens.first;
      final serving = server.first.then((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'code': 401, 'msg': '登录已过期'}));
        await request.response.close();
      });
      try {
        await expectLater(
          client.get(
            '/system/conference/schedule',
            token: 'expired-synthetic-session',
          ),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 401)),
        );
        expect(await notification, 'expired-synthetic-session');
        await serving;
      } finally {
        client.close();
        await server.close(force: true);
      }
    },
  );

  test(
    'missing route diagnostics are not shown as user-facing messages',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
      final serving = server.first.then((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'code': 500,
            'msg':
                "No static resource system/conference/schedule for request '/system/conference/schedule'.",
          }),
        );
        await request.response.close();
      });
      try {
        await expectLater(
          InterviewApi(
            client,
          ).schedule('synthetic-session', DateTime(2026, 10)),
          throwsA(
            isA<ApiException>()
                .having((e) => e.message, 'message', '服务暂时不可用，请稍后重试')
                .having((e) => e.code, 'code', 500),
          ),
        );
        await serving;
      } finally {
        client.close();
        await server.close(force: true);
      }
    },
  );

  test('rejects incomplete page responses instead of silently truncating', () {
    expect(
      () => ApplicationPage.fromJson({'items': [], 'page': 1}),
      throwsA(isA<ApiException>()),
    );
    final unknown = JobApplication.fromJson({
      'id': 4,
      'status': 'future-status',
      'statusText': '服务端新状态',
    });
    expect(unknown.statusText, '服务端新状态');
    expect(unknown.timeline, isEmpty);
  });
}
