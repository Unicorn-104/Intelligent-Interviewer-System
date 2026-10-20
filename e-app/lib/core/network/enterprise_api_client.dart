import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/app_config.dart';
import 'api_exception.dart';

/// P7 联调统一 HTTP 客户端（dio 封装，新增文件，不动现有 ApiClient）。
///
/// 职责：
/// 1. baseUrl：复用 AppConfig.apiBaseUrl（默认连接服务器 /prod-api，
///    其他环境可通过 --dart-define=API_BASE_URL 覆盖）；
/// 2. 超时：复用 AppConfig.requestTimeout（15s）；
/// 3. Token 注入：优先读取 FlutterSecureStorage（键名与 auth_controller 一致
///    `enterprise_access_token`）；无登录态时回退到 `--dart-define=DEV_TOKEN`
///    传入的联调令牌（TODO(P7): 正式接入登录流程后移除回退逻辑）；
/// 4. 统一错误处理：RuoYi AjaxResult 解包（code!=200 抛 ApiException）、
///    401 友好提示、网络异常兜底文案，页面可直接 catch ApiException 展示。
class EnterpriseApiClient {
  EnterpriseApiClient({Dio? dio}) : _dio = dio ?? _buildDio();

  static const _storage = FlutterSecureStorage();

  /// 与 auth_controller 的 Token 存储键保持一致（复用现有登录 Token）
  static const _tokenKey = 'enterprise_access_token';

  // ============================================================
  // TODO: 仅限联调，生产环境必须移除，改为真实登录流程
  // 联调兜底令牌（后端令牌有效期 30 分钟），通过
  // --dart-define=DEV_TOKEN=<token> 传入；禁止用于生产环境。
  // ============================================================
  static const _devToken = String.fromEnvironment(
    'DEV_TOKEN',
    defaultValue: '',
  );

  final Dio _dio;

  static Dio _buildDio() {
    return Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.requestTimeout,
        receiveTimeout: AppConfig.requestTimeout,
        headers: const {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.acceptHeader: 'application/json',
        },
      ),
    );
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, Object?>? query,
  }) => _request('GET', path, query: query);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?>? body,
  }) => _request('POST', path, body: body);

  Future<Map<String, dynamic>> put(String path, {Map<String, Object?>? body}) =>
      _request('PUT', path, body: body);

  Future<Map<String, dynamic>> delete(String path) => _request('DELETE', path);

  /// Uploads one document without changing the JSON request defaults.
  /// Returns the AjaxResult envelope; callers validate and map its data.
  Future<Map<String, dynamic>> uploadFile(
    String path, {
    required String filename,
    required Uint8List bytes,
    String fieldName = 'file',
    String? mimeType,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration receiveTimeout = const Duration(seconds: 180),
  }) async {
    final token = await _readToken();
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: FormData.fromMap({
          fieldName: MultipartFile.fromBytes(
            bytes,
            filename: filename,
            contentType: mimeType == null ? null : DioMediaType.parse(mimeType),
          ),
        }),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        options: Options(
          contentType: Headers.multipartFormDataContentType,
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: receiveTimeout,
          followRedirects: false,
          headers: (token == null || token.isEmpty)
              ? null
              : {HttpHeaders.authorizationHeader: 'Bearer $token'},
        ),
      );
      final decoded = response.data;
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('后端响应格式不正确');
      }
      final status = response.statusCode;
      final code = int.tryParse('${decoded['code']}');
      if (status == null || status < 200 || status >= 300 || code != 200) {
        throw _uploadFailure(status, decoded);
      }
      return decoded;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
          throw const ApiException('文档上传超时，请检查网络后重试');
        case DioExceptionType.receiveTimeout:
          throw const ApiException('文档解析等待超时，请稍后重试');
        case DioExceptionType.badResponse:
          throw _uploadFailure(
            error.response?.statusCode,
            error.response?.data,
          );
        default:
          throw const ApiException('暂时无法连接解析服务，请检查网络后重试');
      }
    }
  }

  ApiException _uploadFailure(int? status, Object? body) {
    final code = body is Map ? int.tryParse('${body['code']}') : null;
    final failure = switch (status) {
      401 || 403 || 413 || 429 => status,
      _ => code ?? status,
    };
    final fallback = switch (failure) {
      401 => '登录已过期，请重新登录',
      403 => '当前账号没有 JD 文档解析权限',
      413 => 'JD 文档过大，请选择不超过10MB的文件',
      429 => '解析请求过于频繁，请稍后重试',
      _ => '文档解析失败，请稍后重试',
    };
    final rawMessage = body is Map ? body['msg'] : null;
    final message = rawMessage is String && rawMessage.trim().isNotEmpty
        ? rawMessage
        : fallback;
    return ApiException(message, code: code, statusCode: status);
  }

  /// 读取登录令牌：SecureStorage 优先，联调兜底令牌次之
  Future<String?> _readToken() async {
    try {
      final stored = await _storage.read(key: _tokenKey);
      if (stored != null && stored.isNotEmpty) return stored;
    } catch (_) {
      // 存储读取失败时走兜底令牌
    }
    return _devToken.isEmpty ? null : _devToken;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? query,
    Map<String, Object?>? body,
  }) async {
    final token = await _readToken();
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: (token == null || token.isEmpty)
              ? null
              : {HttpHeaders.authorizationHeader: 'Bearer $token'},
        ),
      );
      final decoded = response.data;
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('后端响应格式不正确');
      }
      final code = int.tryParse('${decoded['code'] ?? response.statusCode}');
      if ((response.statusCode ?? 0) < 200 ||
          (response.statusCode ?? 0) >= 300 ||
          (code != null && code != 200)) {
        throw ApiException(
          decoded['msg']?.toString() ?? '请求失败，请稍后重试',
          code: code,
          statusCode: response.statusCode,
        );
      }
      return decoded;
    } on DioException catch (e) {
      // 401：Token 无效/过期，友好提示（联调阶段提示重新登录或刷新 DEV_TOKEN）
      if (e.response?.statusCode == 401) {
        throw ApiException('登录已过期或令牌无效，请重新登录（401）', code: 401, statusCode: 401);
      }
      throw ApiException(
        '网络异常：${e.message ?? '请检查后端服务与网络连接'}',
        statusCode: e.response?.statusCode,
      );
    } on ApiException {
      rethrow;
    }
  }
}
