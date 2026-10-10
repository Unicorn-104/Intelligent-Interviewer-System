import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';

/// 使用企业端原有的令牌存储键；已有业务 API 会从同一位置读取令牌。
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.authenticatedBuilder,
    this.client,
    this.storage,
  });

  final ApiClient? client;
  final FlutterSecureStorage? storage;

  final Widget Function(BuildContext context, VoidCallback onLogout)
  authenticatedBuilder;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  FlutterSecureStorage get _storage =>
      widget.storage ?? const FlutterSecureStorage();
  static const _tokenKey = 'enterprise_access_token';

  late final ApiClient _client;
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _checking = true;
  bool _busy = false;
  bool _authenticated = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? ApiClient();
    _restoreSession();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    if (widget.client == null) _client.close();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null || token.isEmpty) {
        if (mounted) setState(() => _authenticated = false);
      } else {
        try {
          // 已有令牌优先使用；过期时清理，避免所有业务页持续显示 401。
          await _client.get('/getInfo', token: token);
          if (mounted) setState(() => _authenticated = true);
        } on ApiException catch (error) {
          if (error.isUnauthorized) {
            await _storage.delete(key: _tokenKey);
            if (mounted) setState(() => _authenticated = false);
          } else {
            rethrow;
          }
        }
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '无法读取登录状态，请重试');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _login() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // 后端 account_password 分支支持账号密码登录，无须图形验证码。
      final response = await _client.post(
        '/login',
        body: {
          'loginType': 'account_password',
          'username': _username.text.trim(),
          'password': _password.text,
        },
      );
      final token = response['token']?.toString();
      if (token == null || token.isEmpty) {
        throw const ApiException('登录响应未包含令牌');
      }
      await _client.get('/getInfo', token: token);
      await _storage.write(key: _tokenKey, value: token);
      if (mounted) setState(() => _authenticated = true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '保存登录状态失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token != null && token.isNotEmpty) {
        try {
          await _client.post('/logout', token: token);
        } catch (_) {
          // 即使后端已使令牌失效，仍需清除本地登录状态。
        }
      }
      await _storage.delete(key: _tokenKey);
      if (mounted) {
        _password.clear();
        setState(() {
          _authenticated = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '退出失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_authenticated) {
      return widget.authenticatedBuilder(context, _logout);
    }
    if (_error != null && _username.text.isEmpty && !_busy) {
      // 校验已有令牌时网络中断，保留令牌供用户重试。
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _restoreSession,
                  child: const Text('重试'),
                ),
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('使用其他账号登录'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('企业端登录')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '智能面试官',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _username,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(labelText: '企业账号'),
                      validator: (text) => text == null || text.trim().isEmpty
                          ? '请输入企业账号'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      onFieldSubmitted: (_) => _login(),
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: '密码',
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (text) =>
                          text == null || text.isEmpty ? '请输入密码' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _login,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('登录'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
