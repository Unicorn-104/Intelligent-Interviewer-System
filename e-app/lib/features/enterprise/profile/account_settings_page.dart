import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/skeleton_list.dart';
import 'data/profile_data_source.dart';
import 'models/profile_view_data.dart';
import 'profile_edit_page.dart';
import 'widgets/profile_edit_dialog.dart';
import 'widgets/profile_preferences_panel.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({
    super.key,
    required this.onLogout,
    required this.profile,
    this.initialSection = -1,
    this.source = const ProfileDataSource(),
  });
  final VoidCallback onLogout;
  final EnterpriseProfile profile;
  final int initialSection;
  final ProfileDataSource source;
  @override
  State<AccountSettingsPage> createState() => AccountSettingsPageState();
}

class AccountSettingsPageState extends State<AccountSettingsPage> {
  EnterpriseProfile? _profile;
  ProfilePreferences _preferences = const ProfilePreferences();
  String? _error, _preferencesError;
  bool _loading = true, _actionOpen = false;
  int _request = 0, _tab = -1;
  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _tab = widget.initialSection;
    _loadInitialPreferences();
  }

  Future<void> _loadInitialPreferences() async {
    await _loadPreferences();
    if (mounted) setState(() => _loading = false);
  }

  /// 修改资料后刷新设置页显示。
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
      saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ProfileEditPage(
            profile: _profile!,
            source: widget.source,
            focusField: focusField,
            onSave: widget.source.saveProfile,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _actionOpen = false);
    }
    if (!mounted || saved != true) return;
    _message('个人资料已更新');
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
    if (mounted && confirmed == true) {
      setState(() => _tab = -1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pop(context);
        widget.onLogout();
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_actionOpen && _tab == -1,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_actionOpen && _tab != -1) setState(() => _tab = -1);
    },
    child: Scaffold(
      backgroundColor: _tab == -1 ? AppColors.canvas : AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: _tab == -1 ? AppColors.canvas : AppColors.background,
        title: Text(
          _tab == -1 ? '设置' : ['账号与安全', '通用设置', '通知与提醒'][_tab],
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          key: const Key('profile-settings-back'),
          tooltip: '返回',
          onPressed: _actionOpen
              ? null
              : () {
                  if (_tab == -1) {
                    Navigator.pop(context);
                  } else {
                    setState(() => _tab = -1);
                  }
                },
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 21),
        ),
      ),
      body: _body(context),
    ),
  );

  Widget _body(BuildContext context) {
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
                '设置加载失败',
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
    if (_tab == -1) return _settingsMenu(profile);
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        key: const Key('profile-settings-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _tabs(),
          const SizedBox(height: 16),
          if (_tab == 0) ...[
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

  Widget _settingsMenu(EnterpriseProfile profile) => ListView(
    key: const Key('profile-settings-scroll'),
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
    children: [
      _menuRow(
        '账号与安全中心',
        key: const Key('profile-tab-0'),
        onTap: () => setState(() => _tab = 0),
      ),
      const SizedBox(height: 12),
      _menuRow(
        '通知与提醒',
        key: const Key('profile-tab-2'),
        onTap: () => setState(() => _tab = 2),
      ),
      _menuRow('隐私保护', onTap: () => _message('隐私保护功能开发中')),
      _menuRow(
        '通用设置',
        key: const Key('profile-tab-1'),
        onTap: () => setState(() => _tab = 1),
      ),
      _menuRow('消息设置', onTap: () => setState(() => _tab = 2)),
      _menuRow('无障碍使用', onTap: () => _message('无障碍使用设置功能开发中，页面支持系统字号')),
      _menuRow('个人信息清单', onTap: () => _showInformation(profile)),
      _menuRow('第三方共享清单', onTap: () => _message('第三方共享清单功能开发中')),
      _menuRow(
        '关于智能面试官',
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('智能面试官 · 企业端'),
            content: const Text('管理招聘岗位、沟通求职者与安排面试。\nAI 分析结果仅供招聘人员参考。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('知道了'),
              ),
            ],
          ),
        ),
      ),
      const Divider(height: 32, color: AppColors.hairline),
      _menuRow('当前身份', detail: '企业招聘者'),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: TextButton(
          key: const Key('profile-logout'),
          onPressed: _actionOpen ? null : _logout,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 50),
            foregroundColor: AppColors.bodySoft,
            backgroundColor: AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: const Text('退出登录', style: TextStyle(fontSize: 16)),
        ),
      ),
    ],
  );

  Widget _menuRow(
    String label, {
    Key? key,
    String? detail,
    VoidCallback? onTap,
  }) => ListTile(
    key: key,
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 20,
    title: Text(
      label,
      style: const TextStyle(fontSize: 16, color: AppColors.ink),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (detail != null)
          Text(
            detail,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        if (onTap != null)
          const Icon(Icons.chevron_right, size: 22, color: AppColors.muted),
      ],
    ),
    onTap: _actionOpen ? null : onTap,
  );

  Future<void> _showInformation(EnterpriseProfile profile) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('个人信息清单'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detail('姓名', profile.name),
            _detail('所属部门', profile.department),
            _detail(
              '手机号',
              profile.phone.isEmpty ? '未填写' : _maskedPhone(profile.phone),
            ),
            _detail(
              '邮箱',
              profile.email.isEmpty ? '未填写' : _maskedEmail(profile.email),
            ),
            const Text(
              '此处仅展示当前账号已有资料；编辑资料可查看与修改联系方式。',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
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
        for (final (index, label) in ['账号安全', '偏好设置', '通知设置'].indexed)
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
      profile.email.isEmpty ? '未填写' : _maskedEmail(profile.email),
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
  String _maskedEmail(String value) {
    final parts = value.split('@');
    return parts.length == 2
        ? '${parts.first.characters.firstOrNull ?? ''}***@${parts.last}'
        : '已填写';
  }

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
