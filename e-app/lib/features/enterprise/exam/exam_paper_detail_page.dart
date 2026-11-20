import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../api/exam_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';

/// 试卷只读阅览页：题目、选项、标准答案和解析均不可编辑。
class ExamPaperDetailPage extends StatefulWidget {
  const ExamPaperDetailPage({super.key, required this.paper, this.loadPaper = getExamPaper});

  final Map<String, dynamic> paper;
  final Future<Map<String, dynamic>> Function(int paperId) loadPaper;

  @override
  State<ExamPaperDetailPage> createState() => _ExamPaperDetailPageState();
}

class _ExamPaperDetailPageState extends State<ExamPaperDetailPage> {
  Map<String, dynamic>? _detail;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = _asInt(widget.paper['paperId']);
    if (id <= 0) {
      setState(() {
        _loading = false;
        _error = '试卷信息不完整';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.loadPaper(id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _detail = Map<String, dynamic>.from(widget.paper);
        _error = '题目清单暂时无法加载：${error.message}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _detail = Map<String, dynamic>.from(widget.paper);
        _error = '题目清单暂时无法加载，请稍后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final paper = _detail ?? widget.paper;
    final questions = (paper['questions'] as List?)
            ?.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        const <Map<String, dynamic>>[];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('试卷阅览'),
        actions: [
          IconButton(
            tooltip: '重新加载',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _header(paper, questions.length),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _notice(_error!),
                  ],
                  const SizedBox(height: 14),
                  if (questions.isEmpty)
                    _notice('当前暂未返回题目清单，请稍后重试。')
                  else
                    ...questions.asMap().entries.map(
                          (entry) => _questionCard(entry.value, entry.key),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _header(Map<String, dynamic> paper, int questionCount) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.interactive.withValues(alpha: .16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              paper['name']?.toString() ?? '未命名试卷',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              paper['positionTitle']?.toString() ?? '未关联岗位',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill('共 $questionCount 题', AppColors.interactive),
                _pill('总分 ${_scoreText(paper['totalScore'])}', AppColors.green),
                _pill('${_asInt(paper['durationMin'])} 分钟', AppColors.orange),
              ],
            ),
          ],
        ),
      );

  Widget _questionCard(Map<String, dynamic> question, int index) {
    final type = _asInt(question['type']);
    final color = _typeColor(type);
    final answer = '${question['answer'] ?? ''}'.trim();
    final answerLabels = answer
        .split(RegExp(r'[,，、\s]+'))
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toSet();
    final options = _options(question);
    final analysis = '${question['analysis'] ?? ''}'.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .035), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pill('第 ${index + 1} 题', color),
              const SizedBox(width: 8),
              Text(_typeName(type), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${_scoreText(question['score'])} 分', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          Text('${question['content'] ?? ''}', style: const TextStyle(fontSize: 16, height: 1.55, color: AppColors.ink, fontWeight: FontWeight.w700)),
          if (options.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final option in options)
              _optionRow(option, answerLabels.contains(option.$1.toUpperCase())),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(color: AppColors.green.withValues(alpha: .1), borderRadius: BorderRadius.circular(10)),
            child: Text('标准答案：${answer.isEmpty ? '暂无' : answer}', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          if (analysis.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
              child: Text('解析：$analysis', style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.65)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _optionRow((String, String) option, bool correct) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: correct ? AppColors.green.withValues(alpha: .1) : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: correct ? AppColors.green : AppColors.hairline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${option.$1}.', style: TextStyle(color: correct ? AppColors.green : AppColors.body, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Expanded(child: Text(option.$2, style: TextStyle(color: correct ? AppColors.green : AppColors.body, fontSize: 13, height: 1.45))),
            if (correct) const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 17),
          ],
        ),
      );

  List<(String, String)> _options(Map<String, dynamic> question) {
    Object? raw = question['options'];
    if (raw is! List && question['optionsJson'] != null) {
      try {
        raw = jsonDecode('${question['optionsJson']}');
      } catch (_) {
        raw = null;
      }
    }
    if (raw is! List) return const [];
    return raw.map((item) {
      if (item is Map) return ('${item['label'] ?? ''}', '${item['text'] ?? item['value'] ?? ''}');
      return ('', '$item');
    }).where((item) => item.$1.isNotEmpty || item.$2.isNotEmpty).toList();
  }

  Widget _notice(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
        child: Text(message, style: const TextStyle(color: AppColors.warning, fontSize: 12, height: 1.5)),
      );

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );

  static int _asInt(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;

  static String _scoreText(Object? value) {
    final score = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return score == score.roundToDouble() ? '${score.toInt()}' : score.toString();
  }

  static String _typeName(int type) => switch (type) {
        1 => '单选题',
        2 => '多选题',
        3 => '判断题',
        4 => '简答题',
        5 => '编程题',
        _ => '自定义题',
      };

  static Color _typeColor(int type) => switch (type) {
        1 => AppColors.interactive,
        2 => AppColors.purple,
        3 => AppColors.green,
        4 => AppColors.orange,
        5 => AppColors.error,
        _ => AppColors.textMuted,
      };
}
