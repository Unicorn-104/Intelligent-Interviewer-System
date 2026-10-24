import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../theme/app_theme.dart';
import '../../notification/data/message_data_source.dart';
import '../data/talent_contact_data_source.dart';

class TalentContactSheet extends StatefulWidget {
  const TalentContactSheet({
    super.key,
    this.talentId,
    this.userId,
    required this.source,
  }) : assert((talentId == null) != (userId == null));
  final int? talentId, userId;
  final TalentContactDataSource source;
  @override
  State<TalentContactSheet> createState() => _TalentContactSheetState();
}

class _TalentContactSheetState extends State<TalentContactSheet> {
  final _text = TextEditingController();
  TalentContactTarget? _target;
  Map<String, dynamic>? _session;
  bool _loading = true, _sending = false, _uncertain = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_sending) return;
    setState(() {
      _loading = true;
      _error = null;
      _target = null;
      _session = null;
    });
    try {
      final target = widget.userId != null
          ? await widget.source.loadUserTarget(widget.userId!)
          : await widget.source.loadTarget(widget.talentId!);
      final session = await widget.source.findSession(target);
      if (mounted) {
        setState(() {
          _target = target;
          _session = session;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = messageError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_sending || _loading || _target == null || _uncertain) return;
    final text = _text.text.trim();
    if (text.isEmpty || text.length > 1000) {
      setState(() => _error = '请输入1至1000字的招呼语');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final session = await widget.source.sendGreeting(_target!, text);
      if (mounted) Navigator.pop(context, session);
    } catch (error) {
      if (mounted) {
        setState(() {
          _uncertain = error is! ApiException || error.code == null;
          _error = _uncertain
              ? '发送结果待核对，请刷新会话后进入聊天核对，避免重复发送'
              : messageError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '主动沟通',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('talent-contact-close'),
                    tooltip: '关闭',
                    onPressed: _sending ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('正在核对求职者账号与沟通记录…'),
                ),
              if (!_loading && _target != null) Text('联系：${_target!.name}'),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              if (!_loading && _session != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('已有沟通记录，进入聊天继续交流。'),
                ),
                FilledButton(
                  key: const Key('talent-contact-continue'),
                  onPressed: _sending
                      ? null
                      : () => Navigator.pop(context, _session),
                  child: const Text('进入聊天'),
                ),
              ] else if (!_loading && _target != null && !_uncertain) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '首次联系需发送一条招呼语，点击发送前不会创建会话或自动联系候选人。',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
                TextField(
                  key: const Key('talent-contact-input'),
                  controller: _text,
                  enabled: !_sending,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: '招呼语',
                    hintText: '介绍岗位并说明联系意向',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('talent-contact-send'),
                  onPressed: _sending ? null : _send,
                  child: Text(_sending ? '发送中…' : '发送并进入聊天'),
                ),
              ],
              if (!_loading && (_error != null || _uncertain))
                TextButton(
                  key: const Key('talent-contact-retry'),
                  onPressed: _sending ? null : _load,
                  child: Text(_uncertain ? '刷新并核对会话' : '重新读取'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
