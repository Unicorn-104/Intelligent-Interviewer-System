import 'package:flutter/material.dart';

import '../../../api/integration_settings_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';

class IntegrationSettingsPage extends StatefulWidget {
  const IntegrationSettingsPage({super.key});

  @override
  State<IntegrationSettingsPage> createState() => _IntegrationSettingsPageState();
}

class _IntegrationSettingsPageState extends State<IntegrationSettingsPage> {
  bool _loading = true;
  bool _saving = false;
  bool _forceRegenerate = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _forceRegenerate = await getExamAnalysisForceRegenerate();
    } on ApiException catch (error) {
      _error = error.message;
    } catch (_) {
      _error = '集成配置加载失败，请稍后重试';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(bool value) async {
    if (_saving) return;
    final previous = _forceRegenerate;
    setState(() { _forceRegenerate = value; _saving = true; });
    try {
      final saved = await updateExamAnalysisForceRegenerate(value);
      if (mounted) setState(() => _forceRegenerate = saved);
    } catch (error) {
      if (!mounted) return;
      setState(() => _forceRegenerate = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error is ApiException ? error.message : '保存配置失败，请稍后重试')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('集成配置')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  _notice(_error!),
                  const SizedBox(height: 12),
                ],
                _section(
                  icon: Icons.auto_awesome_rounded,
                  title: '笔试 AI 解析策略',
                  subtitle: '控制新增题目和批量补全解析时是否复用数据库内容',
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _forceRegenerate,
                    onChanged: _saving ? null : _toggle,
                    title: const Text('强制重新生成解析', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      _forceRegenerate
                          ? '已开启：每次都请求 AI，覆盖已有解析'
                          : '已关闭：优先读取数据库，缺少解析时才请求 AI',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    activeThumbColor: AppColors.interactive,
                    activeTrackColor: AppColors.primarySoft,
                  ),
                ),
                const SizedBox(height: 12),
                _notice('关闭开关可以避免重复消耗 AI 配额，并保证同一题目的解析在各端保持一致。'),
              ],
            ),
          ),
  );

  Widget _section({required IconData icon, required String title, required String subtitle, required Widget child}) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .035), blurRadius: 12, offset: const Offset(0, 5))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: AppColors.interactive)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ])),
      ]),
      const SizedBox(height: 8),
      child,
    ]),
  );

  Widget _notice(String text) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5)),
  );
}
