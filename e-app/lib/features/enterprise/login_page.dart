import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../theme/app_theme.dart';

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
  final _captcha = TextEditingController();

  bool _checking = true;
  bool _busy = false;
  bool _authenticated = false;
  bool _obscurePassword = true;
  String? _error;
  bool _smsMode = false;
  bool _agreed = false;
  bool _captchaLoading = true;
  bool _captchaEnabled = false;
  int _captchaRequest = 0;
  String? _captchaUuid;
  Uint8List? _captchaBytes;
  String? _captchaError;

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
    _captcha.dispose();
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
    if (mounted && !_authenticated && _error == null) {
      await _loadCaptcha();
    }
  }

  Future<void> _loadCaptcha() async {
    if (_busy) return;
    final request = ++_captchaRequest;
    setState(() {
      _captchaLoading = true;
      _captchaError = null;
      _captchaUuid = null;
      _captchaBytes = null;
      _captcha.clear();
    });
    try {
      final response = await _client.get('/captchaImage');
      if (!mounted || request != _captchaRequest) return;
      final enabled = response['captchaEnabled'];
      if (enabled is! bool) throw const FormatException('验证码配置无效');
      Uint8List? bytes;
      String? uuid;
      if (enabled) {
        uuid = response['uuid']?.toString().trim();
        final image = response['img'];
        if (uuid == null || uuid.isEmpty || image is! String || image.isEmpty) {
          throw const FormatException('验证码响应不完整');
        }
        bytes = base64Decode(image);
        if (bytes.isEmpty) throw const FormatException('验证码图片为空');
        final decoded = await decodeImageFromList(bytes);
        decoded.dispose();
      }
      if (!mounted || request != _captchaRequest) return;
      setState(() {
        _captchaEnabled = enabled;
        _captchaUuid = uuid;
        _captchaBytes = bytes;
      });
    } on ApiException catch (error) {
      if (mounted && request == _captchaRequest) {
        setState(() => _captchaError = error.message);
      }
    } catch (_) {
      if (mounted && request == _captchaRequest) {
        setState(() => _captchaError = '图形验证码加载失败，请重试');
      }
    } finally {
      if (mounted && request == _captchaRequest) {
        setState(() => _captchaLoading = false);
      }
    }
  }

  Future<void> _login() async {
    if (_busy || _smsMode || _captchaLoading || _captchaError != null) {
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    var authenticated = false;
    try {
      // 图形验证码开启时使用后端已有的验证码校验分支。
      final response = await _client.post(
        '/login',
        body: {
          'loginType': _captchaEnabled ? 'password' : 'account_password',
          'username': _username.text.trim(),
          'password': _password.text,
          if (_captchaEnabled) 'code': _captcha.text.trim(),
          if (_captchaEnabled) 'uuid': _captchaUuid,
        },
      );
      final token = response['token']?.toString();
      if (token == null || token.isEmpty) {
        throw const ApiException('登录响应未包含令牌');
      }
      await _client.get('/getInfo', token: token);
      await _storage.write(key: _tokenKey, value: token);
      authenticated = true;
      if (mounted) setState(() => _authenticated = true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '保存登录状态失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && !authenticated && _captchaEnabled) {
      await _loadCaptcha();
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
    if (mounted && !_authenticated && _error == null) {
      await _loadCaptcha();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const _LoginLayout(
        title: '正在连接工作台',
        subtitle: '正在检查企业账号登录状态',
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_authenticated) {
      return widget.authenticatedBuilder(context, _logout);
    }
    if (_error != null && _username.text.isEmpty && !_busy) {
      return _LoginLayout(
        title: '欢迎回来',
        subtitle: '登录后开启高效招聘与人才管理',
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  color: AppColors.textMuted,
                  size: 36,
                ),
                const SizedBox(height: 16),
                _LoginError(message: _error!),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _restoreSession,
                  child: const Text('重试'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() => _error = null);
                    unawaited(_loadCaptcha());
                  },
                  child: const Text('使用其他账号登录'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _LoginLayout(
      title: '欢迎回来',
      subtitle: '登录后开启高效招聘与人才管理',
      footer: const _RegistrationPrompt(),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    for (final sms in [true, false])
                      Expanded(
                        child: Semantics(
                          selected: _smsMode == sms,
                          child: TextButton(
                            key: ValueKey(
                              sms ? 'login-mode-sms' : 'login-mode-password',
                            ),
                            onPressed: _busy
                                ? null
                                : () {
                                    FocusScope.of(context).unfocus();
                                    setState(() => _smsMode = sms);
                                  },
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              foregroundColor: _smsMode == sms
                                  ? AppColors.brand
                                  : AppColors.textMuted,
                              backgroundColor: _smsMode == sms
                                  ? AppColors.canvas
                                  : AppColors.background,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: Text(
                              sms ? '验证码登录' : '密码登录',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: _smsMode == sms
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_smsMode)
                const _SmsLoginPreview()
              else
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        key: const ValueKey('enterprise-login-username'),
                        controller: _username,
                        enabled: !_busy,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        decoration: _loginInputDecoration(
                          label: '企业账号',
                          icon: Icons.person_outline_rounded,
                        ),
                        validator: (text) => text == null || text.trim().isEmpty
                            ? '请输入企业账号'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('enterprise-login-password'),
                        controller: _password,
                        enabled: !_busy,
                        obscureText: _obscurePassword,
                        textInputAction: _captchaEnabled
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_captchaEnabled) unawaited(_login());
                        },
                        autofillHints: const [AutofillHints.password],
                        decoration:
                            _loginInputDecoration(
                              label: '密码',
                              icon: Icons.lock_outline_rounded,
                            ).copyWith(
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                                onPressed: _busy
                                    ? null
                                    : () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.textMuted,
                                  size: 22,
                                ),
                              ),
                            ),
                        validator: (text) =>
                            text == null || text.isEmpty ? '请输入密码' : null,
                      ),
                      if (_captchaEnabled &&
                          !_captchaLoading &&
                          _captchaError == null) ...[
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact =
                                constraints.maxWidth < 260 ||
                                MediaQuery.textScalerOf(context).scale(1) > 1.3;
                            final input = TextFormField(
                              key: const ValueKey('enterprise-login-captcha'),
                              controller: _captcha,
                              enabled: !_busy,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _login(),
                              decoration: _loginInputDecoration(
                                label: '图形验证码',
                                icon: Icons.verified_user_outlined,
                              ),
                              validator: (text) =>
                                  text == null || text.trim().isEmpty
                                  ? '请输入图形验证码'
                                  : null,
                            );
                            final image = Semantics(
                              button: true,
                              label: '刷新图形验证码',
                              child: Tooltip(
                                message: '点击刷新图形验证码',
                                child: Material(
                                  color: AppColors.canvas,
                                  shape: RoundedRectangleBorder(
                                    side: const BorderSide(
                                      color: AppColors.hairline,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    key: const ValueKey(
                                      'enterprise-login-captcha-refresh',
                                    ),
                                    onTap: _busy ? null : _loadCaptcha,
                                    child: SizedBox(
                                      width: 116,
                                      height: 56,
                                      child: Image.memory(
                                        _captchaBytes!,
                                        fit: BoxFit.contain,
                                        excludeFromSemantics: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  input,
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: image,
                                  ),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: input),
                                const SizedBox(width: 12),
                                image,
                              ],
                            );
                          },
                        ),
                      ],
                      if (_captchaLoading) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                        const SizedBox(height: 8),
                        const Text(
                          '正在加载登录验证…',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (_captchaError != null) ...[
                        const SizedBox(height: 16),
                        _LoginError(message: _captchaError!),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            key: const ValueKey(
                              'enterprise-login-captcha-retry',
                            ),
                            onPressed: _loadCaptcha,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('重新加载验证码'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _LoginAgreement(
                        agreed: _agreed,
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _agreed = value),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _LoginError(message: _error!),
                      ],
                      const SizedBox(height: 8),
                      FilledButton(
                        key: const ValueKey('enterprise-login-submit'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: AppColors.interactive,
                          foregroundColor: AppColors.canvas,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed:
                            _busy || _captchaLoading || _captchaError != null
                            ? null
                            : _login,
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('登录'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginCheckbox extends StatelessWidget {
  const _LoginCheckbox({
    required this.checkboxKey,
    required this.value,
    required this.onChanged,
  });

  final Key checkboxKey;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 44,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Center(
        child: Transform.scale(
          scale: .8,
          child: Checkbox(
            key: checkboxKey,
            value: value,
            activeColor: AppColors.interactive,
            checkColor: AppColors.canvas,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            side: const BorderSide(color: AppColors.textMuted, width: 1.5),
            onChanged: onChanged == null
                ? null
                : (selected) => onChanged!(selected ?? false),
          ),
        ),
      ),
    ),
  );
}

class _RegistrationPrompt extends StatelessWidget {
  const _RegistrationPrompt();

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    children: [
      const Text(
        '还没有账号？',
        style: TextStyle(color: AppColors.textMuted, fontSize: 14),
      ),
      TextButton(
        key: const ValueKey('enterprise-login-register'),
        onPressed: () =>
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('企业账号注册功能开发中'))),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.interactive,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        child: const Text('立即注册'),
      ),
    ],
  );
}

class _LoginAgreement extends StatelessWidget {
  const _LoginAgreement({required this.agreed, required this.onChanged});

  final bool agreed;
  final ValueChanged<bool>? onChanged;

  void _open(BuildContext context, String title) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('协议内容功能开发中，当前仅展示界面。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      _LoginCheckbox(
        checkboxKey: const ValueKey('enterprise-login-agreement'),
        value: agreed,
        onChanged: onChanged,
      ),
      Expanded(
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              '我已阅读并同意',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            TextButton(
              key: const ValueKey('enterprise-login-user-agreement'),
              onPressed: () => _open(context, '用户协议'),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 0),
                foregroundColor: AppColors.interactive,
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('《用户协议》'),
            ),
            const Text(
              '和',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            TextButton(
              key: const ValueKey('enterprise-login-privacy'),
              onPressed: () => _open(context, '隐私政策'),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 0),
                foregroundColor: AppColors.interactive,
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('《隐私政策》'),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SmsLoginPreview extends StatelessWidget {
  const _SmsLoginPreview();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const ValueKey('enterprise-login-phone'),
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        decoration: _loginInputDecoration(
          label: '手机号',
          icon: Icons.phone_iphone,
        ).copyWith(prefixText: '+86 '),
      ),
      const SizedBox(height: 16),
      TextField(
        key: const ValueKey('enterprise-login-sms-code'),
        keyboardType: TextInputType.number,
        decoration:
            _loginInputDecoration(
              label: '短信验证码',
              icon: Icons.sms_outlined,
            ).copyWith(
              suffixIconConstraints: const BoxConstraints(
                minWidth: 100,
                maxWidth: 100,
                minHeight: 48,
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextButton(
                  key: const ValueKey('enterprise-login-sms-send'),
                  onPressed: () => ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('短信验证码登录功能开发中'))),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.interactive,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('获取验证码'),
                  ),
                ),
              ),
            ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.interactiveSoft,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: AppColors.interactive, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '短信验证码登录功能开发中，请使用密码登录。',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const FilledButton(
        key: ValueKey('enterprise-login-sms-submit'),
        onPressed: null,
        child: Text('登录'),
      ),
    ],
  );
}

InputDecoration _loginInputDecoration({
  required String label,
  required IconData icon,
}) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
  prefixIcon: Icon(icon, color: AppColors.brand, size: 22),
  filled: true,
  fillColor: AppColors.canvas,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: const BorderSide(color: AppColors.hairline),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: const BorderSide(color: AppColors.interactive, width: 1.5),
  ),
);

class _LoginLayout extends StatelessWidget {
  const _LoginLayout({
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.interactive,
                              AppColors.brand,
                              AppColors.brandDeep,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.canvas,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '智能面试官',
                            style: TextStyle(
                              color: AppColors.brand,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '企业招聘服务',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                child,
                if (footer != null) ...[const SizedBox(height: 16), footer!],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _LoginError extends StatelessWidget {
  const _LoginError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.error.withValues(alpha: .15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
