import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../data/talent_detail_data_source.dart';
import '../models/talent_detail_view_data.dart';
import 'talent_match_analysis_section.dart';

class TalentGreetingSheet extends StatefulWidget {
  const TalentGreetingSheet({
    super.key,
    required this.candidateId,
    required this.name,
    required this.source,
    this.job,
  });
  final int candidateId;
  final String name;
  final TalentDetailDataSource source;
  final TalentJobContext? job;
  @override
  State<TalentGreetingSheet> createState() => _TalentGreetingSheetState();
}

class _TalentGreetingSheetState extends State<TalentGreetingSheet> {
  final _text = TextEditingController();
  bool _loading = true, _template = false;
  String? _error;
  Map<String, dynamic>? _existing;
  int _request = 0;
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
    final request = ++_request;
    final before = _text.text;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.source.loadGreeting(widget.candidateId);
      if (!mounted || request != _request) {
        return;
      }
      setState(() {
        _existing = result;
        if (_text.text == before && before.isEmpty) {
          _text.text = talentText(result?['content'], '');
        }
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = talentError(error));
      }
    } finally {
      if (mounted && request == _request) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _generate() async {
    if (_text.text.trim().isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('替换当前招呼语草稿？'),
          content: const Text('当前编辑内容将被本地模板替换。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('替换'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) {
        return;
      }
    }
    setState(() {
      _template = true;
      _text.text = talentGreetingTemplate(name: widget.name, job: widget.job);
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '招呼语预览与编辑',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const TalentAiInfoButton(),
            ],
          ),
          const Text(
            '模板草稿，非实时 AI 生成',
            style: TextStyle(fontSize: 12, color: AppColors.bodySoft),
          ),
          const Text(
            '仅在当前面板编辑和预览；关闭后不保存。',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (_loading)
            const LinearProgressIndicator()
          else if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('重试读取已有文案')),
          ] else if (_existing == null)
            const Text('暂无已有招呼语')
          else ...[
            const Text('候选人已有文案'),
            if (_existing!['status'] != null)
              Text('原文案状态：${_existing!['status']}'),
            if (_existing!['sentAt'] != null)
              Text('原文案发送时间：${_existing!['sentAt']}'),
          ],
          if (_template) const Text('当前内容：本地模板草稿'),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            minLines: 4,
            maxLines: 9,
            decoration: const InputDecoration(labelText: '招呼语草稿'),
          ),
          OutlinedButton(
            onPressed: _loading ? null : _generate,
            child: const Text('生成模板草稿'),
          ),
          const SizedBox(height: 8),
          const Text('预览'),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _text,
            builder: (context, value, child) =>
                SelectableText(value.text.isEmpty ? '请输入或生成草稿' : value.text),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭预览'),
          ),
        ],
      ),
    ),
  );
}
