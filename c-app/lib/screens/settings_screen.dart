import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../features/auth/domain/auth_session.dart';
import '../features/ai/data/ai_api.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.session,
    required this.onLogout,
    this.memoryApi,
  });

  final AuthSession session;
  final Future<void> Function() onLogout;
  final AiApi? memoryApi;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _storage = FlutterSecureStorage();
  static const _jobKey = 'settings_job_notifications';
  static const _interviewKey = 'settings_interview_notifications';
  static const _chatKey = 'settings_chat_notifications';
  static const _recommendationKey = 'settings_personalized_recommendations';

  bool _loading = true;
  bool _jobNotifications = true;
  bool _interviewNotifications = true;
  bool _chatNotifications = true;
  bool _personalizedRecommendations = true;
  final _memoryClient = ApiClient();
  late final _memoryApi = widget.memoryApi ?? AiApi(_memoryClient);
  bool _memoryEnabled = false;
  bool _memoryLoading = true;
  bool _memorySaving = false;
  bool _memoryLoadFailed = false;
  int _memoryRevision = 0;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadMemorySettings();
  }

  @override
  void dispose() {
    _memoryClient.close();
    super.dispose();
  }

  Future<void> _loadMemorySettings() async {
    setState(() {
      _memoryLoading = true;
      _memoryLoadFailed = false;
    });
    try {
      final settings = await _memoryApi.memorySettings(widget.session.token);
      if (!mounted) return;
      setState(() {
        _memoryEnabled = settings['enabled'] == true;
        _memoryRevision = (settings['revision'] as num).toInt();
      });
    } catch (_) {
      if (mounted) setState(() => _memoryLoadFailed = true);
    } finally {
      if (mounted) setState(() => _memoryLoading = false);
    }
  }

  Future<void> _setMemoryEnabled(bool enabled) async {
    setState(() => _memorySaving = true);
    try {
      final settings = await _memoryApi.setMemoryEnabled(
        widget.session.token,
        enabled,
        _memoryRevision,
      );
      if (!mounted) return;
      setState(() {
        _memoryEnabled = settings['enabled'] == true;
        _memoryRevision = (settings['revision'] as num).toInt();
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage(error is ApiException ? error.message : '记忆设置保存失败，请稍后重试');
      await _loadMemorySettings();
    } finally {
      if (mounted) setState(() => _memorySaving = false);
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final values = await Future.wait([
        _storage.read(key: _jobKey),
        _storage.read(key: _interviewKey),
        _storage.read(key: _chatKey),
        _storage.read(key: _recommendationKey),
      ]);
      if (!mounted) return;
      setState(() {
        _jobNotifications = _readBool(values[0], fallback: true);
        _interviewNotifications = _readBool(values[1], fallback: true);
        _chatNotifications = _readBool(values[2], fallback: true);
        _personalizedRecommendations = _readBool(values[3], fallback: true);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _readBool(String? value, {required bool fallback}) {
    if (value == null) return fallback;
    return value == 'true';
  }

  Future<void> _setPreference(
    String key,
    bool value,
    void Function(bool value) update,
  ) async {
    setState(() => update(value));
    try {
      await _storage.write(key: key, value: value.toString());
    } catch (_) {
      if (!mounted) return;
      setState(() => update(!value));
      _showMessage('设置保存失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          _AccountHeader(session: widget.session),
          const SizedBox(height: 24),
          const _SectionTitle('账号与安全'),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.lock_outline,
                title: '修改登录密码',
                subtitle: '定期修改密码可提升账号安全性',
                onTap: _openPasswordEditor,
              ),
              _SettingsTile(
                icon: Icons.phone_iphone_outlined,
                title: '绑定手机号',
                trailingText: _maskedPhone(widget.session.phoneNumber),
                onTap: () => _showMessage('手机号换绑将在短信服务接入后开放'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle('消息通知'),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _PreferenceSwitch(
                icon: Icons.work_outline,
                title: '职位推荐',
                value: _jobNotifications,
                enabled: !_loading,
                onChanged: (value) => _setPreference(
                  _jobKey,
                  value,
                  (next) => _jobNotifications = next,
                ),
              ),
              _PreferenceSwitch(
                icon: Icons.event_available_outlined,
                title: '面试提醒',
                value: _interviewNotifications,
                enabled: !_loading,
                onChanged: (value) => _setPreference(
                  _interviewKey,
                  value,
                  (next) => _interviewNotifications = next,
                ),
              ),
              _PreferenceSwitch(
                icon: Icons.chat_bubble_outline,
                title: '沟通消息',
                value: _chatNotifications,
                enabled: !_loading,
                onChanged: (value) => _setPreference(
                  _chatKey,
                  value,
                  (next) => _chatNotifications = next,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle('隐私与通用'),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              if (_memoryLoading)
                const ListTile(
                  leading: Icon(
                    Icons.psychology_outlined,
                    color: AppColors.brand,
                  ),
                  title: Text('记忆'),
                  trailing: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_memoryLoadFailed)
                _SettingsTile(
                  icon: Icons.psychology_outlined,
                  title: '记忆',
                  subtitle: '加载失败，点击重试',
                  onTap: _loadMemorySettings,
                )
              else
                _PreferenceSwitch(
                  icon: Icons.psychology_outlined,
                  title: '记忆',
                  value: _memoryEnabled,
                  enabled: !_memoryLoading && !_memorySaving,
                  onChanged: _setMemoryEnabled,
                ),
              _PreferenceSwitch(
                icon: Icons.auto_awesome_outlined,
                title: '个性化职位推荐',
                subtitle: '根据求职意向优化推荐结果',
                value: _personalizedRecommendations,
                enabled: !_loading,
                onChanged: (value) => _setPreference(
                  _recommendationKey,
                  value,
                  (next) => _personalizedRecommendations = next,
                ),
              ),
              _SettingsTile(
                icon: Icons.shield_outlined,
                title: '隐私政策',
                onTap: () => _openDocument(
                  '隐私政策',
                  '我们仅在提供登录、求职资料、职位推荐和沟通服务所必需的范围内处理你的信息。你可以在个人资料中查看和修改账号信息，也可以关闭个性化推荐。未经授权，我们不会向无关第三方提供你的个人信息。',
                ),
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: '用户协议',
                onTap: () => _openDocument(
                  '用户协议',
                  '使用智聘助手前，请确保提交的信息真实、合法，并妥善保管账号凭证。平台提供的职位匹配和 AI 建议仅作为求职参考，具体招聘结果以招聘方最终确认信息为准。',
                ),
              ),
              _SettingsTile(
                icon: Icons.cleaning_services_outlined,
                title: '清理图片缓存',
                onTap: _clearImageCache,
              ),
              _SettingsTile(
                icon: Icons.info_outline,
                title: '关于智聘助手',
                trailingText: 'v1.0.0',
                onTap: _showAbout,
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('退出登录'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPasswordEditor() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangePasswordScreen(token: widget.session.token),
      ),
    );
    if (changed == true && mounted) _showMessage('登录密码已更新');
  }

  void _openDocument(String title, String content) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _DocumentScreen(title: title, content: content),
      ),
    );
  }

  void _clearImageCache() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    _showMessage('图片缓存已清理');
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: '智聘助手',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.interactive,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
      children: const [Text('以 AI 能力提升职位匹配、简历诊断和求职沟通效率。')],
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onLogout();
  }

  String _maskedPhone(String? phone) {
    final value = phone?.trim() ?? '';
    if (value.length < 7) return value.isEmpty ? '未绑定' : value;
    return '${value.substring(0, 3)}****${value.substring(value.length - 4)}';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.token});

  final String token;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final ApiClient _client;
  bool _submitting = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('修改登录密码')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security_outlined, color: AppColors.interactive),
                  SizedBox(width: 12),
                  Expanded(child: Text('新密码应为 6–20 位，建议同时包含字母、数字或符号。')),
                ],
              ),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _oldPasswordController,
              obscureText: _obscurePassword,
              decoration: const InputDecoration(labelText: '当前密码'),
              validator: (value) =>
                  value?.isNotEmpty == true ? null : '请输入当前密码',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscurePassword,
              decoration: const InputDecoration(labelText: '新密码'),
              validator: _validatePassword,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscurePassword,
              decoration: const InputDecoration(labelText: '确认新密码'),
              validator: (value) {
                if (value != _newPasswordController.text) return '两次输入的密码不一致';
                return null;
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                ),
                label: Text(_obscurePassword ? '显示密码' : '隐藏密码'),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('确认修改'),
            ),
          ],
        ),
      ),
    );
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 6 || password.length > 20) return '请输入 6–20 位新密码';
    if (password == _oldPasswordController.text) return '新密码不能与当前密码相同';
    return null;
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await _client.put(
        '/system/user/profile/updatePwd',
        token: widget.token,
        body: {
          'oldPassword': _oldPasswordController.text,
          'newPassword': _newPasswordController.text,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) _showError('密码修改失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final name = session.nickName.isEmpty ? session.userName : session.nickName;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primarySoft,
              child: Text(
                name.isEmpty ? '用' : name.substring(0, 1),
                style: const TextStyle(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '账号：${session.userName}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.verified_user_outlined, color: AppColors.green),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingText,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.brand),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(trailingText!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.icon,
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: enabled ? onChanged : null,
      secondary: Icon(icon, color: AppColors.brand),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
    );
  }
}

class _DocumentScreen extends StatelessWidget {
  const _DocumentScreen({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('更新日期：2026年9月28日', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          Text(content, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          const Text('如需查询、更正或删除个人信息，可以通过“我的—问题反馈”联系我们。'),
        ],
      ),
    );
  }
}
