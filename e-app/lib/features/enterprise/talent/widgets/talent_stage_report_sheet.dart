import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../theme/app_theme.dart';
import '../data/talent_detail_data_source.dart';
import '../data/talent_stage_report_loader.dart';
import '../models/talent_detail_view_data.dart';

/// 仅查看本轮实际会话的已有报告，不生成或写入评估，也不复用演示报告页。
class TalentStageReportSheet extends StatefulWidget {
  const TalentStageReportSheet({
    super.key,
    required this.stageName,
    required this.candidateId,
    required this.positionId,
    required this.sessions,
    required this.source,
  });
  final String stageName;
  final int candidateId, positionId;
  final List<TalentStageSession> sessions;
  final TalentDetailDataSource source;

  @override
  State<TalentStageReportSheet> createState() => _TalentStageReportSheetState();
}

class _TalentStageReportSheetState extends State<TalentStageReportSheet> {
  late int _sessionId;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _report;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessions.first.id;
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    final id = _sessionId;
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });
    try {
      final report = await widget.source.loadInterviewReport(id);
      if (talentId(report['sessionId']) != id ||
          talentId(report['candidateId']) != widget.candidateId ||
          report['positionId'] != null &&
              talentId(report['positionId']) != widget.positionId) {
        throw const FormatException('报告与本轮面试不匹配，暂无法展示');
      }
      if (mounted && request == _request) setState(() => _report = report);
    } catch (error) {
      if (mounted && request == _request) {
        setState(
          () =>
              _error = error is ApiException && error.message == '面试记录或评估结果不存在'
              ? '本轮面试已开始，AI总结报告尚未生成'
              : talentError(error),
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  String _value(Object? value) => switch (value) {
    null => '',
    String() => value.trim(),
    List() => value.map(_value).where((s) => s.isNotEmpty).join('\n'),
    Map() =>
      value.entries
          .map((entry) => '${entry.key}：${_value(entry.value)}')
          .join('\n'),
    _ => '$value',
  };

  Widget _section(String title, String content) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.brand,
          ),
        ),
        const SizedBox(height: 6),
        SelectableText(
          content,
          style: const TextStyle(color: AppColors.body, height: 1.5),
        ),
      ],
    ),
  );

  List<Widget> _content(Map<String, dynamic> report) {
    final sections = <Widget>[];
    final score = talentNumber(report['overallScore']);
    if (score != null) {
      sections.add(_section('本轮综合评分', '$score 分'));
    }
    Object? dimensions = report['dimensionScores'];
    if (dimensions is String) {
      try {
        dimensions = jsonDecode(dimensions);
      } catch (_) {
        dimensions = null;
      }
    }
    if (dimensions is Map) {
      final values = <String>[];
      for (final entry in dimensions.entries) {
        final value = talentNumber(entry.value);
        if (value != null) values.add('${entry.key}：$value');
      }
      if (values.isNotEmpty) sections.add(_section('维度评分', values.join('\n')));
    }
    for (final field in const {
      'summary': '本轮总结',
      'advantages': '表现亮点',
      'risks': '风险提示',
      'gaps': '待提升项',
      'recommendation': '评估建议',
    }.entries) {
      final text = _value(report[field.key]);
      if (text.isNotEmpty) sections.add(_section(field.value, text));
    }
    if (sections.isEmpty) {
      sections.add(
        const Text('本轮暂无总结内容', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return sections;
  }

  String _time(DateTime time) => TalentUtc8.serverTime(time);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '本轮AI总结报告',
                    style: TextStyle(
                      color: AppColors.brand,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    widget.stageName,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('talent-stage-report-close'),
              tooltip: '关闭报告',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.sessions.length > 1)
          DropdownButtonFormField<int>(
            key: const Key('talent-stage-report-session'),
            initialValue: _sessionId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '本轮面试场次'),
            items: [
              for (final session in widget.sessions)
                DropdownMenuItem(
                  value: session.id,
                  child: Text(_time(session.startedAt)),
                ),
            ],
            onChanged: (id) {
              if (id != null && id != _sessionId) {
                setState(() => _sessionId = id);
                _load();
              }
            },
          ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          key: const Key('talent-stage-report-retry'),
                          onPressed: _load,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  key: const Key('talent-stage-report-content'),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'AI结果仅供参考',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    ..._content(_report!),
                  ],
                ),
        ),
      ],
    ),
  );
}
