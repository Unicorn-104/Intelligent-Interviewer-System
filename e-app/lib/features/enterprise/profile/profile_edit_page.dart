import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_theme.dart';
import 'data/profile_data_source.dart';
import 'models/profile_view_data.dart';
import 'widgets/profile_avatar_view.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({
    super.key,
    required this.profile,
    required this.onSave,
    required this.source,
    this.focusField,
  });
  final EnterpriseProfile profile;
  final ProfileDataSource source;
  final Future<void> Function(Map<String, Object?>) onSave;
  final String? focusField;
  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late String _sex;
  bool _saving = false,
      _uploading = false,
      _avatarChanged = false,
      _allowPop = false;
  String? _error, _avatarError;
  String? _uploadedUrl;
  bool get _busy => _saving || _uploading;
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
    if (_busy || !_form.currentState!.validate()) return;
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
      if (mounted) {
        setState(() {
          _allowPop = true;
          _saving = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, true);
        });
      }
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
      enabled: !_busy,
      autofocus: widget.focusField == key,
      keyboardType: keyboard,
      maxLength: maxLength,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        counterText: key == 'remark' ? null : '',
        filled: true,
        fillColor: AppColors.canvas,
      ),
      validator: validator,
      inputFormatters: key == 'phonenumber'
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
    ),
  );
  Future<void> _avatar() async {
    if (_busy) return;
    setState(() {
      _uploading = true;
      _avatarError = null;
    });
    try {
      final file = await widget.source.pickAvatar();
      if (!mounted || file == null) return;
      final path = await widget.source.uploadAvatar(file);
      if (!mounted) return;
      setState(() {
        _uploadedUrl = widget.source.avatarUrl(path);
        _avatarChanged = true;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('头像已更新')));
    } catch (error) {
      if (mounted) setState(() => _avatarError = profileError(error));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _leave() {
    if (_busy) return;
    if (_avatarChanged && !_allowPop) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } else {
      Navigator.pop(context, _avatarChanged);
    }
  }

  Widget _avatarHeader() => Column(
    children: [
      Semantics(
        button: true,
        label: '更换头像',
        child: InkWell(
          key: const Key('profile-avatar'),
          onTap: _busy ? null : _avatar,
          borderRadius: BorderRadius.circular(48),
          child: SizedBox(
            width: 104,
            height: 104,
            child: Stack(
              children: [
                Positioned.fill(
                  right: 8,
                  bottom: 8,
                  child: ProfileAvatarView(
                    name: widget.profile.name,
                    url:
                        _uploadedUrl ??
                        widget.source.avatarUrl(widget.profile.avatar),
                    revision: _avatarChanged ? 1 : 0,
                    size: 96,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.interactive,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                    child: _uploading
                        ? const Padding(
                            padding: EdgeInsets.all(7),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.canvas,
                            ),
                          )
                        : const Icon(
                            Icons.photo_camera_outlined,
                            color: AppColors.canvas,
                            size: 18,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        '点击更换头像，支持 JPG、PNG 等图片，须小于5MB',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      const SizedBox(height: 4),
      const Text(
        '头像更换后立即保存',
        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
      if (_avatarError != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _avatarError!,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ),
    ],
  );

  Widget _section(String title, IconData icon, List<Widget> children) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(icon, size: 19, color: AppColors.muted),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );

  Widget _readonly(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.body, fontSize: 14),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && (!_avatarChanged || _allowPop),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_busy) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.primarySoft,
        title: const Text(
          '个人资料',
          style: TextStyle(color: AppColors.ink, fontSize: 20),
        ),
        leading: IconButton(
          key: const Key('profile-edit-back'),
          tooltip: '返回',
          onPressed: _busy ? null : _leave,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 21),
        ),
        actions: [
          TextButton(onPressed: _busy ? null : _leave, child: const Text('取消')),
        ],
      ),
      body: SingleChildScrollView(
        key: const Key('profile-edit-scroll'),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.primarySoft, AppColors.background],
                  ),
                ),
                child: Column(
                  children: [
                    _avatarHeader(),
                    const SizedBox(height: 12),
                    Text(
                      widget.profile.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '完善招聘名片，让沟通更有温度',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _section('基本资料', Icons.edit_outlined, [
                      _field(
                        'nickName',
                        '姓名 / 昵称',
                        maxLength: 30,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? '请填写姓名或昵称'
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
                        onChanged: _busy
                            ? null
                            : (value) {
                                if (value != null) setState(() => _sex = value);
                              },
                      ),
                    ]),
                    _section('联系方式', Icons.contact_phone_outlined, [
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
                      const Text(
                        '联系方式仅用于当前账号资料；对外展示以业务权限为准。',
                        style: TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                    ]),
                    _section('招聘身份', Icons.business_center_outlined, [
                      _readonly('登录账号', widget.profile.account),
                      _readonly('所属部门', widget.profile.department),
                      _readonly('职务', widget.profile.position),
                      _readonly('角色', widget.profile.role),
                      const SizedBox(height: 8),
                      const Text(
                        '身份信息由企业管理员维护，当前页面不可修改。',
                        style: TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                    ]),
                    _section('个人简介', Icons.edit_note_outlined, [
                      _field(
                        'remark',
                        '介绍你的招聘方向与工作理念',
                        maxLength: 500,
                        lines: 4,
                      ),
                    ]),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    FilledButton(
                      key: const Key('profile-edit-save'),
                      onPressed: _busy ? null : _save,
                      child: Text(_saving ? '保存中…' : '保存修改'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
