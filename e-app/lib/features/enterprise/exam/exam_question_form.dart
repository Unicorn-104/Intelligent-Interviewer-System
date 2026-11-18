import 'package:flutter/material.dart';

import '../../../api/exam_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';

/// 新增/编辑企业题库题目（底部弹窗表单）。
///
/// 后端 buildQuestionParams 约定：type/content/answer/score 必填，
/// 选择题（type<=3）必须提供 options（[{label,text}]），difficulty 默认 2。
/// 返回 true 表示保存成功。
Future<bool?> showExamQuestionForm(
  BuildContext context, {
  Map<String, dynamic>? question,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.canvas,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ExamQuestionForm(question: question),
    ),
  );
}

class _ExamQuestionForm extends StatefulWidget {
  const _ExamQuestionForm({this.question});

  final Map<String, dynamic>? question;

  @override
  State<_ExamQuestionForm> createState() => _ExamQuestionFormState();
}

class _ExamQuestionFormState extends State<_ExamQuestionForm> {
  final _contentCtrl = TextEditingController();
  final _scoreCtrl = TextEditingController(text: '10');
  final _skillCtrl = TextEditingController();
  final _analysisCtrl = TextEditingController();
  final _answerTextCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls =
      List.generate(4, (_) => TextEditingController());

  int _type = 1;
  int _difficulty = 2;
  String _singleAnswer = 'A';
  bool _saving = false;

  bool get _isEdit => widget.question != null;
  bool get _isChoice => _type <= 2; // 单选/多选
  bool get _isJudge => _type == 3;
  bool get _needOptions => _type <= 3;
  bool get _isTextAnswer => _type >= 4; // 简答/编程

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    if (q != null) {
      _type = _asInt(q['type'], 1);
      _difficulty = _asInt(q['difficulty'], 2);
      _contentCtrl.text = q['content']?.toString() ?? '';
      _scoreCtrl.text = _trimScore(q['score']);
      _skillCtrl.text = q['skillTag']?.toString() ?? '';
      _analysisCtrl.text = q['analysis']?.toString() ?? '';
      final answer = q['answer']?.toString() ?? '';
      if (_type >= 4) {
        _answerTextCtrl.text = answer;
      } else {
        _singleAnswer = answer.isEmpty ? 'A' : answer.split(',').first;
      }
      final options = q['options'];
      if (options is List) {
        for (var i = 0; i < options.length && i < _optionCtrls.length; i++) {
          final opt = options[i];
          if (opt is Map) {
            _optionCtrls[i].text =
                (opt['text'] ?? opt['value'] ?? opt['label'] ?? '').toString();
          } else {
            _optionCtrls[i].text = opt.toString();
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _scoreCtrl.dispose();
    _skillCtrl.dispose();
    _analysisCtrl.dispose();
    _answerTextCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_isEdit ? '编辑题目' : '新增题目',
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _label('题型'),
          _dropdown<int>(
            value: _type,
            items: const {
              1: '单选题',
              2: '多选题',
              3: '判断题',
              4: '简答题',
              5: '编程题',
            },
            onChanged: (v) => setState(() => _type = v ?? 1),
          ),
          const SizedBox(height: 12),
          _label('题干'),
          _textField(_contentCtrl, '请输入题干', maxLines: 3),
          if (_needOptions) ...[
            const SizedBox(height: 12),
            _label(_isJudge ? '选项（固定为正确/错误）' : '选项'),
            if (_isJudge)
              const Text('A. 正确    B. 错误',
                  style: TextStyle(fontSize: 13, color: AppColors.bodySoft))
            else
              ...List.generate(4, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _textField(
                    _optionCtrls[i],
                    '选项 ${String.fromCharCode(65 + i)}',
                  ),
                );
              }),
          ],
          const SizedBox(height: 12),
          _label('标准答案'),
          if (_isTextAnswer)
            _textField(_answerTextCtrl, '请输入参考答案', maxLines: 2)
          else if (_isChoice && _type == 2)
            _textField(_answerTextCtrl, '多选答案，如 A,B',
                onChanged: null)
          else
            _dropdown<String>(
              value: _singleAnswer,
              items: {
                for (var i = 0; i < (_isJudge ? 2 : 4); i++)
                  String.fromCharCode(65 + i): String.fromCharCode(65 + i),
              },
              onChanged: (v) => setState(() => _singleAnswer = v ?? 'A'),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('分值'),
                    _textField(_scoreCtrl, '分值',
                        keyboardType: TextInputType.number),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('难度'),
                    _dropdown<int>(
                      value: _difficulty,
                      items: const {1: '简单', 2: '中等', 3: '困难'},
                      onChanged: (v) => setState(() => _difficulty = v ?? 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _label('技能标签（可选）'),
          _textField(_skillCtrl, '如 网络基础、Java'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.interactive,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : '保存'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final content = _contentCtrl.text.trim();
    final score = double.tryParse(_scoreCtrl.text.trim()) ?? 0;
    if (content.isEmpty) {
      _toast('请输入题干');
      return;
    }
    if (score <= 0) {
      _toast('分值必须大于0');
      return;
    }

    String answer;
    List<Map<String, String>>? options;
    if (_isTextAnswer) {
      answer = _answerTextCtrl.text.trim();
    } else if (_type == 2) {
      answer = _answerTextCtrl.text.trim();
    } else {
      answer = _singleAnswer;
    }
    if (answer.isEmpty) {
      _toast('请填写标准答案');
      return;
    }

    if (_isJudge) {
      options = [
        {'label': 'A', 'text': '正确'},
        {'label': 'B', 'text': '错误'},
      ];
    } else if (_isChoice) {
      final list = <Map<String, String>>[];
      for (var i = 0; i < _optionCtrls.length; i++) {
        final text = _optionCtrls[i].text.trim();
        if (text.isNotEmpty) {
          list.add({'label': String.fromCharCode(65 + i), 'text': text});
        }
      }
      if (list.length < 2) {
        _toast('选择题至少填写两个选项');
        return;
      }
      options = list;
    }

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await updateExamQuestion(
          _asInt(widget.question!['questionId'], 0),
          type: _type,
          content: content,
          answer: answer,
          score: score,
          difficulty: _difficulty,
          skillTag: _skillCtrl.text.trim(),
          analysis: _analysisCtrl.text.trim(),
          options: options,
        );
      } else {
        await saveExamQuestion(
          type: _type,
          content: content,
          answer: answer,
          score: score,
          difficulty: _difficulty,
          skillTag: _skillCtrl.text.trim(),
          analysis: _analysisCtrl.text.trim(),
          options: options,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      _toast(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ==================== 通用组件 ====================

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.body)),
      );

  Widget _textField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.fieldBackground,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.fieldBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items.entries
              .map((e) => DropdownMenuItem<T>(
                  value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static int _asInt(Object? value, int fallback) =>
      value is int ? value : int.tryParse('$value') ?? fallback;

  static String _trimScore(Object? value) {
    final d = value is num ? value.toDouble() : double.tryParse('$value') ?? 10;
    return d == d.roundToDouble() ? '${d.toInt()}' : d.toString();
  }
}
