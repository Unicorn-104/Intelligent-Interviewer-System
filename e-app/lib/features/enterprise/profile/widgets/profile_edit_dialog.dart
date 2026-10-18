import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_theme.dart';
import '../data/profile_data_source.dart';
import '../models/profile_view_data.dart';

class ProfileEditDialog extends StatefulWidget {
  const ProfileEditDialog({
    super.key,
    required this.profile,
    required this.onSave,
    this.focusField,
  });
  final EnterpriseProfile profile;
  final Future<void> Function(Map<String, Object?>) onSave;
  final String? focusField;
  @override
  State<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<ProfileEditDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late String _sex;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final initial = widget.profile.editable;
    _fields = {
      for (final key in ['nickName', 'phonenumber', 'email', 'remark'])
        key: TextEditingController(text: '${initial[key]}'),
    };
    _sex = '${initial['sex']}';
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final body = <String, Object?>{
      for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
      'sex': _sex,
    };
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(body);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = profileError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String key,
    String label, {
    int? maxLength,
    TextInputType? keyboard,
    int lines = 1,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: Key('profile-edit-$key'),
      controller: _fields[key],
      enabled: !_saving,
      autofocus: widget.focusField == key,
      keyboardType: keyboard,
      maxLength: maxLength,
      maxLines: lines,
      decoration: InputDecoration(labelText: label, counterText: ''),
      validator: validator,
      inputFormatters: key == 'phonenumber'
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
    ),
  );
  @override
  Widget build(BuildContext context) => _ProfileDialogFrame(
    title: '编辑个人资料',
    busy: _saving,
    error: _error,
    onSave: _save,
    saveKey: const Key('profile-edit-save'),
    child: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '登录账号：${widget.profile.account}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _field(
            'nickName',
            '姓名 / 昵称',
            maxLength: 30,
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请填写姓名或昵称' : null,
          ),
          _field(
            'phonenumber',
            '手机号',
            maxLength: 11,
            keyboard: TextInputType.phone,
            validator: (value) =>
                value != null &&
                    value.isNotEmpty &&
                    !RegExp(r'^1[3-9]\d{9}$').hasMatch(value)
                ? '请输入有效的11位手机号'
                : null,
          ),
          _field(
            'email',
            '邮箱',
            maxLength: 50,
            keyboard: TextInputType.emailAddress,
            validator: (value) =>
                value != null &&
                    value.trim().isNotEmpty &&
                    !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(value.trim())
                ? '请输入有效邮箱地址'
                : null,
          ),
          DropdownButtonFormField<String>(
            key: const Key('profile-edit-sex'),
            initialValue: _sex,
            decoration: const InputDecoration(labelText: '性别'),
            items: const [
              DropdownMenuItem(value: '0', child: Text('男')),
              DropdownMenuItem(value: '1', child: Text('女')),
              DropdownMenuItem(value: '2', child: Text('未填写')),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) setState(() => _sex = value);
                  },
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(labelText: '所属部门'),
            child: Text(
              widget.profile.department,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          _field('remark', '个人简介', maxLength: 500, lines: 3),
        ],
      ),
    ),
  );
}

class ProfilePasswordDialog extends StatefulWidget {
  const ProfilePasswordDialog({super.key, required this.onSave});
  final Future<void> Function(String, String) onSave;
  @override
  State<ProfilePasswordDialog> createState() => _ProfilePasswordDialogState();
}

class _ProfilePasswordDialogState extends State<ProfilePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _old = TextEditingController(),
      _new = TextEditingController(),
      _confirm = TextEditingController();
  final _visible = <String, bool>{};
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_old.text, _new.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = profileError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String id,
    String label,
    TextEditingController controller,
    String? Function(String?) validator,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: Key('profile-password-$id'),
      controller: controller,
      enabled: !_saving,
      obscureText: !(_visible[id] ?? false),
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          tooltip: (_visible[id] ?? false) ? '隐藏密码' : '显示密码',
          onPressed: _saving
              ? null
              : () => setState(() => _visible[id] = !(_visible[id] ?? false)),
          icon: Icon(
            (_visible[id] ?? false)
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
      validator: validator,
    ),
  );
  @override
  Widget build(BuildContext context) => _ProfileDialogFrame(
    title: '修改登录密码',
    busy: _saving,
    error: _error,
    onSave: _save,
    saveKey: const Key('profile-password-save'),
    child: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            'old',
            '旧密码',
            _old,
            (value) => value == null || value.isEmpty ? '请输入旧密码' : null,
          ),
          _field('new', '新密码', _new, (value) {
            if (value == null || value.length < 6 || value.length > 20) {
              return '新密码长度为6至20个字符';
            }
            if (value == _old.text) return '新密码不能与旧密码相同';
            return null;
          }),
          _field(
            'confirm',
            '确认新密码',
            _confirm,
            (value) => value != _new.text || value == null || value.isEmpty
                ? '两次新密码不一致'
                : null,
          ),
        ],
      ),
    ),
  );
}

class _ProfileDialogFrame extends StatelessWidget {
  const _ProfileDialogFrame({
    required this.title,
    required this.busy,
    required this.child,
    required this.onSave,
    required this.saveKey,
    this.error,
  });
  final String title;
  final bool busy;
  final Widget child;
  final VoidCallback onSave;
  final Key saveKey;
  final String? error;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Dialog(
      backgroundColor: AppColors.canvas,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(child: SingleChildScrollView(child: child)),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: busy ? null : () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: saveKey,
                      onPressed: busy ? null : onSave,
                      child: Text(busy ? '保存中…' : '保存修改'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
