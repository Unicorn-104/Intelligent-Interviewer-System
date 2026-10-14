import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/auth_session.dart';
import '../domain/captcha_challenge.dart';

class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<CaptchaChallenge> fetchCaptcha() async {
    final json = await _client.get('/captchaImage');
    return CaptchaChallenge.fromJson(json);
  }

  Future<String> login({
    required String username,
    required String password,
    String? code,
    String? uuid,
  }) async {
    final json = await _client.post(
      '/login',
      body: {
        'username': username.trim(),
        'password': password,
        'code': code?.trim() ?? '',
        'uuid': uuid ?? '',
      },
    );
    final token = json['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const ApiException('登录成功，但后端未返回 Token');
    }
    return token;
  }

  Future<AuthSession> getSession(String token) async {
    final json = await _client.get('/getInfo', token: token);
    final user = json['user'];
    if (user is! Map<String, dynamic>) {
      throw const ApiException('未获取到用户信息');
    }

    final userId = int.tryParse(user['userId']?.toString() ?? '');
    if (userId == null) {
      throw const ApiException('用户信息缺少用户 ID');
    }

    return AuthSession(
      token: token,
      userId: userId,
      userName: user['userName']?.toString() ?? '',
      nickName:
          user['nickName']?.toString() ?? user['userName']?.toString() ?? '用户',
      avatar: user['avatar']?.toString(),
      phoneNumber: user['phonenumber']?.toString(),
    );
  }

  Future<void> logout(String token) async {
    await _client.post('/logout', token: token);
  }
}
