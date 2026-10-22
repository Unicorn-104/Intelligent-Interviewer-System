import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../config/app_config.dart';
import 'api_exception.dart';

class ApiClient {
  static final _unauthorized = StreamController<String>.broadcast();
  static Stream<String> get unauthorizedTokens => _unauthorized.stream;

  ApiClient({HttpClient? httpClient, this.baseUrl = AppConfig.apiBaseUrl})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;
  final String baseUrl;

  Stream<String> eventLines(String path, {required String token}) async* {
    HttpClientRequest? request;
    try {
      request = await _httpClient
          .getUrl(Uri.parse('$baseUrl$path'))
          .timeout(AppConfig.requestTimeout);
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final response = await request.close().timeout(AppConfig.requestTimeout);
      if (response.statusCode != 200 ||
          response.headers.contentType?.mimeType != 'text/event-stream') {
        await _readResponse(response, token: token);
        throw const ApiException('AI 连接暂不可用，请重试');
      }
      yield* response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(const Duration(seconds: 30));
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('AI 连接超时，可重新连接查看回答');
    } on SocketException {
      throw const ApiException('连接中断，可重新连接查看回答');
    } on HandshakeException {
      throw const ApiException('无法建立安全连接，请联系管理员');
    } on FormatException {
      throw const ApiException('AI 响应格式不正确，请重试');
    } finally {
      request?.abort();
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    String? token,
    Duration timeout = AppConfig.requestTimeout,
  }) {
    return _request('GET', path, token: token, timeout: timeout);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
    Duration timeout = AppConfig.requestTimeout,
  }) {
    return _request('POST', path, body: body, token: token, timeout: timeout);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    String? token,
    Duration timeout = AppConfig.requestTimeout,
  }) {
    return _request('PUT', path, body: body, token: token, timeout: timeout);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    String? token,
    Duration timeout = AppConfig.requestTimeout,
  }) {
    return _request('DELETE', path, body: body, token: token, timeout: timeout);
  }

  Future<Map<String, dynamic>> postFile(
    String path, {
    required String filePath,
    required String fieldName,
    String? token,
    Map<String, dynamic>? jsonBody,
    String jsonFieldName = 'resume',
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final file = File(filePath);
    final fileName = file.uri.pathSegments.last;
    final boundary =
        '----intelligent-interviewer-${DateTime.now().microsecondsSinceEpoch}';
    final header = utf8.encode(
      jsonBody != null
          ? '--$boundary\r\n'
                'Content-Disposition: form-data; name="$jsonFieldName"\r\n'
                'Content-Type: application/json; charset=utf-8\r\n\r\n'
                '${jsonEncode(jsonBody)}\r\n'
          : '',
    );
    final fileHeader = utf8.encode(
      '--$boundary\r\n'
      'Content-Disposition: form-data; name="$fieldName"; '
      'filename="${fileName.replaceAll('"', '')}"\r\n'
      'Content-Type: ${_contentType(fileName)}\r\n\r\n',
    );
    final footer = utf8.encode('\r\n--$boundary--\r\n');

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
      request.contentLength =
          header.length +
          fileHeader.length +
          await file.length() +
          footer.length;

      request.add(header);
      request.add(fileHeader);
      await request.addStream(file.openRead());
      request.add(footer);

      final response = await request.close().timeout(
        AppConfig.fileUploadTimeout,
      );
      return await _readResponse(
        response,
        timeout: AppConfig.fileUploadTimeout,
        token: token,
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('PDF 上传或识别超时，请稍后重试');
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
    Duration timeout = AppConfig.requestTimeout,
  }) async {
    final uri = Uri.parse('$baseUrl$path');

    try {
      final request = switch (method) {
        'GET' => await _httpClient.getUrl(uri).timeout(timeout),
        'POST' => await _httpClient.postUrl(uri).timeout(timeout),
        'PUT' => await _httpClient.putUrl(uri).timeout(timeout),
        'DELETE' => await _httpClient.deleteUrl(uri).timeout(timeout),
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

      final response = await request.close().timeout(timeout);
      return _readResponse(response, timeout: timeout, token: token);
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
    HttpClientResponse response, {
    Duration timeout = AppConfig.requestTimeout,
    String? token,
  }) async {
    if (response.statusCode == 401 && token != null && token.isNotEmpty) {
      _unauthorized.add(token);
    }
    final responseText = await utf8.decoder
        .bind(response)
        .join()
        .timeout(timeout);

    if (responseText.isEmpty) {
      throw ApiException('后端返回了空响应', statusCode: response.statusCode);
    }

    final decoded = jsonDecode(responseText);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('后端响应格式不正确');
    }

    final code = _asInt(decoded['code']) ?? response.statusCode;
    if (code == 401 &&
        response.statusCode != 401 &&
        token != null &&
        token.isNotEmpty) {
      _unauthorized.add(token);
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        code != 200) {
      final message = decoded['msg']?.toString();
      throw ApiException(
        message?.startsWith('No static resource ') == true
            ? '服务暂时不可用，请稍后重试'
            : message ?? '请求失败，请稍后重试',
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
