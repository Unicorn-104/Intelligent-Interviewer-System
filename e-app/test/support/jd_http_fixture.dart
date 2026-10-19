import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:enterprise_recruiter/core/network/enterprise_api_client.dart';

class JdHttpFixture {
  JdHttpFixture() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://synthetic.invalid',
        contentType: Headers.jsonContentType,
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    dio.httpClientAdapter = adapter;
    client = EnterpriseApiClient(dio: dio);
  }

  final adapter = RecordingJdHttpAdapter();
  late final Dio dio;
  late final EnterpriseApiClient client;

  void close() => dio.close(force: true);
}

class RecordingJdHttpAdapter implements HttpClientAdapter {
  int status = 200;
  Object? body = {'code': 200, 'data': <String, Object?>{}};
  DioExceptionType? failure;
  final requests = <RequestOptions>[];
  final wireBodies = <Uint8List>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final bytes = BytesBuilder(copy: false);
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.add(chunk);
      }
    }
    wireBodies.add(bytes.takeBytes());
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure!);
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
