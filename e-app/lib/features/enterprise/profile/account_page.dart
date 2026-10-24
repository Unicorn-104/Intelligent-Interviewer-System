import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/skeleton_list.dart';
import '../talent/talent_page.dart';
import '../interview/recording_page.dart';
import '../schedule/reschedule_review_page.dart';
import 'account_settings_page.dart';
import 'data/profile_data_source.dart';
import 'models/profile_view_data.dart';
import 'profile_edit_page.dart';
import 'settings_page.dart';
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
      title: const Text(
        '我的',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      backgroundColor: AppColors.primarySoft,
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
        padding: EdgeInsets.zero,
        children: [
          _hero(profile),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const EnterpriseManagementPanel(),
                const SizedBox(height: 16),
                _recruitingTools(),
                const SizedBox(height: 28),
                const Text(
                  '智能面试官 · 企业端',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTool(Widget page) async {
    if (_actionOpen) return;
    setState(() => _actionOpen = true);
    try {
      await Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => page));
    } finally {
      if (mounted) setState(() => _actionOpen = false);
    }
  }

  Widget _recruitingTools() => Container(
    key: const Key('profile-recruiting-tools'),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '招聘工具',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (label, icon, page, demo)
                in const <(String, IconData, Widget, bool)>[
                  (
                    '人才库',
                    Icons.people_outline,
                    TalentPage(discovery: true),
                    false,
                  ),
                  ('录播', Icons.video_library_outlined, RecordingPage(), true),
                  (
                    '改期审批',
                    Icons.edit_calendar_outlined,
                    RescheduleReviewPage(),
                    false,
                  ),
                ])
              Expanded(
                child: InkWell(
                  key: ValueKey('profile-tool-$label'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: _actionOpen ? null : () => _openTool(page),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            icon,
                            color: AppColors.interactive,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.body,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (demo)
                          const Text(
                            '演示数据',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.orange,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _hero(EnterpriseProfile profile) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.primarySoft, AppColors.background],
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        key: const Key('profile-card-frame'),
        color: AppColors.canvas,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.interactive.withValues(alpha: .22)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('profile-business-card'),
          onTap: _actionOpen ? null : _edit,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ProfileAvatarView(
                      size: 76,
                      name: profile.name,
                      url: widget.source.avatarUrl(profile.avatar),
                      revision: _avatarRevision,
                    ),
                    const SizedBox(width: 16),
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
                              color: AppColors.ink,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '个人资料',
                                  style: TextStyle(
                                    color: AppColors.bodySoft,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.edit_outlined,
                                size: 15,
                                color: AppColors.bodySoft,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('profile-edit'),
                      tooltip: '编辑资料',
                      onPressed: _actionOpen ? null : _edit,
                      icon: const Icon(
                        Icons.chevron_right,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  '${profile.position} · ${profile.department}',
                  style: const TextStyle(
                    color: AppColors.bodySoft,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    profile.role,
                    style: const TextStyle(
                      color: AppColors.interactive,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (profileText(profile.user['remark'], '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    profileText(profile.user['remark']),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.bodySoft,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
