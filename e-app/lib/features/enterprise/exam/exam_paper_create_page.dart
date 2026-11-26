import 'package:flutter/material.dart';

import '../../../api/exam_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';

typedef ExamQuestionLoader = Future<List<Map<String, dynamic>>> Function();
typedef ExamPaperSubmit = Future<int?> Function({
  required String name,
  required int positionId,
  required int durationMin,
  required String mode,
  List<Map<String, dynamic>>? rule,
  List<String>? bankScopes,
  List<Map<String, dynamic>>? questions,
});

/// 新建试卷组卷页（设计稿③）。
///
/// 后端 createPaper：random 模式提交 rule={rules:[...],scopes:[...]}，
/// manual 模式提交 questions=[{questionId,score}]，总分由后端计算。
/// 随机抽题只从已勾选的平台题库 / 企业题库来源中按题型和难度抽取。
class ExamPaperCreatePage extends StatefulWidget {
  const ExamPaperCreatePage({
    super.key,
    required this.jobs,
    this.loadQuestions,
    this.submitPaper,
  });

  final List<Map<String, dynamic>> jobs;
  final ExamQuestionLoader? loadQuestions;
  final ExamPaperSubmit? submitPaper;

  @override
  State<ExamPaperCreatePage> createState() => _ExamPaperCreatePageState();
}

class _Rule {
  int type = 1;
  int difficulty = 0; // 0=不限
  int count = 5;
  double score = 5;
}

class _ExamPaperCreatePageState extends State<ExamPaperCreatePage> {
  final _nameCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '60');
  int? _positionId;
  String _mode = 'random';
  final List<_Rule> _rules = [
    _Rule()..type = 1,
    _Rule()..type = 2,
    _Rule()..type = 4,
  ];

  List<Map<String, dynamic>> _questions = const [];
  final Set<int> _selected = {};
  final Set<String> _bankScopes = {'platform', 'enterprise'};
  bool _loadingQuestions = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.jobs.isNotEmpty) {
      _positionId = _asInt(widget.jobs.first['posId']);
    }
    _loadQuestions();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final rows =
          await (widget.loadQuestions?.call() ??
              listExamQuestions(pageSize: 200));
      if (!mounted) return;
      setState(() {
        _questions = rows;
        _loadingQuestions = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingQuestions = false);
    }
  }

  int get _platformCount =>
      _questions.where((q) => q['companyId'] == null).length;
  int get _enterpriseCount =>
      _questions.where((q) => q['companyId'] != null).length;

  double get _randomTotal =>
      _rules.fold(0, (sum, r) => sum + r.count * r.score);

  double get _manualTotal => _questions
      .where((q) => _selected.contains(_asInt(q['questionId'])))
      .fold(0.0, (sum, q) => sum + _asDouble(q['score']));

  @override
  Widget build(BuildContext context) {
    final total = _mode == 'random' ? _randomTotal : _manualTotal;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.brand,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          '新建试卷',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.body,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        children: [
          _formCard(total),
          const SizedBox(height: 16),
          if (_mode == 'random') ...[
            _bankSection(),
            const SizedBox(height: 16),
            _ruleCard(),
          ] else
            _manualSection(),
          const SizedBox(height: 90),
        ],
      ),
      bottomSheet: _bottomBar(),
    );
  }

  // ==================== 表单卡片 ====================

  Widget _formCard(double total) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('试卷名称'),
          _input(_nameCtrl, '请输入试卷名称', key: const Key('exam-paper-name')),
          const SizedBox(height: 14),
          _label('关联岗位'),
          _jobDropdown(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('考试时长'),
                    _input(
                      _durationCtrl,
                      '分钟',
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('总分'),
                    Text(
                      '${_trim(total)}分',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.interactive,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _label('组卷方式'),
          Row(
            children: [
              Expanded(child: _modeButton('random', '随机抽题')),
              const SizedBox(width: 12),
              Expanded(child: _modeButton('manual', '人工组卷')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeButton(String mode, String label) {
    final selected = _mode == mode;
    return InkWell(
      onTap: () => setState(() => _mode = mode),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.interactive : AppColors.canvas,
          border: Border.all(
            color: selected ? AppColors.interactive : AppColors.hairline,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.bodySoft,
          ),
        ),
      ),
    );
  }

  // ==================== 选择题库 ====================

  Widget _bankSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择题库',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.interactive,
          ),
        ),
        const SizedBox(height: 10),
        _card(
          child: Column(
            children: [
              _bankRow(
                'platform',
                '平台题库',
                _loadingQuestions ? null : _platformCount,
              ),
              const Divider(height: 12),
              _bankRow(
                'enterprise',
                '企业题库',
                _loadingQuestions ? null : _enterpriseCount,
              ),
              const SizedBox(height: 8),
              const Text(
                '仅从已勾选的题库中随机抽取题目，至少保留一个题库',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bankRow(String scope, String name, int? count) {
    final selected = _bankScopes.contains(scope);
    final enabled = !_loadingQuestions && (selected || (count ?? 0) > 0);
    return Material(
      color: Colors.transparent,
      child: CheckboxListTile(
        key: Key('exam-paper-bank-$scope'),
        value: selected,
        onChanged: enabled
            ? (value) => _toggleBank(scope, value == true)
            : null,
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.interactive,
        title: Row(
          children: [
            const Icon(
              Icons.folder_outlined,
              size: 18,
              color: AppColors.interactive,
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: const TextStyle(fontSize: 14, color: AppColors.body),
            ),
          ],
        ),
        secondary: Text(
          count == null ? '加载中…' : '$count题',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ),
    );
  }

  void _toggleBank(String scope, bool selected) {
    if (selected) {
      setState(() => _bankScopes.add(scope));
      return;
    }
    if (_bankScopes.length <= 1) {
      _toast('至少选择一个题库');
      return;
    }
    setState(() => _bankScopes.remove(scope));
  }

  // ==================== 抽题规则 ====================

  Widget _ruleCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '抽题规则',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _rules.add(_Rule())),
                child: const Text(
                  '+ 添加',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.interactive,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ..._rules.asMap().entries.map(
            (entry) => _ruleRow(entry.key, entry.value),
          ),
        ],
      ),
    );
  }

  Widget _ruleRow(int index, _Rule rule) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.fieldBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _miniDropdown<int>(
                value: rule.type,
                items: const {1: '单选题', 2: '多选题', 3: '判断题', 4: '简答题', 5: '编程题'},
                onChanged: (v) => setState(() => rule.type = v ?? 1),
              ),
              const SizedBox(width: 8),
              _miniDropdown<int>(
                value: rule.difficulty,
                items: const {0: '不限难度', 1: '简单', 2: '中等', 3: '困难'},
                onChanged: (v) => setState(() => rule.difficulty = v ?? 0),
              ),
              const Spacer(),
              if (_rules.length > 1)
                InkWell(
                  onTap: () => setState(() => _rules.removeAt(index)),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _stepper(
                value: rule.count,
                onChanged: (v) => setState(() => rule.count = v),
              ),
              const SizedBox(width: 6),
              const Text(
                '题',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const Spacer(),
              const Text(
                '每题',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(width: 6),
              _scoreInput(rule),
              const SizedBox(width: 4),
              const Text(
                '分',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepper({required int value, required ValueChanged<int> onChanged}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepButton(
          Icons.remove_rounded,
          () => onChanged(value > 1 ? value - 1 : 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '$value',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        _stepButton(Icons.add_rounded, () => onChanged(value + 1)),
      ],
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppColors.canvas,
          border: Border.all(color: AppColors.hairline),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 15, color: AppColors.interactive),
      ),
    );
  }

  Widget _scoreInput(_Rule rule) {
    return SizedBox(
      width: 46,
      child: TextFormField(
        initialValue: _trim(rule.score),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.canvas,
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) => rule.score = double.tryParse(v) ?? rule.score,
      ),
    );
  }

  // ==================== 人工组卷 ====================

  Widget _manualSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择题目（已选 ${_selected.length} 题）',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (_loadingQuestions)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.interactive),
              ),
            )
          else if (_questions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('题库暂无题目')),
            )
          else
            ..._questions.map((q) {
              final id = _asInt(q['questionId']);
              final selected = _selected.contains(id);
              return CheckboxListTile(
                value: selected,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  q['content']?.toString() ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  '${_typeName(q['type'])} · ${_trim(_asDouble(q['score']))}分',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selected.add(id);
                  } else {
                    _selected.remove(id);
                  }
                }),
              );
            }),
        ],
      ),
    );
  }

  // ==================== 底部 ====================

  Widget _bottomBar() {
    return Container(
      color: AppColors.canvas,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.interactive),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text(
                '取消',
                style: TextStyle(color: AppColors.interactive),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              key: const Key('exam-paper-save'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.interactive,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : '保存试卷'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 0;
    if (name.isEmpty) {
      _toast('请输入试卷名称');
      return;
    }
    if (_positionId == null || _positionId == 0) {
      _toast('请选择关联岗位');
      return;
    }
    if (duration <= 0) {
      _toast('考试时长必须大于0');
      return;
    }

    List<Map<String, dynamic>>? rule;
    List<Map<String, dynamic>>? questions;
    if (_mode == 'random') {
      if (_bankScopes.isEmpty) {
        _toast('请至少选择一个题库');
        return;
      }
      final valid = _rules.where((r) => r.count > 0 && r.score > 0).toList();
      if (valid.isEmpty) {
        _toast('请至少配置一条有效的抽题规则');
        return;
      }
      rule = valid
          .map(
            (r) => <String, dynamic>{
              'type': r.type,
              if (r.difficulty > 0) 'difficulty': r.difficulty,
              'count': r.count,
              'score': r.score,
            },
          )
          .toList();
    } else {
      if (_selected.isEmpty) {
        _toast('请至少选择一道题');
        return;
      }
      questions = _questions
          .where((q) => _selected.contains(_asInt(q['questionId'])))
          .map(
            (q) => <String, dynamic>{
              'questionId': _asInt(q['questionId']),
              'score': _asDouble(q['score']),
            },
          )
          .toList();
    }

    setState(() => _saving = true);
    try {
      final submit = widget.submitPaper ?? createExamPaper;
      await submit(
        name: name,
        positionId: _positionId!,
        durationMin: duration,
        mode: _mode,
        rule: rule,
        bankScopes: _mode == 'random'
            ? const [
                'platform',
                'enterprise',
              ].where(_bankScopes.contains).toList(growable: false)
            : null,
        questions: questions,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      _toast(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ==================== 通用组件 ====================

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.body,
      ),
    ),
  );

  Widget _input(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    Key? key,
  }) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.fieldBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _jobDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.fieldBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _positionId,
          isExpanded: true,
          hint: const Text('请选择岗位'),
          items: widget.jobs
              .map(
                (j) => DropdownMenuItem<int>(
                  value: _asInt(j['posId']),
                  child: Text(j['title']?.toString() ?? '岗位'),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _positionId = v),
        ),
      ),
    );
  }

  Widget _miniDropdown<T>({
    required T value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          style: const TextStyle(fontSize: 12, color: AppColors.body),
          items: items.entries
              .map(
                (e) => DropdownMenuItem<T>(value: e.key, child: Text(e.value)),
              )
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

  static int _asInt(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  static double _asDouble(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static String _typeName(Object? type) {
    switch (_asInt(type)) {
      case 1:
        return '单选';
      case 2:
        return '多选';
      case 3:
        return '判断';
      case 4:
        return '简答';
      case 5:
        return '编程';
      default:
        return '自定义';
    }
  }

  static String _trim(double value) =>
      value == value.roundToDouble() ? '${value.toInt()}' : value.toString();
}
