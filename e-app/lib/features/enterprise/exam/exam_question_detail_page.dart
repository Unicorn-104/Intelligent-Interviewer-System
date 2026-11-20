import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../api/exam_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import 'exam_question_form.dart';

/// 题目详情：展示题干、选项、标准答案和答案解析。
class ExamQuestionDetailPage extends StatefulWidget {
  const ExamQuestionDetailPage({
    super.key,
    required this.question,
    this.loadQuestion = getExamQuestion,
  });

  final Map<String, dynamic> question;
  final Future<Map<String, dynamic>> Function(int questionId) loadQuestion;

  @override
  State<ExamQuestionDetailPage> createState() => _ExamQuestionDetailPageState();
}

class _ExamQuestionDetailPageState extends State<ExamQuestionDetailPage> {
  Map<String, dynamic>? _detail;
  String? _error;
  bool _loading = true;
  bool _editing = false;

  bool get _isEnterprise => (_detail ?? widget.question)['companyId'] != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = _asInt(widget.question['questionId']);
    if (id == null) {
      setState(() {
        _loading = false;
        _error = '题目信息不完整';
      });
      return;
    }
    if (_hasEmbeddedDetail(widget.question)) {
      final embedded = Map<String, dynamic>.from(widget.question);
      if (embedded['options'] is! List && embedded['optionsJson'] != null) {
        try {
          final parsed = jsonDecode('${embedded['optionsJson']}');
          if (parsed is List) embedded['options'] = parsed;
        } catch (_) {
          // 保留题目基础信息，选项无法解析时仍可查看答案和解析。
        }
      }
      setState(() {
        _detail = embedded;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.loadQuestion(id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _detail = Map<String, dynamic>.from(widget.question);
        _error = '详情接口暂时不可用，当前显示题库已返回的信息：${error.message}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _detail = Map<String, dynamic>.from(widget.question);
        _error = '详情接口暂时不可用，当前显示题库已返回的信息';
      });
    }
  }

  Future<void> _edit() async {
    if (!_isEnterprise || _editing) return;
    _editing = true;
    try {
      final saved = await showExamQuestionForm(
        context,
        question: _detail ?? widget.question,
      );
      if (saved == true && mounted) await _load();
    } finally {
      _editing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _detail ?? widget.question;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('题目详情'),
        actions: [
          if (_isEnterprise)
            IconButton(
              key: const ValueKey('exam-question-edit'),
              tooltip: '编辑题目',
              onPressed: _editing ? null : _edit,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _detail == null
          ? _errorView()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  if (_error != null)
                    _warningBanner(_error!),
                  _summary(q),
                  const SizedBox(height: 12),
                  _questionCard(q),
                  if (_options(q).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _optionsCard(q),
                  ],
                  const SizedBox(height: 12),
                  _answerCard(q),
                  const SizedBox(height: 12),
                  _analysisCard(q),
                ],
              ),
            ),
    );
  }

  bool _hasEmbeddedDetail(Map<String, dynamic> q) {
    return q['answer'] != null ||
        q['analysis'] != null ||
        q['options'] is List ||
        q['optionsJson'] != null;
  }

  Widget _warningBanner(String message) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(message, style: const TextStyle(color: AppColors.warning, fontSize: 12)),
  );

  Widget _summary(Map<String, dynamic> q) {
    final color = _typeColor(_asInt(q['type']));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _pill(_typeName(_asInt(q['type'])), color),
        _pill(_difficultyName(_asInt(q['difficulty'])), AppColors.warning),
        _pill('${_scoreText(q['score'])} 分', AppColors.interactive),
        _pill(
          _isEnterprise ? '企业题库' : '平台题库',
          _isEnterprise ? AppColors.green : AppColors.textMuted,
        ),
      ],
    );
  }

  Widget _questionCard(Map<String, dynamic> q) => _section(
    title: '题目',
    icon: Icons.help_outline_rounded,
    color: _typeColor(_asInt(q['type'])),
    child: Text(
      '${q['content'] ?? ''}',
      style: const TextStyle(
        color: AppColors.body,
        fontSize: 18,
        height: 1.55,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _optionsCard(Map<String, dynamic> q) {
    final answer = _answerLabels(q['answer']);
    final options = _options(q);
    return _section(
      title: '选项',
      icon: Icons.format_list_bulleted_rounded,
      color: AppColors.interactive,
      child: Column(
        children: [
          for (final option in options)
            _optionRow(option, highlighted: answer.contains(option.$1)),
        ],
      ),
    );
  }

  Widget _optionRow((String, String) option, {required bool highlighted}) {
    final color = highlighted ? AppColors.green : AppColors.bodySoft;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.green.withValues(alpha: .1)
            : AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted ? AppColors.green : AppColors.primarySoft,
          width: highlighted ? 1.3 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${option.$1}.',
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(option.$2, style: TextStyle(color: color, height: 1.4)),
          ),
          if (highlighted)
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.green,
              size: 18,
            ),
        ],
      ),
    );
  }

  Widget _answerCard(Map<String, dynamic> q) {
    final answer = '${q['answer'] ?? ''}'.trim();
    return _section(
      title: '正确答案',
      icon: Icons.check_circle_outline_rounded,
      color: AppColors.green,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          answer.isEmpty ? '暂无答案' : answer,
          style: const TextStyle(
            color: AppColors.green,
            fontSize: 16,
            height: 1.45,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _analysisCard(Map<String, dynamic> q) {
    final analysis = '${q['analysis'] ?? ''}'.trim();
    return _section(
      title: '答案解析',
      icon: Icons.lightbulb_outline_rounded,
      color: AppColors.warning,
      child: Text(
        analysis.isEmpty ? '暂无答案解析' : analysis,
        style: TextStyle(
          color: analysis.isEmpty ? AppColors.textMuted : AppColors.bodySoft,
          fontSize: 14,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: .05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );

  Widget _errorView() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_error ?? '加载失败'),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _load, child: const Text('重试')),
      ],
    ),
  );

  List<(String, String)> _options(Map<String, dynamic> q) {
    final raw = q['options'];
    if (raw is! List) return const [];
    return raw
        .map((item) {
          if (item is Map) {
            final label = '${item['label'] ?? ''}'.trim();
            final text = '${item['text'] ?? item['value'] ?? ''}'.trim();
            return (label, text);
          }
          return ('', '$item');
        })
        .where((item) => item.$1.isNotEmpty || item.$2.isNotEmpty)
        .toList();
  }

  Set<String> _answerLabels(Object? value) => '${value ?? ''}'
      .split(RegExp(r'[,，、\s]+'))
      .map((item) => item.trim().toUpperCase())
      .where((item) => item.isNotEmpty)
      .toSet();

  int? _asInt(Object? value) => int.tryParse('$value');

  String _typeName(int? type) => switch (type) {
    1 => '单选题',
    2 => '多选题',
    3 => '判断题',
    4 => '简答题',
    5 => '编程题',
    _ => '题目',
  };

  String _difficultyName(int? value) => switch (value) {
    1 => '简单',
    2 => '中等',
    3 => '困难',
    _ => '未标注难度',
  };

  String _scoreText(Object? value) {
    final score = double.tryParse('$value');
    if (score == null) return '—';
    return score == score.roundToDouble()
        ? score.toInt().toString()
        : score.toString();
  }

  Color _typeColor(int? type) => switch (type) {
    1 => AppColors.interactive,
    2 => AppColors.purple,
    3 => AppColors.green,
    4 => AppColors.warning,
    5 => AppColors.error,
    _ => AppColors.textMuted,
  };
}
