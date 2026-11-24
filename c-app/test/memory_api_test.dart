import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/ai/data/ai_api.dart';

void main() {
  test('记忆列表修改和删除携带鉴权及版本，保持后端字段契约', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
    final requests = <Map<String, dynamic>>[];
    final subscription = server.listen((request) async {
      requests.add({
        'method': request.method,
        'path': request.uri.path,
        'authorization': request.headers.value('authorization'),
        'body': request.method == 'PUT'
            ? jsonDecode(await utf8.decoder.bind(request).join())
            : null,
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'code': 200,
          if (request.method == 'GET')
            'data': {
              'items': [
                {'id': 'memory-7', 'content': '合成偏好', 'revision': 3},
              ],
            },
        }),
      );
      await request.response.close();
    });
    try {
      final api = AiApi(client);
      final items = await api.longTermMemories('synthetic-token');
      expect(items.single['revision'], 3);
      await api.updateLongTermMemory(
        'synthetic-token',
        'memory-7',
        '修改后的合成偏好',
        3,
      );
      await api.deleteLongTermMemory('synthetic-token', 'memory-7');
      expect(requests.map((r) => r['method']), ['GET', 'PUT', 'DELETE']);
      expect(requests.first['path'], '/app/ai/long-term-memories');
      expect(requests[1]['path'], '/app/ai/long-term-memories/memory-7');
      expect(requests[1]['body'], {'content': '修改后的合成偏好', 'revision': 3});
      expect(requests.last['path'], requests[1]['path']);
      expect(
        requests.every((r) => r['authorization'] == 'Bearer synthetic-token'),
        isTrue,
      );
    } finally {
      client.close();
      await subscription.cancel();
      await server.close(force: true);
    }
  });

  test('列表结构无效时报告失败，不显示为空记忆', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
    final subscription = server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'code': 200,
          'data': {'items': 'invalid'},
        }),
      );
      await request.response.close();
    });
    try {
      await expectLater(
        AiApi(client).longTermMemories('synthetic'),
        throwsA(isA<ApiException>()),
      );
    } finally {
      client.close();
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}
