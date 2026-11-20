import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/skeleton_list.dart';
import '../talent/talent_page.dart';
import '../interview/recording_page.dart';
import '../schedule/reschedule_review_page.dart';
import '../schedule/data/reschedule_review_data_source.dart';
import 'account_settings_page.dart';
import 'data/profile_data_source.dart';
import 'models/profile_view_data.dart';
import 'profile_edit_page.dart';
import 'settings_page.dart';
import 'enterprise_management_page.dart';
import 'integration_settings_page.dart';
import '../exam/exam_management_page.dart';
import '../exam/exam_proctor_page.dart';
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
  // “我的”列表滚动控制器，用于 Tab 重新选中时回到顶部
  final ScrollController _scrollController = ScrollController();
  final _rescheduleSource = RescheduleReviewDataSource();
  int _reschedulePending = 0;
  Timer? _rescheduleTimer;
  // 回到顶部请求标志（reload 时列表会被骨架替换，controller 无 client，需延迟执行）
  bool _scrollTopRequested = false;
  @override
  void initState() {
    super.initState();
    reload();
    _rescheduleTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadReschedulePending(),
    );
  }

  Future<void> _loadReschedulePending() async {
    try {
      final count = await _rescheduleSource.pendingCount();
      if (mounted) setState(() => _reschedulePending = count);
    } catch (_) {
      // 角标属于辅助信息，接口暂不可用时不影响“我的”页面主体加载。
    }
  }

  @override
  void dispose() {
    _rescheduleTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// 由 Shell 在“我的”Tab 被选中时调用：滚动到页面顶部。
  Future<void> scrollToTop() async {
    _scrollTopRequested = true;
    _applyScrollTop();
  }

  /// 实际执行回顶；若列表尚未挂载（reload 骨架），下一帧继续尝试。
  void _applyScrollTop() {
    if (!_scrollTopRequested) return;
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyScrollTop());
      return;
    }
    _scrollTopRequested = false;
    if (_scrollController.offset <= 0) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// 每次进入“我的”重新读取服务端资料，保持企业壳原有刷新入口。
  Future<void> reload() async {
    if (_actionOpen) return;
    _loadReschedulePending();
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
    _loadReschedulePending();
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

  Future<void> _openEnterpriseSection(String name) async {
    if (_actionOpen) return;
    final page = switch (name) {
      '部门管理' => const EnterpriseManagementPage(
        section: EnterpriseManagementSection.departments,
      ),
      '成员管理' => const EnterpriseManagementPage(
        section: EnterpriseManagementSection.members,
      ),
      '通知模板' => const EnterpriseManagementPage(
        section: EnterpriseManagementSection.templates,
      ),
      '集成配置' => const IntegrationSettingsPage(),
      _ => null,
    };
    if (page == null) {
      _message('$name功能开发中，请在 Web 端操作');
      return;
    }
    await _openTool(page);
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
        controller: _scrollController,
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
                EnterpriseManagementPanel(
                  onOpenSection: _openEnterpriseSection,
                ),
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
    _loadReschedulePending();
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
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: .75,
          children: [
            for (final (label, icon, page, demo)
                in const <(String, IconData, Widget, bool)>[
                  ('人才库', Icons.people_outline, TalentPage(discovery: true), false),
                  ('录播', Icons.video_library_outlined, RecordingPage(), false),
                  ('改期审批', Icons.edit_calendar_outlined, RescheduleReviewPage(), false),
                  ('笔试管理', Icons.assignment_outlined, ExamManagementPage(), false),
                  ('监控监考', Icons.shield_outlined, ExamProctorPage(), false),
                ])
              InkWell(
                  key: ValueKey('profile-tool-$label'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: _actionOpen ? null : () => _openTool(page),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(icon, color: AppColors.interactive, size: 26),
                                if (page is RescheduleReviewPage && _reschedulePending > 0)
                                  Positioned(
                                    right: -16,
                                    top: -16,
                                    child: Container(
                                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                                      child: Text(
                                        _reschedulePending > 99 ? '99+' : '$_reschedulePending',
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                              ],
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
                          // 固定高度占位：有无「演示数据」标签都保留同等空间，
                          // 避免个别格子内容超出 GridView 单元格高度导致 BOTTOM OVERFLOWED。
                          SizedBox(
                            height: 14,
                            child: demo
                                ? const Text(
                                    '演示数据',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.orange,
                                    ),
                                  )
                                : null,
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
