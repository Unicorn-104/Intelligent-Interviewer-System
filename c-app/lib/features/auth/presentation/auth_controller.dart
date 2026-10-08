import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_api.dart';
import '../data/token_store.dart';
import '../domain/auth_session.dart';
import '../domain/captcha_challenge.dart';

class AuthController extends ChangeNotifier {
  factory AuthController({
    required AuthApi api,
    required TokenStore tokenStore,
    bool autoLoadCaptcha = true,
  }) => AuthController._(api, tokenStore, autoLoadCaptcha);

  AuthController._(this._api, this._tokenStore, this.autoLoadCaptcha);

  final AuthApi _api;
  final TokenStore _tokenStore;
  final bool autoLoadCaptcha;

  bool _initialized = false;
  bool _busy = false;
  AuthSession? _session;
  CaptchaChallenge? _captcha;
  String? _errorMessage;

  bool get initialized => _initialized;
  bool get busy => _busy;
  bool get isAuthenticated => _session != null;
  AuthSession? get session => _session;
  CaptchaChallenge? get captcha => _captcha;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    try {
      final token = await _tokenStore.read();
      if (token != null && token.isNotEmpty) {
        _session = await _api.getSession(token);
      }
    } catch (_) {
      await _clearTokenSafely();
      _session = null;
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> refreshCaptcha() async {
    try {
      _captcha = await _api.fetchCaptcha();
      _errorMessage = null;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = '验证码加载失败，请稍后重试';
    } finally {
      notifyListeners();
    }
  }

  Future<bool> signIn({
    required String username,
    required String password,
    String? captchaCode,
  }) async {
    if (_busy) return false;
    _busy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await _api.login(
        username: username,
        password: password,
        code: captchaCode,
        uuid: _captcha?.uuid,
      );
      final nextSession = await _api.getSession(token);
      await _tokenStore.write(token);
      _session = nextSession;
      return true;
    } on ApiException catch (error) {
      final loginError = error.message;
      if (_captcha?.enabled == true) {
        await refreshCaptcha();
      }
      _errorMessage = loginError;
      return false;
    } catch (_) {
      _errorMessage = '登录失败，请稍后重试';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    final token = _session?.token;
    _busy = true;
    notifyListeners();
    try {
      if (token != null) await _api.logout(token);
    } catch (_) {
      // 即使服务端暂时不可用，也必须清理本地会话。
    } finally {
      _session = null;
      _captcha = null;
      _errorMessage = null;
      await _clearTokenSafely();
      _busy = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _clearTokenSafely() async {
    try {
      await _tokenStore.clear();
    } catch (_) {
      // 安全存储不可用时不阻断进入登录页。
    }
  }
}
