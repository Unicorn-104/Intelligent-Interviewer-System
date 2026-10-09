import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _captcha = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    widget.controller.loadCaptcha();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _captcha.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.controller.login(
      username: _username.text,
      password: _password.text,
      code: _captcha.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Scaffold(
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
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.brandDeep,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.business_center_outlined, color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 28),
                      Text('企业招聘工作台', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      const Text('登录后管理岗位、候选人、面试与沟通', style: TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _username,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: '账号', prefixIcon: Icon(Icons.person_outline)),
                        validator: (value) => value == null || value.trim().isEmpty ? '请输入账号' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: '密码',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty ? '请输入密码' : null,
                      ),
                      if (widget.controller.captchaEnabled) ...[
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _captcha,
                                decoration: const InputDecoration(labelText: '验证码'),
                                validator: (value) => value == null || value.trim().isEmpty ? '请输入验证码' : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: widget.controller.loadCaptcha,
                              child: Container(
                                width: 116,
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.hairline), borderRadius: BorderRadius.circular(4)),
                                child: widget.controller.captchaBytes == null
                                    ? const Icon(Icons.refresh)
                                    : Image.memory(widget.controller.captchaBytes!, fit: BoxFit.contain),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (widget.controller.error != null) ...[
                        const SizedBox(height: 12),
                        Text(widget.controller.error!, style: const TextStyle(color: AppColors.red)),
                      ],
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: widget.controller.busy ? null : _submit,
                        child: widget.controller.busy
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('登录'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
