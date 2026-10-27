import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/core/network/enterprise_api_client.dart';
import 'package:enterprise_recruiter/features/enterprise/assistant/enterprise_ai_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/assistant/enterprise_ai_events.dart';

String frame(String content, {String state = 'R', int id = 12}) =>
    'event:run\ndata:${jsonEncode({'id': id, 'sessionId': 1, 'state': state, 'content': content})}\n\n';

class SseAdapter implements HttpClientAdapter {
  SseAdapter(
    this.body, {
    this.status = 200,
    this.contentType = 'text/event-stream; charset=utf-8',
  });
  final Stream<Uint8List> body;
  final int status;
  final String contentType;
  final requests = <RequestOptions>[];
  final fetched = Completer<void>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    fetched.complete();
    return ResponseBody(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('UTF8按单字节拆包，CRLF、多行data和心跳均能解析', () async {
    final json = jsonEncode({
      'id': 12,
      'sessionId': 1,
      'state': 'R',
      'content': '中文实时输出😀',
    });
    final split = json.indexOf(',') + 1;
    final wire =
        '\uFEFF:keepalive\r\nevent:other\r\ndata:{}\r\n\r\nevent:run\r\ndata:${json.substring(0, split)}\r\ndata:${json.substring(split)}\r\n\r\n';
    final result = await decodeEnterpriseAiEvents(
      Stream.fromIterable(utf8.encode(wire).map((byte) => [byte])),
    ).toList();
    expect(result.single.content, '中文实时输出😀');
  });
  test('连接尚未结束时就能收到第一段和后续增量', () async {
    final input = StreamController<List<int>>();
    final received = <EnterpriseAiRun>[];
    final subscription = decodeEnterpriseAiEvents(input.stream)
        .listen(received.add);
    input.add(utf8.encode(frame('第一段')));
    await Future<void>.delayed(Duration.zero);
    expect(input.isClosed, isFalse);
    expect(received.single.content, '第一段');
    input.add(utf8.encode(frame('第一段，第二段')));
    await Future<void>.delayed(Duration.zero);
    expect(received.last.content, '第一段，第二段');
    input.add(utf8.encode(frame('完整回答', state: 'C')));
    await input.close();
    expect(received.last.state, 'C');
    await subscription.cancel();
  });
  test('拒绝截断帧、无效ID、非法UTF8和超长数据', () async {
    for (final wire in [
      'event:run\ndata:{}',
      frame('内容', id: 0),
      'event:run\ndata:${'x' * 100001}\n\n',
    ]) {
      await expectLater(
        decodeEnterpriseAiEvents(Stream.value(utf8.encode(wire))).toList(),
        throwsA(isA<FormatException>()),
      );
    }
    await expectLater(
      decodeEnterpriseAiEvents(Stream.value([255])).toList(),
      throwsA(isA<FormatException>()),
    );
  });
  test('流式GET使用现有认证，分段抵达即转发且可主动取消', () async {
    FlutterSecureStorage.setMockInitialValues({
      'enterprise_access_token': 'synthetic-session-not-a-credential',
    });
    final input = StreamController<Uint8List>();
    final adapter = SseAdapter(input.stream);
    final dio = Dio(BaseOptions(baseUrl: 'https://synthetic.invalid'))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final source = EnterpriseAiDataSource(
      client: EnterpriseApiClient(dio: dio),
    );
    final connection = source.openEvents(12);
    final received = <EnterpriseAiRun>[];
    final subscription = connection.events.listen(
      received.add,
      onError: (Object _) {},
    );
    await adapter.fetched.future;
    input.add(Uint8List.fromList(utf8.encode(frame('真实分包的合成内容'))));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(received.single.content, '真实分包的合成内容');
    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/enterprise/assistant/runs/12/events');
    expect(
      request.headers[HttpHeaders.authorizationHeader],
      'Bearer synthetic-session-not-a-credential',
    );
    expect(request.headers[HttpHeaders.acceptHeader], 'text/event-stream');
    expect(request.followRedirects, isFalse);
    connection.close();
    await subscription.cancel();
    await input.close();
    expect(adapter.requests.length, 1);
  });
  test('HTTP200中的业务401仍按登录失效处理，不当作流式文本', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final adapter = SseAdapter(
      Stream.value(
        Uint8List.fromList(utf8.encode('{"code":401,"msg":"synthetic"}')),
      ),
      contentType: 'application/json',
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://synthetic.invalid'))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final connection = EnterpriseAiDataSource(
      client: EnterpriseApiClient(dio: dio),
    ).openEvents(12);
    await expectLater(
      connection.events.toList(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.isUnauthorized,
          'unauthorized',
          isTrue,
        ),
      ),
    );
    connection.close();
  });
  test('损坏的活跃流能关闭连接而不产生未捕获的取消异常', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final input = StreamController<Uint8List>();
    final adapter = SseAdapter(input.stream);
    final dio = Dio(BaseOptions(baseUrl: 'https://synthetic.invalid'))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final connection = EnterpriseAiDataSource(
      client: EnterpriseApiClient(dio: dio),
    ).openEvents(12);
    final result = expectLater(
      connection.events.toList(),
      throwsA(isA<FormatException>()),
    );
    await adapter.fetched.future;
    input.add(Uint8List.fromList([255]));
    await result;
    connection.close();
    await input.close();
  });
}
