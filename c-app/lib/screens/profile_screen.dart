import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../features/auth/domain/auth_session.dart';
import '../features/applications/presentation/application_screen.dart';
import '../features/interviews/presentation/interview_screen.dart';
import '../features/profile/data/profile_api.dart';
import '../features/profile/domain/user_profile.dart';
import '../features/profile/presentation/profile_controller.dart';
import '../features/profile/presentation/profile_avatar.dart';
import '../theme/app_theme.dart';
import 'profile_edit_screen.dart';
import '../features/companies/presentation/company_favorites_screen.dart';
import 'resume_screen.dart';
import 'settings_screen.dart';
import 'support_screens.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.session,
    required this.onLogout,
    this.refreshVersion = 0,
  });

  final AuthSession session;
  final Future<void> Function() onLogout;
  final int refreshVersion;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ApiClient _client;
  late final ProfileController _controller;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _controller = ProfileController(
      ProfileApi(_client),
      session: widget.session,
    );
    _controller.load();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion) _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            tooltip: '设置',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final profile = _controller.profile;
          return RefreshIndicator(
            onRefresh: _controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                if (_controller.loading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                _ProfileHeader(
                  profile: profile,
                  onEdit: () => _openEditor(profile),
                ),
                if (_controller.errorMessage case final message?) ...[
                  const SizedBox(height: 12),
                  _LoadError(message: message, onRetry: _controller.load),
                ],
                const SizedBox(height: 14),
                if (profile.completionPercent < 100) ...[
                  _CompletionCard(
                    percent: profile.completionPercent,
                    onTap: () => _openEditor(profile),
                  ),
                  const SizedBox(height: 14),
                ],
                _StatsCard(profile: profile, onSelected: _openCareer),
                const SizedBox(height: 24),
                const _SectionTitle(title: '求职概况'),
                const SizedBox(height: 10),
                _CareerOverview(profile: profile),
                const SizedBox(height: 24),
                const _SectionTitle(title: '求职管理'),
                const SizedBox(height: 10),
                _MenuGroup(
                  items: const [
                    _MenuItem(Icons.description_outlined, '简历管理', '维护求职简历'),
                    _MenuItem(Icons.send_outlined, '我的投递', '查看投递进度'),
                    _MenuItem(Icons.calendar_month_outlined, '面试日程', '管理面试安排'),
                    _MenuItem(Icons.bookmark_outline, '我的收藏', '收藏的企业'),
                  ],
                  onTap: _openCareer,
                ),
                const SizedBox(height: 22),
                const _SectionTitle(title: '帮助与服务'),
                const SizedBox(height: 10),
                _MenuGroup(
                  items: const [
                    _MenuItem(Icons.help_outline, '帮助中心', '使用指南'),
                    _MenuItem(Icons.feedback_outlined, '问题反馈', ''),
                    _MenuItem(
                      Icons.support_agent_outlined,
                      '联系客服',
                      '工作日 9:00–18:00',
                    ),
                  ],
                  onTap: _openSupport,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEditor(UserProfile profile) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ProfileEditScreen(initialProfile: profile, controller: _controller),
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('个人资料已保存')));
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            SettingsScreen(session: widget.session, onLogout: widget.onLogout),
      ),
    );
  }

  Future<void> _openSupport(String title) async {
    final screen = switch (title) {
      '帮助中心' => HelpCenterScreen(session: widget.session),
      '问题反馈' => FeedbackScreen(session: widget.session),
      '联系客服' => ContactSupportScreen(session: widget.session),
      _ => null,
    };
    if (screen == null) return;
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => screen));
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title功能将在对应业务模块中接入')));
  }

  Future<void> _openCareer(String title) async {
    final screen = switch (title) {
      '简历管理' => ResumeScreen(session: widget.session, showAppBar: true),
      '我的投递' => ApplicationScreen(session: widget.session),
      '面试日程' => InterviewScreen(session: widget.session),
      '我的收藏' => CompanyFavoritesScreen(session: widget.session),
      _ => null,
    };
    if (screen == null) {
      _showComingSoon(title);
      return;
    }
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _controller.load();
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.onEdit});

  final UserProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final verified = profile.verifyStatus == 1;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.brandDeep, AppColors.interactive],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileAvatar(
                  avatar: profile.avatar,
                  name: profile.nickName,
                  radius: 34,
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.brand,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.nickName.isEmpty
                            ? profile.userName
                            : profile.nickName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _HeaderBadge(
                            icon: verified
                                ? Icons.verified
                                : Icons.shield_outlined,
                            label: profile.verificationLabel,
                          ),
                          if (profile.currentCity?.isNotEmpty == true)
                            _HeaderBadge(
                              icon: Icons.location_on_outlined,
                              label: profile.currentCity!,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '编辑资料',
                  onPressed: onEdit,
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 19),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              profile.bio?.isNotEmpty == true
                  ? profile.bio!
                  : '完善个人简介，让招聘方更快了解你的优势。',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.percent, required this.onTap});

  final int percent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: AppColors.interactive,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      percent >= 100 ? '个人资料已完善' : '个人资料完整度',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: AppColors.interactive,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: percent / 100,
                  minHeight: 5,
                  backgroundColor: AppColors.hairline,
                  color: AppColors.interactive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.profile, required this.onSelected});

  final UserProfile profile;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            _Stat(
              value: '${profile.applicationCount}',
              label: '我的投递',
              onTap: () => onSelected('我的投递'),
            ),
            const _VerticalDivider(),
            _Stat(
              value: '${profile.interviewCount}',
              label: '面试安排',
              onTap: () => onSelected('面试日程'),
            ),
            const _VerticalDivider(),
            _Stat(
              value: '${profile.favoriteCount}',
              label: '收藏',
              onTap: () => onSelected('我的收藏'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.onTap});

  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: AppColors.hairline);
  }
}

class _CareerOverview extends StatelessWidget {
  const _CareerOverview({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _OverviewItem(
                    icon: Icons.track_changes_outlined,
                    label: '期望职位',
                    value: profile.targetDirection ?? '待完善',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OverviewItem(
                    icon: Icons.work_history_outlined,
                    label: '当前状态',
                    value: profile.statusLabel,
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: _OverviewItem(
                    icon: Icons.location_on_outlined,
                    label: '期望城市',
                    value: profile.targetCity ?? profile.currentCity ?? '待完善',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OverviewItem(
                    icon: Icons.timeline_outlined,
                    label: '工作年限',
                    value: profile.workYears > 0
                        ? '${profile.workYears} 年'
                        : '待完善',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewItem extends StatelessWidget {
  const _OverviewItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 18, color: AppColors.interactive),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _MenuItem {
  const _MenuItem(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items, required this.onTap});

  final List<_MenuItem> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            ListTile(
              minLeadingWidth: 26,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 2,
              ),
              leading: Icon(
                items[index].icon,
                color: AppColors.bodySoft,
                size: 21,
              ),
              title: Text(items[index].title),
              subtitle: items[index].subtitle.isEmpty
                  ? null
                  : Text(items[index].subtitle, maxLines: 1),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => onTap(items[index].title),
            ),
            if (index != items.length - 1)
              const Divider(height: 1, indent: 56, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6F7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
