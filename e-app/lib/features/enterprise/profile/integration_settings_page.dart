import 'package:flutter/material.dart';

import '../../../api/enterprise_memory_api.dart';
import '../../../api/integration_settings_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../assistant/enterprise_agent_sessions_page.dart';
import '../assistant/enterprise_knowledge_page.dart';
import '../assistant/enterprise_memory_page.dart';

class IntegrationSettingsPage extends StatefulWidget {
  const IntegrationSettingsPage({super.key});

  @override
  State<IntegrationSettingsPage> createState() =>
      _IntegrationSettingsPageState();
}

class _IntegrationSettingsPageState extends State<IntegrationSettingsPage> {
  bool _loading = true;
  bool _saving = false;
  bool _forceRegenerate = false;
  String _screeningAnalysisMode = 'incremental';
  String? _error;

  EnterpriseMemory? _memory;
  bool _memoryLoading = true;
  String? _memoryError;

  @override
  void initState() {
    super.initState();
    _load();
    _loadMemory();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await getIntegrationSettings();
      _forceRegenerate = settings['forceRegenerate'] == true;
      _screeningAnalysisMode = settings['screeningAnalysisMode'] == 'full'
          ? 'full'
          : 'incremental';
    } on ApiException catch (error) {
      _error = error.message.contains('No static resource')
          ? '后端暂未提供集成配置接口'
          : error.message;
    } catch (_) {
      _error = '集成配置加载失败';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(bool value) async {
    if (_saving) return;
    final previous = _forceRegenerate;
    setState(() {
      _forceRegenerate = value;
      _saving = true;
    });
    try {
      final saved = await updateIntegrationSettings(
        forceRegenerate: value,
        screeningAnalysisMode: _screeningAnalysisMode,
      );
      if (mounted) {
        setState(() {
          _forceRegenerate = saved['forceRegenerate'] == true;
          _screeningAnalysisMode = saved['screeningAnalysisMode'] == 'full'
              ? 'full'
              : 'incremental';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _forceRegenerate = previous);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_errorText(error, '保存失败'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setScreeningMode(String mode) async {
    if (_saving || mode == _screeningAnalysisMode) return;
    final previous = _screeningAnalysisMode;
    setState(() {
      _screeningAnalysisMode = mode;
      _saving = true;
    });
    try {
      final saved = await updateIntegrationSettings(
        forceRegenerate: _forceRegenerate,
        screeningAnalysisMode: mode,
      );
      if (mounted) {
        setState(() {
          _forceRegenerate = saved['forceRegenerate'] == true;
          _screeningAnalysisMode = saved['screeningAnalysisMode'] == 'full'
              ? 'full'
              : 'incremental';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _screeningAnalysisMode = previous);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_errorText(error, '保存失败'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadMemory() async {
    setState(() {
      _memoryLoading = true;
      _memoryError = null;
    });
    try {
      final memory = await getEnterpriseMemory();
      if (mounted) setState(() => _memory = memory);
    } catch (error) {
      if (mounted) {
        setState(() {
          _memory = null;
          _memoryError = error is ApiException
              ? error.message.contains('No static resource')
                    ? '接口未部署'
                    : error.message
              : '加载失败';
        });
      }
    } finally {
      if (mounted) setState(() => _memoryLoading = false);
    }
  }

  Future<void> _openMemory() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const EnterpriseMemoryPage()),
    );
    if (mounted) await _loadMemory();
  }

  Future<void> _refresh() async {
    await Future.wait<void>([_load(), _loadMemory()]);
  }

  void _openKnowledge() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const EnterpriseKnowledgePage()),
    );
  }

  void _openSessions() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const EnterpriseAgentSessionsPage(),
      ),
    );
  }

  String get _memorySummary {
    if (_memoryLoading) return '加载中…';
    if (_memoryError != null) return '$_memoryError，可查看页面';
    final memory = _memory;
    if (memory == null) return '查看已保存偏好';
    return '${memory.enabled ? '已开启' : '已关闭'} · ${memory.items.length} 条';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text(
        '集成配置',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.brand,
        ),
      ),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (_error != null) ...[
                  _inlineNotice(_error!),
                  const SizedBox(height: 12),
                ],
                _sectionLabel('AI 策略'),
                const SizedBox(height: 8),
                _card([
                  _switchRow(
                    icon: Icons.auto_awesome_rounded,
                    title: '强制重新生成解析',
                    subtitle: _forceRegenerate ? '已开启，每次都重新生成' : '已关闭，优先复用已有解析',
                    value: _forceRegenerate,
                    onChanged: _saving ? null : _toggle,
                  ),
                  _divider,
                  _switchRow(
                    icon: Icons.people_alt_outlined,
                    title: '强制全量分析',
                    subtitle: _screeningAnalysisMode == 'full'
                        ? '已开启，每次分析全部求职者'
                        : '已关闭，仅补充新增分析',
                    value: _screeningAnalysisMode == 'full',
                    onChanged: _saving
                        ? null
                        : (value) =>
                              _setScreeningMode(value ? 'full' : 'incremental'),
                  ),
                ]),
                const SizedBox(height: 20),
                _sectionLabel('Agent 管理'),
                const SizedBox(height: 8),
                _card([
                  _navRow(
                    icon: Icons.psychology_outlined,
                    title: '长期记忆',
                    subtitle: _memorySummary,
                    onTap: _openMemory,
                  ),
                  _divider,
                  _navRow(
                    icon: Icons.menu_book_outlined,
                    title: '企业知识库',
                    subtitle: '管理检索资料与文档',
                    onTap: _openKnowledge,
                  ),
                  _divider,
                  _navRow(
                    icon: Icons.forum_outlined,
                    title: '对话与上下文',
                    subtitle: '重置上下文、删除对话',
                    onTap: _openSessions,
                  ),
                ]),
              ],
            ),
          ),
  );

  Widget _card(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.hairline),
    ),
    child: Column(children: children),
  );

  Widget get _divider => const Divider(
    height: 1,
    indent: 14,
    endIndent: 14,
    color: AppColors.hairline,
  );

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.brand,
      ),
    ),
  );

  Widget _switchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
    minVerticalPadding: 8,
    visualDensity: VisualDensity.compact,
    leading: Icon(icon, size: 20, color: AppColors.interactive),
    title: Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    ),
    subtitle: Text(
      subtitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
    ),
    trailing: Transform.scale(
      scale: .86,
      child: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.interactive,
        activeTrackColor: AppColors.primarySoft,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
  );

  Widget _navRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
    minVerticalPadding: 9,
    visualDensity: VisualDensity.compact,
    leading: Icon(icon, size: 20, color: AppColors.interactive),
    title: Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    ),
    subtitle: Text(
      subtitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
    ),
    trailing: const Icon(
      Icons.chevron_right,
      size: 18,
      color: AppColors.textMuted,
    ),
    onTap: onTap,
  );

  Widget _inlineNotice(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, size: 14, color: AppColors.interactive),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );

  static String _errorText(Object error, String fallback) =>
      error is ApiException ? error.message : fallback;
}
