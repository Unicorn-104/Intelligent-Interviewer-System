import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../features/profile/domain/user_profile.dart';
import '../features/profile/presentation/profile_avatar.dart';
import '../features/profile/presentation/profile_controller.dart';
import '../theme/app_theme.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({
    super.key,
    required this.initialProfile,
    required this.controller,
  });

  final UserProfile initialProfile;
  final ProfileController controller;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  late final TextEditingController _nickNameController;
  late final TextEditingController _realNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _cityController;
  late final TextEditingController _targetController;
  late final TextEditingController _targetCityController;
  late final TextEditingController _bioController;
  late final TextEditingController _salaryMinController;
  late final TextEditingController _salaryMaxController;
  int? _salaryMode;
  late String _sex;
  int? _currentStatus;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _avatar;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _nickNameController = TextEditingController(text: profile.nickName);
    _realNameController = TextEditingController(text: profile.realName);
    _phoneController = TextEditingController(text: profile.phoneNumber);
    _emailController = TextEditingController(text: profile.email);
    _cityController = TextEditingController(text: profile.currentCity);
    _targetController = TextEditingController(text: profile.targetDirection);
    _targetCityController = TextEditingController(text: profile.targetCity);
    _bioController = TextEditingController(text: profile.bio);
    _salaryMinController = TextEditingController(
      text: profile.salaryMin?.toString(),
    );
    _salaryMaxController = TextEditingController(
      text: profile.salaryMax?.toString(),
    );
    _salaryMode = profile.salaryNegotiable;
    _sex = profile.sex ?? '2';
    _currentStatus = profile.currentStatus;
    _avatar = profile.avatar;
  }

  @override
  void dispose() {
    _nickNameController.dispose();
    _realNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _targetController.dispose();
    _targetCityController.dispose();
    _bioController.dispose();
    _salaryMinController.dispose();
    _salaryMaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编辑资料')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
              child: Column(
                children: [
                  Semantics(
                    button: true,
                    label: '更换头像',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _uploadingAvatar ? null : _chooseAvatar,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ProfileAvatar(
                            avatar: _avatar,
                            name: _avatarText,
                            radius: 42,
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.interactive,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (_uploadingAvatar)
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.42),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: SizedBox.square(
                                    dimension: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _uploadingAvatar ? '头像上传中…' : '点击更换头像，支持 JPG、PNG',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _FormSectionTitle('基本资料'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nickNameController,
              decoration: const InputDecoration(labelText: '昵称'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return '请输入昵称';
                if (value.trim().length > 30) return '昵称不能超过 30 个字符';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _realNameController,
              decoration: const InputDecoration(labelText: '姓名'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _sex,
              decoration: const InputDecoration(labelText: '性别'),
              items: const [
                DropdownMenuItem(value: '0', child: Text('男')),
                DropdownMenuItem(value: '1', child: Text('女')),
                DropdownMenuItem(value: '2', child: Text('不展示')),
              ],
              onChanged: (value) => setState(() => _sex = value ?? '2'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '手机号'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: '邮箱'),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isNotEmpty && !text.contains('@')) return '请输入正确的邮箱地址';
                return null;
              },
            ),
            const SizedBox(height: 24),
            const _FormSectionTitle('求职信息'),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              key: const Key('profile-salary-mode'),
              initialValue: _salaryMode ?? -1,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '期望薪资'),
              items: const [
                DropdownMenuItem(value: -1, child: Text('未填写')),
                DropdownMenuItem(value: 1, child: Text('面议')),
                DropdownMenuItem(value: 0, child: Text('填写月薪区间')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(
                      () => _salaryMode = value == -1 ? null : value,
                    ),
            ),
            if (_salaryMode == 0) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('profile-salary-min'),
                controller: _salaryMinController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '期望月薪下限（元）'),
                validator: _salaryValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('profile-salary-max'),
                controller: _salaryMaxController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '期望月薪上限（元）'),
                validator: (value) {
                  final error = _salaryValidator(value);
                  if (error != null) return error;
                  final minimum = int.tryParse(
                    _salaryMinController.text.trim(),
                  );
                  final maximum = int.tryParse(value?.trim() ?? '');
                  return minimum != null && maximum != null && maximum < minimum
                      ? '上限不能低于下限'
                      : null;
                },
              ),
            ],
            const SizedBox(height: 6),
            const Text(
              '人民币税前月薪；保存后用于招聘者人才发现。未填写不等于0元。',
              style: TextStyle(fontSize: 12),
            ),

            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _currentStatus,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '当前状态'),
              hint: const Text('请选择当前状态'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('在职，考虑新机会')),
                DropdownMenuItem(value: 2, child: Text('离职，随时到岗')),
                DropdownMenuItem(value: 3, child: Text('应届生')),
              ],
              onChanged: (value) => setState(() => _currentStatus = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: '所在城市'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _targetController,
              decoration: const InputDecoration(labelText: '期望职位'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _targetCityController,
              decoration: const InputDecoration(labelText: '期望城市'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: _FormSectionTitle('个人简介')),
                TextButton.icon(
                  onPressed: _writeBio,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('AI 帮我写'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bioController,
              minLines: 4,
              maxLines: 6,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: '介绍你的职业方向、经验与优势',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 22),
            const _FormSectionTitle('实名认证'),
            const SizedBox(height: 10),
            _IdentityVerificationCard(
              verifyStatus: widget.initialProfile.verifyStatus,
              onTap: _showIdentityVerificationPlaceholder,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('保存修改'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _avatarText {
    final name = _nickNameController.text.trim();
    return name.isEmpty ? '用' : name.substring(0, 1).toUpperCase();
  }

  Future<void> _chooseAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('从相册选择'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('拍照'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (image == null || !mounted) return;
      if (await image.length() > 5 * 1024 * 1024) {
        if (!mounted) return;
        _showMessage('图片不能超过 5MB，请重新选择');
        return;
      }

      setState(() => _uploadingAvatar = true);
      final success = await widget.controller.uploadAvatar(image.path);
      if (!mounted) return;
      setState(() {
        _uploadingAvatar = false;
        if (success) _avatar = widget.controller.profile.avatar;
      });
      _showMessage(
        success ? '头像更新成功' : (widget.controller.errorMessage ?? '头像上传失败，请稍后重试'),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      _showMessage('无法读取图片，请检查相册或相机权限');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _writeBio() {
    final direction = _targetController.text.trim();
    final city = _targetCityController.text.trim();
    final focus = direction.isEmpty ? '目标岗位' : direction;
    final destination = city.isEmpty ? '' : '，期望在$city发展';
    _bioController.text =
        '专注$focus方向，重视用户价值与团队协作$destination。期待在新的机会中持续创造业务成果。';
    setState(() {});
  }

  Future<void> _showIdentityVerificationPlaceholder() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('实名认证', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              const Text('实名认证功能建设中，后续将接入身份信息填写、证件校验和认证结果查询。'),
              const SizedBox(height: 6),
              Text(
                '认证信息仅用于身份核验，请勿在其他资料字段中填写证件号码。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('知道了'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _salaryValidator(String? raw) {
    final value = int.tryParse(raw?.trim() ?? '');
    return value == null || value < 0 || value > 10000000
        ? '请输入0至10000000的整数金额'
        : null;
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final nextProfile = widget.initialProfile.copyWith(
      nickName: _nickNameController.text.trim(),
      realName: _realNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      sex: _sex,
      bio: _bioController.text.trim(),
      currentCity: _cityController.text.trim(),
      currentStatus: _currentStatus,
      targetDirection: _targetController.text.trim(),
      targetCity: _targetCityController.text.trim(),
      updateSalary: true,
      salaryNegotiable: _salaryMode,
      salaryMin: _salaryMode == 0
          ? int.tryParse(_salaryMinController.text.trim())
          : null,
      salaryMax: _salaryMode == 0
          ? int.tryParse(_salaryMaxController.text.trim())
          : null,
    );
    final success = await widget.controller.update(nextProfile);
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) {
      Navigator.pop(context, true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.controller.errorMessage ?? '保存失败，请稍后重试')),
    );
  }
}

class _FormSectionTitle extends StatelessWidget {
  const _FormSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _IdentityVerificationCard extends StatelessWidget {
  const _IdentityVerificationCard({
    required this.verifyStatus,
    required this.onTap,
  });

  final int verifyStatus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (verifyStatus) {
      1 => ('已完成', AppColors.green, AppColors.green.withValues(alpha: 0.1)),
      2 => ('未通过', AppColors.red, AppColors.red.withValues(alpha: 0.08)),
      _ => ('待认证', AppColors.warning, AppColors.warningSoft),
    };

    return Material(
      color: AppColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.interactive,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '实名认证',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        verifyStatus == 1 ? '身份信息已完成核验' : '完成身份核验，提升账号可信度',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.muted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
