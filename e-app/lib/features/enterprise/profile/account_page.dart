import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/skeleton_list.dart';
import 'account_settings_page.dart';
import 'data/profile_data_source.dart';
import 'models/profile_view_data.dart';
import 'profile_edit_page.dart';
import 'widgets/profile_avatar_view.dart';

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
  String? _error;
  bool _loading = true, _actionOpen = false;
  int _request = 0, _avatarRevision = 0;
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
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = profileError(error));
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
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
    _avatarRevision++;
    _message('个人资料已更新');
    await reload();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _settings() async {
    if (_actionOpen || _profile == null) return;
    setState(() => _actionOpen = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => AccountSettingsPage(
            profile: _profile!,
            source: widget.source,
            onLogout: widget.onLogout,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _actionOpen = false);
    }
    if (mounted) await reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('我的'),
      actions: [
        IconButton(
          key: const Key('profile-settings'),
          tooltip: '设置',
          onPressed: _actionOpen || _loading || _profile == null
              ? null
              : _settings,
          icon: const Icon(Icons.settings_outlined, color: AppColors.brand),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: _body(context),
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
        children: [_hero(profile)],
      ),
    );
  }

  Widget _hero(EnterpriseProfile profile) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.brandDeep, AppColors.brand, AppColors.interactive],
      ),
    ),
    child: Material(
      color: AppColors.canvas.withValues(alpha: 0),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('profile-business-card'),
        onTap: _actionOpen ? null : _edit,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileAvatarView(
                    name: profile.name,
                    url: widget.source.avatarUrl(profile.avatar),
                    revision: _avatarRevision,
                  ),
                  const SizedBox(width: 14),
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
                            color: AppColors.canvas,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _badge(Icons.verified_user_outlined, profile.role),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: const Key('profile-edit'),
                    tooltip: '编辑资料',
                    onPressed: _actionOpen ? null : _edit,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.canvas.withValues(alpha: .14),
                    ),
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.canvas,
                      size: 21,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${profile.position} · ${profile.department}',
                style: TextStyle(
                  color: AppColors.canvas.withValues(alpha: .85),
                  fontSize: 13,
                ),
              ),
              if (profileText(profile.user['remark'], '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  profileText(profile.user['remark']),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.canvas.withValues(alpha: .9),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _badge(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.canvas.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.canvas),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.canvas, fontSize: 11),
          ),
        ),
      ],
    ),
  );
}
