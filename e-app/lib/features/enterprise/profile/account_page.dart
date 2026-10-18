import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/skeleton_list.dart';
import 'data/profile_data_source.dart';
import 'models/profile_view_data.dart';
import 'widgets/profile_edit_dialog.dart';
import 'widgets/profile_preferences_panel.dart';
import 'settings_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    required this.onLogout,
    this.source = const ProfileDataSource(),
  });
  final VoidCallback onLogout;
  final ProfileDataSource source;
  @override
  State<AccountPage> createState() => AccountPageState();
}

class AccountPageState extends State<AccountPage> {
  EnterpriseProfile? _profile;
  ProfilePreferences _preferences = const ProfilePreferences();
  String? _error, _preferencesError;
  bool _loading = true, _actionOpen = false, _uploadingAvatar = false;
  int _request = 0, _tab = 0, _avatarRevision = 0;
  @override
  void initState() {
    super.initState();
    reload();
  }

  /// 每次进入“我的”重新读取服务端资料，保持企业壳原有刷新入口。
  Future<void> reload() async {
    if (_actionOpen) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.source.loadProfile();
      if (!mounted || request != _request) return;
      setState(() => _profile = profile);
      await _loadPreferences(request);
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = profileError(error));
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _loadPreferences([int? request]) async {
    final profile = _profile;
    if (profile == null) return;
    try {
      final value = await widget.source.loadPreferences(profile.id);
      if (mounted &&
          (request == null || request == _request) &&
          _profile?.id == profile.id) {
        setState(() {
          _preferences = value;
          _preferencesError = null;
        });
      }
    } catch (error) {
      if (mounted && (request == null || request == _request)) {
        setState(() => _preferencesError = '本机设置读取失败，请重试');
      }
    }
  }

  Future<void> _edit({String? focusField}) async {
    if (_actionOpen || _profile == null) return;
    setState(() => _actionOpen = true);
    bool? saved;
    try {
      saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ProfileEditDialog(
          profile: _profile!,
          focusField: focusField,
          onSave: widget.source.saveProfile,
        ),
      );
    } finally {
      if (mounted) setState(() => _actionOpen = false);
    }
    if (!mounted || saved != true) return;
    _message('个人资料已保存');
    await reload();
  }

  Future<void> _password() async {
    if (_actionOpen) return;
    setState(() => _actionOpen = true);
    bool? saved;
    try {
      saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            ProfilePasswordDialog(onSave: widget.source.changePassword),
      );
    } finally {
      if (mounted) setState(() => _actionOpen = false);
    }
    if (!mounted || saved != true) return;
    _message('密码已修改，当前会话可继续使用');
    await reload();
  }

  Future<void> _avatar() async {
    if (_actionOpen) return;
    setState(() {
      _actionOpen = true;
      _uploadingAvatar = true;
    });
    var saved = false;
    try {
      final picked = await widget.source.pickAvatar();
      if (picked == null || !mounted) return;
      await widget.source.uploadAvatar(picked);
      if (!mounted) return;
      saved = true;
      _avatarRevision++;
      _message('头像已更新');
    } catch (error) {
      if (mounted) _message(profileError(error));
    } finally {
      if (mounted) {
        setState(() {
          _actionOpen = false;
          _uploadingAvatar = false;
        });
      }
    }
    if (saved && mounted) await reload();
  }

  Future<void> _savePreferences(ProfilePreferences value) async {
    final profile = _profile!;
    final merged = _tab == 2
        ? _preferences.copyWith(notices: value.notices)
        : _preferences.copyWith(
            duration: value.duration,
            calendar: value.calendar,
            frequency: value.frequency,
          );
    if (_actionOpen) return;
    setState(() => _actionOpen = true);
    try {
      await widget.source.savePreferences(profile.id, merged);
      if (mounted && _profile?.id == profile.id) {
        setState(() => _preferences = merged);
      }
    } finally {
      if (mounted) setState(() => _actionOpen = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录？'),
        content: const Text('退出后可重新登录当前账号。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('profile-logout-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonList(rows: 3);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_outline,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              const Text(
                '个人中心加载失败',
                style: TextStyle(
                  color: AppColors.brand,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: reload, child: const Text('重试')),
              TextButton(onPressed: widget.onLogout, child: const Text('退出登录')),
            ],
          ),
        ),
      );
    }
    final profile = _profile!;
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        key: const Key('profile-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _hero(profile),
          const SizedBox(height: 16),
          _tabs(),
          const SizedBox(height: 16),
          if (_tab == 0) ...[
            _personal(profile),
            const SizedBox(height: 16),
            _security(profile),
            const SizedBox(height: 16),
            _login(profile),
          ] else
            ProfilePreferencesPanel(
              key: ValueKey('profile-settings-${profile.id}-$_tab'),
              value: _preferences,
              notifications: _tab == 2,
              error: _preferencesError,
              onRetry: _loadPreferences,
              onSave: _savePreferences,
            ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              key: const Key('profile-enterprise-settings'),
              leading: const Icon(
                Icons.business_outlined,
                color: AppColors.interactive,
              ),
              title: const Text('企业设置', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                '组织、成员与配置概览',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
              ),
              onTap: _actionOpen
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const EnterpriseSettingsPage(),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('profile-logout'),
            onPressed: _actionOpen ? null : _logout,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('退出登录'),
          ),
        ],
      ),
    );
  }

  Widget _hero(EnterpriseProfile profile) {
    final url = widget.source.avatarUrl(profile.avatar);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Semantics(
                  button: true,
                  label: '修改头像',
                  child: InkWell(
                    key: const Key('profile-avatar'),
                    onTap: _actionOpen ? null : _avatar,
                    borderRadius: BorderRadius.circular(40),
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            right: 8,
                            bottom: 8,
                            child: ClipOval(
                              child: ColoredBox(
                                color: AppColors.interactiveSoft,
                                child: url == null
                                    ? _avatarFallback(profile)
                                    : Image.network(
                                        '$url${url.contains('?') ? '&' : '?'}v=$_avatarRevision',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _avatarFallback(profile),
                                      ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.interactive,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.canvas,
                                  width: 2,
                                ),
                              ),
                              child: _uploadingAvatar
                                  ? const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.canvas,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.photo_camera_outlined,
                                      color: AppColors.canvas,
                                      size: 15,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        key: const Key('profile-display-name'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.brand,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.interactiveSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          profile.role,
                          style: const TextStyle(
                            color: AppColors.interactive,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${profile.position} · ${profile.department}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '登录账号：${profile.account}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: const Key('profile-edit'),
                onPressed: _actionOpen ? null : _edit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('编辑资料'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(EnterpriseProfile profile) => Center(
    child: Text(
      profile.name.characters.first,
      style: const TextStyle(
        color: AppColors.interactive,
        fontSize: 26,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
  Widget _tabs() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      border: Border.all(color: AppColors.hairline),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        for (final (index, label) in ['个人资料', '偏好设置', '通知设置'].indexed)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: TextButton(
                key: ValueKey('profile-tab-$index'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  backgroundColor: index == _tab
                      ? AppColors.interactiveSoft
                      : AppColors.canvas,
                  foregroundColor: index == _tab
                      ? AppColors.interactive
                      : AppColors.textMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: _actionOpen
                    ? null
                    : () => setState(() => _tab = index),
                child: Text(label, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ),
      ],
    ),
  );
  Widget _card(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.brand,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          ),
        ),
      ],
    ),
  );
  Widget _personal(EnterpriseProfile profile) => _card('基本信息', [
    _detail('姓名', profile.name),
    _detail('手机号', profile.phone.isEmpty ? '未填写' : profile.phone),
    _detail('邮箱', profile.email.isEmpty ? '未填写' : profile.email),
    _detail('性别', profile.sex),
    _detail('所属部门', profile.department),
    _detail('个人简介', profileText(profile.user['remark'], '未填写')),
  ]);
  Widget _security(EnterpriseProfile profile) => _card('账号与安全', [
    _securityRow(
      '登录密码',
      Icons.key_outlined,
      '修改密码',
      _password,
      key: const Key('profile-change-password'),
    ),
    _securityRow(
      '联系手机号',
      Icons.smartphone_outlined,
      profile.phone.isEmpty ? '未填写' : _maskedPhone(profile.phone),
      () => _edit(focusField: 'phonenumber'),
    ),
    _securityRow(
      '联系邮箱',
      Icons.mail_outline,
      profile.email.isEmpty ? '未填写' : profile.email,
      () => _edit(focusField: 'email'),
    ),
    _securityRow(
      '绑定微信',
      Icons.chat_outlined,
      '功能开发中',
      () => _message('微信绑定功能开发中'),
    ),
    _securityRow(
      '双重验证',
      Icons.verified_user_outlined,
      '功能开发中',
      () => _message('双重验证功能开发中'),
    ),
  ]);
  String _maskedPhone(String value) => value.length < 7
      ? value
      : '${value.substring(0, 3)}****${value.substring(value.length - 4)}';
  Widget _securityRow(
    String title,
    IconData icon,
    String detail,
    VoidCallback action, {
    Key? key,
  }) => ListTile(
    key: key,
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: AppColors.interactive, size: 21),
    title: Text(title, style: const TextStyle(fontSize: 14)),
    subtitle: Text(
      detail,
      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
    ),
    trailing: const Icon(
      Icons.chevron_right,
      color: AppColors.textMuted,
      size: 20,
    ),
    onTap: _actionOpen ? null : action,
  );
  Widget _login(EnterpriseProfile profile) => _card('最近登录', [
    _detail('登录时间', profileText(profile.user['loginDate'], '暂无登录时间')),
    _detail('登录 IP', profileText(profile.user['loginIp'], '暂无登录记录')),
    TextButton(
      onPressed: () => _message('历史登录记录功能开发中'),
      child: const Text('查看全部登录记录 · 功能开发中'),
    ),
  ]);
}
