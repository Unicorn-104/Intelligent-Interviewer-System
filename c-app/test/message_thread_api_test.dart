import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/messages/data/message_api.dart';
import 'package:intelligent_interviewer/features/messages/domain/app_message.dart';

// 单独运行真实 HTTP 测试，避免 Widget binding 的网络替身拦截请求。
void main() {
  test('分组、历史游标及逐批已读使用真实 HTTP 契约', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
    final paths = <Uri>[];
    Map? readBody;
    final sub = server.listen((request) async {
      paths.add(request.uri);
      request.response.headers.contentType = ContentType.json;
      if (request.method == 'PUT') {
        readBody = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        request.response.write(jsonEncode({'code': 200}));
      } else {
        request.response.write(
          jsonEncode({
            'code': 200,
            'data': {
              'items': [
                {
                  'sourceId': 30,
                  'category': 'COMPANY',
                  'threadType': 'COMPANY',
                  'threadId': 7,
                  'occurredAt': '2026-10-28 00:00:00',
                  'unreadCount': 1,
                },
              ],
              'hasMore': false,
              'unreadCounts': {'HR': 0, 'COMPANY': 1, 'SYSTEM': 0},
            },
          }),
        );
      }
      await request.response.close();
    });
    try {
      final api = MessageApi(client);
      final before = AppMessage(
        sourceId: 40,
        category: AppMessageCategory.company,
        title: '合成企业',
        content: '',
        occurredAt: DateTime(2026, 10, 28),
        unreadCount: 1,
      );
      final page = await api.fetchThreads('synthetic', before: before);
      await api.fetchEvents('synthetic', page.items.single, beforeId: 30);
      expect(paths.length, 2);
      expect(paths.first.queryParameters['category'], 'ALL');
      expect(paths.first.queryParameters['beforeType'], 'COMPANY');
      expect(paths.first.queryParameters['beforeTime'], '2026-10-28 00:00:00');
      expect(paths.first.queryParameters['beforeId'], '40');
      expect(paths.last.path, '/app/messages/threads/COMPANY/7/events');
      expect(paths.last.queryParameters['beforeId'], '30');
      await api.markEventsRead('synthetic', page.items.single, [30]);
      expect(readBody, {
        'messageIds': [30],
      });
      expect(page.items.single.copyWith(unreadCount: 0).threadId, 7);
    } finally {
      client.close();
      await sub.cancel();
      await server.close(force: true);
    }
  });

  test('旧服务缺接口时明确提示更新，不伪造历史记录', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
    final sub = server.listen((request) async {
      request.response.statusCode = 404;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'code': 404, 'msg': 'No static resource internal/path'}),
      );
      await request.response.close();
    });
    try {
      await expectLater(
        MessageApi(client).fetchThreads('synthetic'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            '消息服务需要更新，请联系管理员后重试',
          ),
        ),
      );
    } finally {
      client.close();
      await sub.cancel();
      await server.close(force: true);
    }
  });
}
