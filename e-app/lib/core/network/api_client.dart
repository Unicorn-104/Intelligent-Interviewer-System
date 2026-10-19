import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../config/app_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  Future<Map<String, dynamic>> get(String path, {String? token, Map<String, Object?>? query}) =>
      _request('GET', path, token: token, query: query);
  Future<Map<String, dynamic>> post(String path, {String? token, Map<String, Object?>? body}) =>
      _request('POST', path, token: token, body: body);
  Future<Map<String, dynamic>> put(String path, {String? token, Map<String, Object?>? body}) =>
      _request('PUT', path, token: token, body: body);
  Future<Map<String, dynamic>> patch(String path, {String? token, Map<String, Object?>? body}) =>
      _request('PATCH', path, token: token, body: body);
  Future<Map<String, dynamic>> delete(String path, {String? token}) =>
      _request('DELETE', path, token: token);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    String? token,
    Map<String, Object?>? query,
    Map<String, Object?>? body,
  }) async {
    final base = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final params = query?.map((key, value) => MapEntry(key, value?.toString()))
      ?..removeWhere((_, value) => value == null || value.isEmpty);
    final uri = params == null ? base : base.replace(queryParameters: params);
    try {
      final request = switch (method) {
        'GET' => await _client.getUrl(uri),
        'POST' => await _client.postUrl(uri),
        'PUT' => await _client.putUrl(uri),
        'PATCH' => await _client.patchUrl(uri),
        'DELETE' => await _client.deleteUrl(uri),
        _ => throw const ApiException('不支持的请求方法'),
      };
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close().timeout(AppConfig.requestTimeout);
      final responseText = await utf8.decoder.bind(response).join().timeout(AppConfig.requestTimeout);
      final decoded = responseText.isEmpty ? <String, dynamic>{} : jsonDecode(responseText);
      if (decoded is! Map<String, dynamic>) throw const ApiException('后端响应格式不正确');
      final code = int.tryParse('${decoded['code'] ?? response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300 || (code != null && code != 200)) {
        throw ApiException(decoded['msg']?.toString() ?? '请求失败，请稍后重试', code: code, statusCode: response.statusCode);
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('连接后端超时，请稍后重试');
    } on SocketException {
      throw const ApiException('无法连接后端服务，请检查网络');
    } on FormatException {
      throw const ApiException('后端响应无法解析');
    } catch (_) {
      throw const ApiException('网络请求失败，请稍后重试');
    }
  }

  void close() => _client.close(force: true);
}
