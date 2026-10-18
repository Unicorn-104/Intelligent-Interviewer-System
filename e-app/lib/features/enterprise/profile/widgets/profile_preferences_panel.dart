import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../data/profile_data_source.dart';
import '../models/profile_view_data.dart';

class ProfilePreferencesPanel extends StatefulWidget {
  const ProfilePreferencesPanel({
    super.key,
    required this.value,
    required this.notifications,
    required this.onSave,
    this.error,
    this.onRetry,
  });
  final ProfilePreferences value;
  final bool notifications;
  final Future<void> Function(ProfilePreferences) onSave;
  final String? error;
  final VoidCallback? onRetry;
  @override
  State<ProfilePreferencesPanel> createState() =>
      _ProfilePreferencesPanelState();
}

class _ProfilePreferencesPanelState extends State<ProfilePreferencesPanel> {
  late ProfilePreferences _draft = widget.value;
  bool _saving = false;
  String? _error;
  @override
  void didUpdateWidget(covariant ProfilePreferencesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.error != null && widget.error == null) _draft = widget.value;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_draft);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已保存到本机')));
      }
    } catch (error) {
      if (mounted) setState(() => _error = profileError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dropdown<T>(
    String id,
    String label,
    T value,
    Map<T, String> options,
    ValueChanged<T> onChange,
  ) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: DropdownButtonFormField<T>(
      key: ValueKey('$id-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options.entries
          .map(
            (entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      onChanged: _saving
          ? null
          : (value) {
              if (value != null) onChange(value);
            },
    ),
  );
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.notifications ? '通知设置' : '工作偏好',
            style: const TextStyle(
              color: AppColors.brand,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.notifications
                ? '仅保存本机接收偏好，手机推送策略功能开发中。'
                : '偏好仅保存在本机；日历同步和通知频率的执行功能开发中。',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          if (widget.error != null) ...[
            const SizedBox(height: 12),
            Text(widget.error!, style: const TextStyle(color: AppColors.error)),
            TextButton(onPressed: widget.onRetry, child: const Text('重新读取设置')),
          ] else ...[
            if (widget.notifications) ...[
              for (final entry in const {
                'interview': ('面试提醒', '面试开始前的提醒', Icons.schedule_outlined),
                'resume': ('简历入库', '新候选人投递时的提醒', Icons.description_outlined),
                'message': ('候选人消息', '候选人发来消息时的提醒', Icons.chat_bubble_outline),
                'system': ('系统更新', '产品更新与维护公告', Icons.campaign_outlined),
              }.entries)
                SwitchListTile.adaptive(
                  key: Key('profile-notice-${entry.key}'),
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    entry.value.$3,
                    color: AppColors.interactive,
                    size: 22,
                  ),
                  title: Text(
                    entry.value.$1,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    entry.value.$2,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  value: _draft.notices[entry.key]!,
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _draft = _draft.copyWith(
                            notices: {..._draft.notices, entry.key: value},
                          ),
                        ),
                ),
            ] else ...[
              _dropdown(
                'profile-pref-duration',
                '偏好面试时长',
                _draft.duration,
                const {30: '30 分钟', 45: '45 分钟', 60: '60 分钟'},
                (value) =>
                    setState(() => _draft = _draft.copyWith(duration: value)),
              ),
              _dropdown(
                'profile-pref-calendar',
                '日历同步偏好',
                _draft.calendar,
                ProfilePreferences.calendarOptions,
                (value) =>
                    setState(() => _draft = _draft.copyWith(calendar: value)),
              ),
              _dropdown(
                'profile-pref-frequency',
                '通知频率偏好',
                _draft.frequency,
                ProfilePreferences.frequencyOptions,
                (value) =>
                    setState(() => _draft = _draft.copyWith(frequency: value)),
              ),
              const SizedBox(height: 16),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.language, color: AppColors.textMuted),
                title: Text('简体中文', style: TextStyle(fontSize: 14)),
                subtitle: Text('其他语言功能开发中', style: TextStyle(fontSize: 12)),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.public, color: AppColors.textMuted),
                title: Text(
                  'UTC+08:00 · 北京 / 上海',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: Text('当前面试日程使用此时区', style: TextStyle(fontSize: 12)),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            _draft = widget.value;
                            _error = null;
                          }),
                    child: const Text('恢复已保存'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('profile-preferences-save'),
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? '保存中…' : '保存设置'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
