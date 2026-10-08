import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../config/app_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  Future<Map<String, dynamic>> get(String path, {String? token}) {
    return _request('GET', path, token: token);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) {
    return _request('POST', path, body: body, token: token);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) {
    return _request('PUT', path, body: body, token: token);
  }

  Future<Map<String, dynamic>> postFile(
    String path, {
    required String filePath,
    required String fieldName,
    String? token,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final file = File(filePath);
    final fileName = file.uri.pathSegments.last;
    final boundary =
        '----intelligent-interviewer-${DateTime.now().microsecondsSinceEpoch}';

    try {
      final request = await _httpClient
          .postUrl(uri)
          .timeout(AppConfig.requestTimeout);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      request.write('--$boundary\r\n');
      request.write(
        'Content-Disposition: form-data; name="$fieldName"; '
        'filename="${fileName.replaceAll('"', '')}"\r\n',
      );
      request.write('Content-Type: ${_contentType(fileName)}\r\n\r\n');
      await request.addStream(file.openRead());
      request.write('\r\n--$boundary--\r\n');

      final response = await request.close().timeout(AppConfig.requestTimeout);
      return _readResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('连接后端超时，请检查网络后重试');
    } on SocketException {
      throw const ApiException('无法连接后端服务，请确认服务已启动');
    } on FileSystemException {
      throw const ApiException('无法读取所选文件，请重新选择');
    } on FormatException {
      throw const ApiException('后端响应无法解析');
    } catch (_) {
      throw const ApiException('文件上传失败，请稍后重试');
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');

    try {
      final request = switch (method) {
        'GET' =>
          await _httpClient.getUrl(uri).timeout(AppConfig.requestTimeout),
        'POST' =>
          await _httpClient.postUrl(uri).timeout(AppConfig.requestTimeout),
        'PUT' =>
          await _httpClient.putUrl(uri).timeout(AppConfig.requestTimeout),
        _ => throw const ApiException('不支持的请求方法'),
      };

      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(AppConfig.requestTimeout);
      return _readResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('连接后端超时，请检查网络后重试');
    } on SocketException {
      throw const ApiException('无法连接后端服务，请确认服务已启动');
    } on FormatException {
      throw const ApiException('后端响应无法解析');
    } catch (_) {
      throw const ApiException('网络请求失败，请稍后重试');
    }
  }

  Future<Map<String, dynamic>> _readResponse(
    HttpClientResponse response,
  ) async {
    final responseText = await utf8.decoder
        .bind(response)
        .join()
        .timeout(AppConfig.requestTimeout);

    if (responseText.isEmpty) {
      throw ApiException('后端返回了空响应', statusCode: response.statusCode);
    }

    final decoded = jsonDecode(responseText);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('后端响应格式不正确');
    }

    final code = _asInt(decoded['code']) ?? response.statusCode;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        code != 200) {
      throw ApiException(
        decoded['msg']?.toString() ?? '请求失败，请稍后重试',
        code: code,
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }

  String _contentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  void close() => _httpClient.close(force: true);
}
