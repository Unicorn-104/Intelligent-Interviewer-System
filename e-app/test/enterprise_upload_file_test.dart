import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/jd_http_fixture.dart';
import 'support/jd_import_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late JdHttpFixture http;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'enterprise_access_token': 'synthetic-jd-token',
    });
    http = JdHttpFixture();
  });
  tearDown(() => http.close());

  Future<Map<String, dynamic>> upload([String name = 'synthetic.pdf']) {
    final document = jdDocument(name);
    return http.client.uploadFile(
      '/enterprise/jd/parse-document',
      filename: document.name,
      bytes: document.bytes,
      mimeType: document.mimeType,
    );
  }

  for (final name in ['synthetic.pdf', 'synthetic.docx']) {
    test('真实 multipart 编码包含 file、文件名和 $name 的 MIME', () async {
      final document = jdDocument(name);
      final progress = <(int, int)>[];
      final response = await http.client.uploadFile(
        '/enterprise/jd/parse-document',
        filename: document.name,
        bytes: document.bytes,
        mimeType: document.mimeType,
        onSendProgress: (sent, total) => progress.add((sent, total)),
      );
      expect(response['code'], 200);
      final request = http.adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/enterprise/jd/parse-document');
      expect(request.headers['authorization'], 'Bearer synthetic-jd-token');
      expect(request.sendTimeout, const Duration(seconds: 60));
      expect(request.receiveTimeout, const Duration(seconds: 180));
      expect(request.followRedirects, isFalse);
      expect(request.contentType, startsWith('multipart/form-data'));
      final form = request.data as FormData;
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, name);
      expect(form.files.single.value.contentType.toString(), document.mimeType);
      final wire = latin1.decode(http.adapter.wireBodies.single);
      expect(wire, contains('name="file"'));
      expect(wire, contains('filename="$name"'));
      expect(wire, contains(document.mimeType));
      expect(wire, contains('%PDF-'));
      expect(progress, isNotEmpty);
      expect(progress.last.$1, http.adapter.wireBodies.single.length);
      expect(progress.last.$2, progress.last.$1);
    });
  }

  test('上传请求不改变普通 JSON 请求的内容类型和15秒超时', () async {
    await upload();
    await http.client.post('/synthetic-json', body: {'value': 1});
    final ordinary = http.adapter.requests.last;
    expect(ordinary.contentType, Headers.jsonContentType);
    expect(ordinary.receiveTimeout, const Duration(seconds: 15));
    expect(jsonDecode(utf8.decode(http.adapter.wireBodies.last)), {'value': 1});
  });

  test('没有令牌时不注入伪造的 Authorization', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await upload();
    expect(http.adapter.requests.single.headers['authorization'], isNull);
  });

  for (final status in [400, 401, 403, 413, 429, 500]) {
    test('HTTP $status 保留状态和后端提示，不自动重试', () async {
      http.adapter.status = status;
      http.adapter.body = {'code': status, 'msg': '合成错误 $status'};
      await expectLater(
        upload(),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', status)
              .having((error) => error.message, 'message', '合成错误 $status'),
        ),
      );
      expect(http.adapter.requests, hasLength(1));
    });
  }

  for (final code in [401, 403, 500]) {
    test('HTTP 200 但业务 code=$code 仍失败', () async {
      http.adapter.body = {'code': code, 'msg': '合成业务错误'};
      await expectLater(
        upload(),
        throwsA(
          isA<ApiException>()
              .having((error) => error.code, 'code', code)
              .having((error) => error.message, 'message', '合成业务错误'),
        ),
      );
    });
  }

  for (final type in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  ]) {
    test('$type 使用对应的超时提示', () async {
      http.adapter.failure = type;
      await expectLater(
        upload(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains(
              type == DioExceptionType.receiveTimeout ? '解析等待超时' : '上传超时',
            ),
          ),
        ),
      );
    });
  }

  test('已取消的上传保持取消语义且不发送请求', () async {
    final token = CancelToken()..cancel('Synthetic cancellation');
    await expectLater(
      http.client.uploadFile(
        '/enterprise/jd/parse-document',
        filename: 'synthetic.pdf',
        bytes: jdDocument().bytes,
        cancelToken: token,
      ),
      throwsA(
        isA<DioException>().having(CancelToken.isCancel, 'isCancel', isTrue),
      ),
    );
    expect(http.adapter.requests, isEmpty);
  });
}
