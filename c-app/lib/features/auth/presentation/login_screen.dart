import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_theme.dart';
import 'auth_controller.dart';

enum _LoginMode { sms, password }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();
  final _phoneController = TextEditingController();
  final _smsCodeController = TextEditingController();

  _LoginMode _mode = _LoginMode.password;
  bool _obscurePassword = true;
  bool _agreed = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller.autoLoadCaptcha) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.refreshCaptcha();
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _BrandHeader(),
                      const SizedBox(height: 34),
                      Text(
                        '欢迎回来',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '登录后开启你的高效求职之旅',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                      ),
                      const SizedBox(height: 28),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _LoginTabs(
                                mode: _mode,
                                onChanged: (mode) {
                                  widget.controller.clearError();
                                  setState(() => _mode = mode);
                                },
                              ),
                              const SizedBox(height: 24),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: _mode == _LoginMode.password
                                    ? _buildPasswordForm()
                                    : _buildSmsForm(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '还没有账号？',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: () => _showNotReady('注册功能将在下一阶段接入'),
                            child: const Text('立即注册'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPasswordForm() {
    final captcha = widget.controller.captcha;
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('password-form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(
              labelText: '手机号 / 登录账号',
              hintText: '请输入登录账号',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return '请输入登录账号';
              if (value.trim().length < 2) return '登录账号格式不正确';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: captcha?.enabled == true
                ? TextInputAction.next
                : TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) {
              if (captcha?.enabled != true) _submitPassword();
            },
            decoration: InputDecoration(
              labelText: '密码',
              hintText: '请输入登录密码',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return '请输入登录密码';
              if (value.length < 5) return '密码长度不能少于 5 位';
              return null;
            },
          ),
          if (captcha?.enabled == true) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _captchaController,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submitPassword(),
                    decoration: const InputDecoration(
                      labelText: '图形验证码',
                      hintText: '请输入验证码',
                      prefixIcon: Icon(Icons.verified_user_outlined),
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? '请输入验证码' : null,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 116,
                  height: 56,
                  child: Material(
                    color: AppColors.canvas,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: const BorderSide(color: AppColors.hairline),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: widget.controller.busy
                          ? null
                          : widget.controller.refreshCaptcha,
                      child: captcha?.imageBytes == null
                          ? const Center(
                              child: Icon(
                                Icons.refresh,
                                color: AppColors.interactive,
                              ),
                            )
                          : Image.memory(
                              captcha!.imageBytes!,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (widget.controller.errorMessage != null) ...[
            const SizedBox(height: 14),
            _ErrorBanner(message: widget.controller.errorMessage!),
          ],
          const SizedBox(height: 8),
          _AgreementRow(
            agreed: _agreed,
            onChanged: (value) => setState(() => _agreed = value),
            onOpen: _showPolicy,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: widget.controller.busy ? null : _submitPassword,
            child: widget.controller.busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('登录'),
          ),
        ],
      ),
    );
  }

  Widget _buildSmsForm() {
    return Column(
      key: const ValueKey('sms-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: '手机号',
            hintText: '请输入手机号',
            prefixIcon: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Center(widthFactor: 1, child: Text('+86')),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _smsCodeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: '短信验证码',
            hintText: '请输入 6 位验证码',
            prefixIcon: const Icon(Icons.sms_outlined),
            counterText: '',
            suffixIcon: TextButton(
              onPressed: () => _showNotReady('后端短信验证码接口尚未接入'),
              child: const Text('获取验证码'),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _InfoBanner(message: '当前后端仅提供账号密码认证。短信验证码登录将在短信服务接入后开放。'),
        const SizedBox(height: 8),
        _AgreementRow(
          agreed: _agreed,
          onChanged: (value) => setState(() => _agreed = value),
          onOpen: _showPolicy,
        ),
        const SizedBox(height: 16),
        const FilledButton(onPressed: null, child: Text('登录')),
      ],
    );
  }

  Future<void> _submitPassword() async {
    FocusManager.instance.primaryFocus?.unfocus();
    widget.controller.clearError();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_agreed) {
      _showNotReady('请先阅读并同意用户协议和隐私政策');
      return;
    }

    final success = await widget.controller.signIn(
      username: _usernameController.text,
      password: _passwordController.text,
      captchaCode: _captchaController.text,
    );
    if (!mounted || !success) return;
    TextInput.finishAutofillContext();
  }

  void _showPolicy(String title) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text('协议正文将在内容审核完成后接入。当前登录仅用于本地开发和接口联调。'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('我知道了'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotReady(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.interactive, AppColors.brand],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppColors.interactive.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '智聘助手',
              style: TextStyle(
                color: AppColors.brand,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'AI 求职服务',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

class _LoginTabs extends StatelessWidget {
  const _LoginTabs({required this.mode, required this.onChanged});

  final _LoginMode mode;
  final ValueChanged<_LoginMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _LoginTab(
              label: '验证码登录',
              selected: mode == _LoginMode.sms,
              onTap: () => onChanged(_LoginMode.sms),
            ),
          ),
          Expanded(
            child: _LoginTab(
              label: '密码登录',
              selected: mode == _LoginMode.password,
              onTap: () => onChanged(_LoginMode.password),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginTab extends StatelessWidget {
  const _LoginTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.canvas : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AppColors.brand : AppColors.muted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _AgreementRow extends StatelessWidget {
  const _AgreementRow({
    required this.agreed,
    required this.onChanged,
    required this.onOpen,
  });

  final bool agreed;
  final ValueChanged<bool> onChanged;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 32,
          height: 40,
          child: Checkbox(
            value: agreed,
            onChanged: (value) => onChanged(value ?? false),
          ),
        ),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('我已阅读并同意', style: Theme.of(context).textTheme.bodySmall),
              TextButton(
                onPressed: () => onOpen('用户协议'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('《用户协议》'),
              ),
              Text('和', style: Theme.of(context).textTheme.bodySmall),
              TextButton(
                onPressed: () => onOpen('隐私政策'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('《隐私政策》'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.interactive,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.bodySoft, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
