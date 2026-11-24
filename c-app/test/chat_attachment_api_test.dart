import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/messages/data/chat_attachment_picker.dart';
import 'package:intelligent_interviewer/features/messages/data/chat_resource_url.dart';
import 'package:intelligent_interviewer/features/messages/data/message_api.dart';

void main() {
  test('资源仅允许当前网关，保留 prod-api 并拒绝外站及路径绕过', () {
    const base = 'https://example.test/prod-api';
    for (final path in [
      '/profile/a.png',
      '/prod-api/profile/a.png',
      'https://example.test/profile/a.png',
    ]) {
      expect(
        chatResourceUrl(path, base),
        'https://example.test/prod-api/profile/a.png',
      );
    }
    for (final path in [
      '//evil.test/profile/a',
      'https://evil.test/profile/a',
      '/profile/../secret',
      '/profile/%2e%2e/secret',
      '/profile/a?token=x',
      '/profile/a#x',
      'file:///profile/a',
      '/profile/a b',
      '/app/profile/a',
    ]) {
      expect(chatResourceUrl(path, base), isNull, reason: path);
    }
  });

  test('校验图片头、10MB上限及文件白名单', () {
    expect(
      () => ChatPickedAttachment(
        name: 'fake.png',
        bytes: Uint8List.fromList([1, 2]),
        isImage: true,
      ),
      throwsFormatException,
    );
    expect(
      () => ChatPickedAttachment.validateSize(10 * 1024 * 1024 + 1),
      throwsFormatException,
    );
    expect(
      () => ChatPickedAttachment.validateName('run.exe', false),
      throwsFormatException,
    );
    expect(
      () => ChatPickedAttachment.validateName('文档.pdf', false),
      returnsNormally,
    );
  });

  test('同 E-App 上传、发送、读取图片和文件；下载无凭据且拒绝重定向', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final base = 'http://127.0.0.1:${server.port}/prod-api';
    final client = ApiClient(baseUrl: base);
    addTearDown(() async {
      client.close();
      await server.close(force: true);
    });
    final requests = <String>[];
    final sent = <Map<String, dynamic>>[];
    final errors = <Object>[];
    server.listen((request) async {
      try {
        requests.add(request.uri.path);
        if (request.uri.path.contains('/profile/')) {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            isNull,
          );
          if (request.uri.path.endsWith('redirect')) {
            request.response.statusCode = 302;
            request.response.headers.set('location', '$base/profile/final');
          } else {
            request.response.headers.contentType = ContentType.binary;
            request.response.add([1, 2, 3]);
          }
        } else {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer synthetic',
          );
          request.response.headers.contentType = ContentType.json;
          if (request.uri.path.endsWith('/common/upload')) {
            final multipart = await utf8.decoder.bind(request).join();
            expect(multipart, contains('filename="合成.txt"'));
            expect(multipart, contains('synthetic file'));
            request.response.write(
              jsonEncode({'code': 200, 'fileName': '/profile/upload/file.txt'}),
            );
          } else if (request.method == 'POST') {
            sent.add(
              Map<String, dynamic>.from(
                jsonDecode(await utf8.decoder.bind(request).join()) as Map,
              ),
            );
            request.response.write(jsonEncode({'code': 200, 'sessionId': 8}));
          } else {
            request.response.write(
              jsonEncode({
                'code': 200,
                'data': [
                  {
                    'messageId': 1,
                    'senderId': 12,
                    'type': 2,
                    'content': 'photo.png',
                    'attachmentUrl': '/profile/photo.png',
                    'isMine': true,
                    'sendTime': '2026-11-17 12:00:00',
                  },
                  {
                    'messageId': 2,
                    'senderId': 11,
                    'type': 3,
                    'content': '合成.txt',
                    'attachmentUrl': '/profile/file.txt',
                    'isMine': false,
                    'sendTime': '2026-11-17 12:00:00',
                  },
                ],
              }),
            );
          }
        }
      } catch (error) {
        errors.add(error);
      }
      await request.response.close();
    });
    final api = MessageApi(client);
    final picked = ChatPickedAttachment(
      name: '合成.txt',
      bytes: Uint8List.fromList(utf8.encode('synthetic file')),
      isImage: false,
    );
    final uploaded = await api.uploadAttachment('synthetic', picked);
    await api.sendAttachment('synthetic', 8, uploaded);
    expect(sent.single, {
      'sessionId': 8,
      'type': 3,
      'content': '合成.txt',
      'attachmentUrl': '/profile/upload/file.txt',
    });
    final messages = await api.fetchHrChat('synthetic', 8);
    expect(messages.map((m) => m.messageId), [2, 1]);
    expect(messages.last.mine, isTrue);
    expect(messages.last.attachmentUrl, '/profile/photo.png');
    expect(messages.last.createdAt.year, 2026);
    expect(await api.downloadAttachment('/profile/file.txt'), [1, 2, 3]);
    await expectLater(
      api.downloadAttachment('/profile/redirect'),
      throwsA(isA<ApiException>()),
    );
    expect(requests, isNot(contains('/prod-api/profile/final')));
    expect(errors, isEmpty);
  });
}
