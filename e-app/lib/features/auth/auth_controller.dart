import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._client);

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'enterprise_access_token';
  final ApiClient _client;

  bool initialized = false;
  bool busy = false;
  String? token;
  String? error;
  String? captchaUuid;
  Uint8List? captchaBytes;
  bool captchaEnabled = false;
  Map<String, dynamic> user = const {};

  bool get authenticated => token != null && token!.isNotEmpty;
  String get displayName =>
      user['nickName']?.toString() ?? user['userName']?.toString() ?? '招聘经理';

  Future<void> initialize() async {
    try {
      token = await _storage.read(key: _tokenKey);
      if (authenticated) await _loadUser();
    } catch (_) {
      await _clearSession();
    } finally {
      initialized = true;
      notifyListeners();
    }
  }

  Future<void> loadCaptcha() async {
    try {
      final response = await _client.get('/captchaImage');
      captchaEnabled = response['captchaEnabled'] != false;
      captchaUuid = response['uuid']?.toString();
      final image = response['img']?.toString();
      captchaBytes = image == null || image.isEmpty ? null : base64Decode(image);
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }
    notifyListeners();
  }

  Future<bool> login({required String username, required String password, String? code}) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final response = await _client.post('/login', body: {
        'username': username.trim(),
        'password': password,
        if (captchaEnabled) 'code': code?.trim(),
        if (captchaEnabled) 'uuid': captchaUuid,
      });
      token = response['token']?.toString();
      if (!authenticated) throw const ApiException('登录响应未包含 Token');
      await _loadUser();
      await _storage.write(key: _tokenKey, value: token);
      return true;
    } on ApiException catch (e) {
      error = e.message;
      if (captchaEnabled) await loadCaptcha();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _loadUser() async {
    final response = await _client.get('/getInfo', token: token);
    user = Map<String, dynamic>.from(response['user'] as Map? ?? const {});
  }

  Future<void> logout() async {
    final currentToken = token;
    busy = true;
    notifyListeners();
    try {
      if (currentToken != null) await _client.post('/logout', token: currentToken);
    } catch (_) {
      // 本地会话仍须清理，避免用户被锁在失效登录态。
    } finally {
      await _clearSession();
      busy = false;
      notifyListeners();
    }
  }

  Future<void> expire() async {
    error = '登录已失效，请重新登录';
    await _clearSession();
    notifyListeners();
  }

  Future<void> _clearSession() async {
    token = null;
    user = const {};
    await _storage.delete(key: _tokenKey);
  }
}
