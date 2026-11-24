import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../api/exam_api.dart';
import '../../../api/integration_settings_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../talent/widgets/talent_filter_icon.dart';
import 'exam_paper_create_page.dart';
import 'exam_paper_detail_page.dart';
import 'exam_question_detail_page.dart';
import 'exam_question_form.dart';
import 'widgets/exam_filter_sheet.dart';

/// 笔试管理：题库 + 试卷。
///
/// 设计稿：科技蓝主色、白色圆角卡片、浅蓝灰背景。
/// 题库归属按 companyId 区分：null=平台题库，否则为本企业题库。
/// 企业题库题目可编辑/删除，平台题库为共享只读。
class ExamManagementPage extends StatefulWidget {
  const ExamManagementPage({super.key});

  @override
  State<ExamManagementPage> createState() => _ExamManagementPageState();
}

class _ExamManagementPageState extends State<ExamManagementPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  // ---- 题库状态 ----
  List<Map<String, dynamic>> _questions = const [];
  bool _loadingQ = true;
  bool _batchAnalyzing = false;
  String? _errorQ;
  String? _scope; // null=全部 platform=平台 enterprise=企业
  int? _type;
  int? _difficulty;
  final _keywordCtrl = TextEditingController();

  // ---- 试卷状态 ----
  List<Map<String, dynamic>> _papers = const [];
  bool _loadingP = true;
  String? _errorP;
  int? _positionId;
  final _paperKeywordCtrl = TextEditingController();
  String _paperKeyword = '';
  List<Map<String, dynamic>> _jobs = const [];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    _loadPapers();
    _loadJobs();
  }

  @override
  void dispose() {
    _tab.dispose();
    _keywordCtrl.dispose();
    _paperKeywordCtrl.dispose();
    super.dispose();
  }

  // ==================== 数据加载 ====================

  Future<void> _loadQuestions() async {
    setState(() {
      _loadingQ = true;
      _errorQ = null;
    });
    try {
      final rows = await listExamQuestions(
        scope: _scope,
        type: _type,
        difficulty: _difficulty,
        keyword: _keywordCtrl.text.trim().isEmpty ? null : _keywordCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _questions = rows;
        _loadingQ = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorQ = error.message;
        _loadingQ = false;
      });
    }
  }

  Future<void> _batchFillAnalysis() async {
    if (_batchAnalyzing) return;
    final forceRegenerate = await getExamAnalysisForceRegenerate().catchError(
      (_) => false,
    );
    final targets = forceRegenerate
        ? _questions
        : _questions
              .where((question) => '${question['analysis'] ?? ''}'.trim().isEmpty)
              .toList();
    if (targets.isEmpty) {
      _toast(forceRegenerate ? '暂无可解析题目' : '所有题目已有解析');
      return;
    }
    final confirmed = await _confirm(
      '批量补全解析',
      forceRegenerate
          ? '将重新生成当前列表中的 ${targets.length} 道题目解析，是否继续？'
          : '将为 ${targets.length} 道缺少解析的题目生成 AI 解析，是否继续？',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _batchAnalyzing = true);
    var updated = 0;
    var failed = 0;
    var continuousFailed = 0;
    try {
      for (final question in targets) {
        try {
          final id = _asInt(question['questionId']);
          if (id <= 0) throw const FormatException('题目编号无效');
          final result = await aiAnalyzeExamQuestion(
            questionId: id,
            type: _asInt(question['type']),
            typeName: question['typeName']?.toString(),
            content: '${question['content'] ?? ''}',
            options: _analysisOptions(question),
            answer: '${question['answer'] ?? ''}',
            difficulty: _asInt(question['difficulty']),
            skillTag: question['skillTag']?.toString(),
          );
          final analysis = '${result['analysis'] ?? ''}'.trim();
          if (analysis.isEmpty) throw const FormatException('未返回有效解析');
          await fillExamQuestionAnalysis(id, analysis);
          updated++;
          continuousFailed = 0;
        } catch (_) {
          failed++;
          continuousFailed++;
          if (continuousFailed >= 3) break;
        }
      }
      await _loadQuestions();
      _toast('批量解析完成：成功 $updated 道，失败 $failed 道');
    } finally {
      if (mounted) setState(() => _batchAnalyzing = false);
    }
  }

  List<String>? _analysisOptions(Map<String, dynamic> question) {
    final type = _asInt(question['type']);
    if (type > 3 && type != 6) return null;
    final raw = question['options'];
    if (raw is! List) return null;
    final options = raw
        .map((item) {
          if (item is Map) {
            final label = '${item['label'] ?? ''}'.trim();
            final text = '${item['text'] ?? item['value'] ?? ''}'.trim();
            return [label, text].where((part) => part.isNotEmpty).join('. ');
          }
          return '$item'.trim();
        })
        .where((item) => item.isNotEmpty)
        .toList();
    return options.isEmpty ? null : options;
  }

  Future<void> _loadPapers() async {
    setState(() {
      _loadingP = true;
      _errorP = null;
    });
    try {
      final rows = await listExamPapers(positionId: _positionId);
      if (!mounted) return;
      setState(() {
        _papers = rows;
        _loadingP = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorP = error.message;
        _loadingP = false;
      });
    }
  }

  Future<void> _loadJobs() async {
    try {
      final rows = await listExamJobs();
      if (!mounted) return;
      setState(() => _jobs = rows);
    } on ApiException {
      // 岗位加载失败不阻塞题库/试卷展示。
    }
  }

  void _refresh() {
    if (_tab.index == 0) {
      _loadQuestions();
    } else {
      _loadPapers();
    }
  }

  // ==================== 框架 ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.brand),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          '笔试管理',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.body),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: _refresh,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                    color: AppColors.interactive, shape: BoxShape.circle),
                child: const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 19),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            color: AppColors.canvas,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.interactive,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              unselectedLabelStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              indicatorColor: AppColors.interactive,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              onTap: (_) => setState(() {}),
              tabs: const [Tab(text: '题库'), Tab(text: '试卷')],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final left = (_fabLeft ??
                  constraints.maxWidth - _fabSize - _fabMargin)
              .clamp(_fabMargin, _maxFabLeft(constraints))
              .toDouble();
          final bottom = _fabBottom
              .clamp(_fabMargin, _maxFabBottom(constraints))
              .toDouble();
          return Stack(
            children: [
              TabBarView(
                controller: _tab,
                children: [
                  _buildQuestionTab(),
                  _buildPaperTab(),
                ],
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                left: left,
                bottom: bottom,
                child: _buildDraggableFab(constraints),
              ),
            ],
          );
        },
      ),
    );
  }

  static const double _fabSize = 56;
  static const double _fabMargin = 12;
  double? _fabLeft;
  double _fabBottom = 20;

  double _maxFabLeft(BoxConstraints constraints) => math.max(
        _fabMargin,
        constraints.maxWidth - _fabSize - _fabMargin,
      );

  double _maxFabBottom(BoxConstraints constraints) => math.max(
        _fabMargin,
        constraints.maxHeight - _fabSize - _fabMargin,
      );

  Widget _buildDraggableFab(BoxConstraints constraints) {
    return GestureDetector(
      key: const ValueKey('exam-floating-add'),
      behavior: HitTestBehavior.opaque,
      onTap: _onFab,
      onPanUpdate: (details) {
        final currentLeft = _fabLeft ?? _maxFabLeft(constraints);
        setState(() {
          _fabLeft = (currentLeft + details.delta.dx)
              .clamp(_fabMargin, _maxFabLeft(constraints))
              .toDouble();
          _fabBottom = (_fabBottom - details.delta.dy)
              .clamp(_fabMargin, _maxFabBottom(constraints))
              .toDouble();
        });
      },
      onPanEnd: (_) {
        final currentLeft = _fabLeft ?? _maxFabLeft(constraints);
        final center = currentLeft + _fabSize / 2;
        final snapLeft = center < constraints.maxWidth / 2
            ? _fabMargin
            : _maxFabLeft(constraints);
        setState(() => _fabLeft = snapLeft);
      },
      child: Material(
        color: AppColors.interactive,
        elevation: 7,
        shadowColor: AppColors.brand.withValues(alpha: .28),
        shape: const CircleBorder(),
        child: const SizedBox(
          width: _fabSize,
          height: _fabSize,
          child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  void _onFab() {
    if (_tab.index == 0) {
      _openQuestionForm();
    } else {
      _openPaperCreate();
    }
  }

  // ==================== 题库 Tab ====================

  Widget _buildQuestionTab() {
    return Column(
      children: [
        // 搜索框 + 筛选图标（参考人才库：搜索框右侧漏斗筛选入口）
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _keywordCtrl,
                    onSubmitted: (_) => _loadQuestions(),
                    decoration: InputDecoration(
                      hintText: '搜索题干关键词',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 20, color: AppColors.textMuted),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded,
                            size: 18, color: AppColors.interactive),
                        onPressed: _loadQuestions,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey('exam-filter-open'),
                tooltip: _filterCount == 0 ? '筛选' : '筛选($_filterCount)',
                onPressed: _openFilter,
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(48),
                  padding: const EdgeInsets.all(10),
                ),
                icon: Badge(
                  key: const ValueKey('exam-filter-count'),
                  isLabelVisible: _filterCount > 0,
                  label: Text('$_filterCount'),
                  backgroundColor: AppColors.interactive,
                  child: TalentFilterIcon(
                    color: _filterCount > 0
                        ? AppColors.interactive
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 列表
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: OutlinedButton.icon(
              key: const ValueKey('exam-batch-analysis'),
              onPressed: _batchAnalyzing ? null : _batchFillAnalysis,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text(_batchAnalyzing ? '解析中…' : '批量补全解析'),
            ),
          ),
        ),
        Expanded(child: _buildQuestionList()),
      ],
    );
  }

  Widget _buildQuestionList() {
    if (_loadingQ) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.interactive));
    }
    if (_errorQ != null) {
      return _errorView(_errorQ!, _loadQuestions);
    }
    if (_questions.isEmpty) {
      return _emptyView('暂无题目，点击右下角新增');
    }
    return RefreshIndicator(
      color: AppColors.interactive,
      onRefresh: _loadQuestions,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _questions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _questionCard(_questions[index]),
      ),
    );
  }

  Widget _questionCard(Map<String, dynamic> q) {
    final type = _asInt(q['type']);
    final color = _typeColor(type);
    final isEnterprise = q['companyId'] != null;
    final questionId = _asInt(q['questionId']);
    final skillTag = q['skillTag']?.toString();

    return InkWell(
      key: ValueKey('exam-question-card-$questionId'),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ExamQuestionDetailPage(question: q),
        ),
      ),
      borderRadius: BorderRadius.circular(14),
      child: _card(
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 题型圆形图标
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_typeIcon(type), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _typeBadge(type, color),
                    const Spacer(),
                    _scopeBadge(isEnterprise),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  q['content']?.toString() ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.body,
                      height: 1.4),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: [
                    _metaTag(_difficultyName(q['difficulty']), AppColors.warning),
                    _metaTag('${_scoreText(q['score'])}分', AppColors.interactive),
                    if (skillTag != null && skillTag.isNotEmpty)
                      _skillTag(skillTag, color),
                  ],
                ),
                if (isEnterprise) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _textAction('编辑', () => _openQuestionForm(question: q)),
                      const SizedBox(width: 16),
                      _textAction('删除', () => _deleteQuestion(questionId)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ==================== 试卷 Tab ====================

  Widget _buildPaperTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _paperKeywordCtrl,
                    onChanged: (value) => setState(() => _paperKeyword = value),
                    decoration: InputDecoration(
                      hintText: '搜索试卷名称或岗位',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 20, color: AppColors.textMuted),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded,
                            size: 18, color: AppColors.interactive),
                        onPressed: () => setState(() {}),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                key: const ValueKey('exam-position-filter-open'),
                onTap: _pickPosition,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: _positionId == null
                        ? AppColors.canvas
                        : AppColors.interactiveSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _positionId == null
                          ? AppColors.primarySoft
                          : AppColors.interactive.withValues(alpha: .35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.work_outline_rounded,
                          size: 18,
                          color: _positionId == null
                              ? AppColors.textPrimary
                              : AppColors.interactive),
                      const SizedBox(width: 5),
                      Text(
                        _positionLabel(),
                        style: TextStyle(
                          fontSize: 12,
                          color: _positionId == null
                              ? AppColors.bodySoft
                              : AppColors.interactive,
                          fontWeight: _positionId == null
                              ? FontWeight.w500
                              : FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 17, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildPaperList()),
      ],
    );
  }

  Widget _buildPaperList() {
    if (_loadingP) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.interactive));
    }
    if (_errorP != null) {
      return _errorView(_errorP!, _loadPapers);
    }
    final keyword = _paperKeyword.trim().toLowerCase();
    final papers = keyword.isEmpty
        ? _papers
        : _papers.where((paper) {
            final name = '${paper['name'] ?? ''}'.toLowerCase();
            final position = '${paper['positionTitle'] ?? ''}'.toLowerCase();
            return name.contains(keyword) || position.contains(keyword);
          }).toList();
    if (papers.isEmpty) {
      return _emptyView('暂无试卷，点击右下角新建');
    }
    return RefreshIndicator(
      color: AppColors.interactive,
      onRefresh: _loadPapers,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: papers.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _paperCard(papers[index]),
      ),
    );
  }

  Widget _paperCard(Map<String, dynamic> p) {
    final paperId = _asInt(p['paperId']);
    final enabled = _asInt(p['status']) == 1;
    final isRandom = (p['ruleJson']?.toString().isNotEmpty ?? false);
    final modeColor = isRandom ? AppColors.orange : AppColors.interactive;

    return InkWell(
      key: ValueKey('exam-paper-card-$paperId'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openPaperPage(p),
      child: _card(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p['name']?.toString() ?? '未命名试卷',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.body),
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(enabled),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.work_outline_rounded,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  p['positionTitle']?.toString() ?? '未关联岗位',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: modeColor.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isRandom ? '随机抽题' : '人工组卷',
              style: TextStyle(
                  fontSize: 11, color: modeColor, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _paperStat('题量', '${_asInt(p['questionCount'])}'),
              _paperStat('总分', _scoreText(p['totalScore'])),
              _paperStat('时长', '${_asInt(p['durationMin'])}分钟'),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${p['createdAt'] ?? ''} 创建',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const Spacer(),
              _iconAction(Icons.delete_outline_rounded,
                  () => _deletePaper(paperId)),
            ],
          ),
        ],
        ),
      ),
    );
  }

  Widget _paperStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.body)),
        ],
      ),
    );
  }

  // ==================== 操作 ====================

  Future<void> _openQuestionForm({Map<String, dynamic>? question}) async {
    final saved = await showExamQuestionForm(context, question: question);
    if (saved == true) _loadQuestions();
  }

  Future<void> _openPaperCreate() async {
    if (_jobs.isEmpty) {
      await _loadJobs();
    }
    if (!mounted) return;
    if (_jobs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先在岗位管理中创建岗位')));
      return;
    }
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => ExamPaperCreatePage(jobs: _jobs)),
    );
    if (created == true) _loadPapers();
  }

  Future<void> _deleteQuestion(int questionId) async {
    final ok = await _confirm('删除题目', '确定删除该企业题目吗？');
    if (ok != true) return;
    try {
      await deleteExamQuestion(questionId);
      _loadQuestions();
    } on ApiException catch (error) {
      _toast(error.message);
    }
  }

  Future<void> _deletePaper(int paperId) async {
    final ok = await _confirm('删除试卷', '确定删除该试卷吗？');
    if (ok != true) return;
    try {
      await deleteExamPaper(paperId);
      _loadPapers();
    } on ApiException catch (error) {
      _toast(error.message);
    }
  }

  Future<void> _openPaperPage(Map<String, dynamic> paper) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ExamPaperDetailPage(paper: paper),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _viewPaper(Map<String, dynamic> paper) async {
    final paperId = _asInt(paper['paperId']);
    if (paperId <= 0) {
      _toast('试卷信息不完整');
      return;
    }
    try {
      final detail = await getExamPaper(paperId);
      if (!mounted) return;
      final questions = (detail['questions'] as List?) ?? const [];
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.canvas,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              Text(detail['name']?.toString() ?? '试卷详情',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('共 ${questions.length} 题 · 总分 ${_scoreText(detail['totalScore'])}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted)),
              const Divider(height: 24),
              ...questions.asMap().entries.map((entry) {
                final q = Map<String, dynamic>.from(entry.value as Map);
                return _paperQuestionCard(q, entry.key);
              }),
            ],
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      _showPaperFallback(paper, error.message);
    }
  }

  Widget _paperQuestionCard(Map<String, dynamic> question, int index) {
    final type = _asInt(question['type']);
    final typeColor = _typeColor(type);
    final answer = '${question['answer'] ?? ''}'.trim();
    final options = _paperOptions(question);
    final answerLabels = answer
        .split(RegExp(r'[,，、\s]+'))
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toSet();
    final analysis = '${question['analysis'] ?? ''}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text('第 ${index + 1} 题', style: TextStyle(color: typeColor, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Text(_typeName(type), style: TextStyle(color: typeColor, fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${_scoreText(question['score'])} 分', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text('${question['content'] ?? ''}', style: const TextStyle(color: AppColors.body, fontSize: 15, height: 1.5, fontWeight: FontWeight.w600)),
          if (options.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final option in options)
              _paperOptionRow(option, answerLabels.contains(option.$1.toUpperCase())),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.green.withValues(alpha: .1), borderRadius: BorderRadius.circular(9)),
            child: Text('标准答案：${answer.isEmpty ? '暂无' : answer}', style: const TextStyle(color: AppColors.green, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          if (analysis.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(9)),
              child: Text('答案解析：$analysis', style: const TextStyle(color: AppColors.bodySoft, fontSize: 12, height: 1.5)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paperOptionRow((String, String) option, bool correct) => Container(
    margin: const EdgeInsets.only(bottom: 7),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: correct ? AppColors.green.withValues(alpha: .1) : AppColors.background,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: correct ? AppColors.green : AppColors.hairline),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${option.$1}.', style: TextStyle(color: correct ? AppColors.green : AppColors.body, fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Expanded(child: Text(option.$2, style: TextStyle(color: correct ? AppColors.green : AppColors.body, fontSize: 13, height: 1.4))),
        if (correct) const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 17),
      ],
    ),
  );

  List<(String, String)> _paperOptions(Map<String, dynamic> question) {
    Object? raw = question['options'];
    if (raw is! List && question['optionsJson'] != null) {
      try {
        raw = jsonDecode('${question['optionsJson']}');
      } catch (_) {
        raw = null;
      }
    }
    if (raw is! List) return const [];
    final options = <(String, String)>[];
    for (var index = 0; index < raw.length; index++) {
      final item = raw[index];
      var label = '';
      var text = '';
      if (item is Map) {
        label = _normalizePaperOptionLabel(item['label']);
        text = '${item['text'] ?? item['value'] ?? ''}'.trim();
      } else {
        text = '$item'.trim();
      }

      final parsed = _parsePaperOptionPrefix(text);
      if (label.isEmpty && parsed != null) {
        label = parsed.$1;
        text = parsed.$2;
      }
      if (text.isEmpty && label.isEmpty) continue;
      options.add((
        label.isEmpty ? String.fromCharCode(65 + index) : label,
        _stripPaperOptionBullet(text),
      ));
    }
    return options;
  }

  String _normalizePaperOptionLabel(Object? value) {
    final label = '${value ?? ''}'.trim().toUpperCase();
    return RegExp(r'^[A-Z]$').hasMatch(label) ? label : '';
  }

  (String, String)? _parsePaperOptionPrefix(String value) {
    final match = RegExp(r'^\s*([A-Za-z])\s*[\.、)、:：]\s*(.+)$')
        .firstMatch(value);
    if (match == null) return null;
    return (match.group(1)!.toUpperCase(), match.group(2)!.trim());
  }

  String _stripPaperOptionBullet(String value) =>
      value.replaceFirst(RegExp(r'^\s*[•·●▪◦‣]\s*'), '').trim();

  void _showPaperFallback(Map<String, dynamic> paper, String message) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paper['name']?.toString() ?? '试卷详情',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '${paper['positionTitle'] ?? '未关联岗位'} · 题量 ${_asInt(paper['questionCount'])} · 总分 ${_scoreText(paper['totalScore'])} · ${_asInt(paper['durationMin'])}分钟',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('题目清单暂时加载失败：$message\n可稍后点击查看重试。', style: const TextStyle(color: AppColors.warning)),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // ==================== 题库筛选（参考人才库弹窗） ====================

  /// 当前已选中的筛选条件数量（用于筛选图标角标）。
  int get _filterCount =>
      (_scope == null ? 0 : 1) +
      (_type == null ? 0 : 1) +
      (_difficulty == null ? 0 : 1);

  /// 打开题库筛选弹窗（题库归属 / 题型 / 难度），确定后刷新列表。
  Future<void> _openFilter() async {
    FocusScope.of(context).unfocus();
    final result = await showModalBottomSheet<ExamFilterResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(),
      builder: (_) => FractionallySizedBox(
        heightFactor: 1,
        child: ExamFilterSheet(
          scope: _scope,
          type: _type,
          difficulty: _difficulty,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _scope = result.scope;
      _type = result.type;
      _difficulty = result.difficulty;
    });
    _loadQuestions();
  }

  void _pickPosition() {
    final options = <List<Object?>>[
      [null, '全部岗位'],
      ..._jobs.map((j) => [_asInt(j['posId']), j['title']?.toString() ?? '岗位']),
    ];
    _pick(
      title: '选择岗位',
      options: options,
      onSelected: (v) => setState(() => _positionId = v as int?),
    );
  }

  void _pick({
    required String title,
    required List<List<Object?>> options,
    required ValueChanged<Object?> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            const Divider(height: 1),
            ...options.map((opt) => ListTile(
                  title: Text(opt[1]?.toString() ?? ''),
                  onTap: () {
                    onSelected(opt[0]);
                    Navigator.pop(context);
                    _refresh();
                  },
                )),
          ],
        ),
      ),
    );
  }

  // ==================== 通用组件 ====================

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: AppColors.brand.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }

  Widget _typeBadge(int? type, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(_typeName(type),
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _scopeBadge(bool isEnterprise) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isEnterprise ? AppColors.interactive : AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isEnterprise ? '企业题库' : '平台题库',
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isEnterprise ? Colors.white : AppColors.textMuted),
      ),
    );
  }

  Widget _statusBadge(bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.green.withValues(alpha: 0.12)
            : AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        enabled ? '启用' : '停用',
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: enabled ? AppColors.green : AppColors.textMuted),
      ),
    );
  }

  Widget _skillTag(String tag, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(tag,
          style: TextStyle(fontSize: 11, color: color)),
    );
  }

  Widget _metaTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _textAction(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Text(label,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
    );
  }

  Widget _iconAction(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Icon(icon, size: 18, color: AppColors.textMuted),
    );
  }

  Widget _emptyView(String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 52, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _errorView(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirm(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确定')),
        ],
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ==================== 映射工具 ====================

  String _positionLabel() {
    if (_positionId == null) return '全部岗位';
    for (final j in _jobs) {
      if (_asInt(j['posId']) == _positionId) {
        return j['title']?.toString() ?? '岗位';
      }
    }
    return '全部岗位';
  }

  static int _asInt(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  static String _scoreText(Object? value) {
    final d = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return d == d.roundToDouble() ? '${d.toInt()}' : d.toString();
  }

  static String _typeName(Object? type) {
    switch (_asInt(type)) {
      case 1:
        return '单选题';
      case 2:
        return '多选题';
      case 3:
        return '判断题';
      case 4:
        return '简答题';
      case 5:
        return '编程题';
      default:
        return '自定义';
    }
  }

  static String _difficultyName(Object? difficulty) {
    switch (_asInt(difficulty)) {
      case 1:
        return '简单';
      case 3:
        return '困难';
      default:
        return '中等';
    }
  }

  static Color _typeColor(int? type) {
    switch (type) {
      case 1:
        return AppColors.interactive;
      case 2:
        return AppColors.teal;
      case 3:
        return AppColors.green;
      case 4:
        return AppColors.purple;
      case 5:
        return AppColors.orange;
      default:
        return AppColors.textMuted;
    }
  }

  static IconData _typeIcon(int? type) {
    switch (type) {
      case 1:
        return Icons.help_outline_rounded;
      case 2:
        return Icons.format_list_bulleted_rounded;
      case 3:
        return Icons.check_rounded;
      case 4:
        return Icons.description_outlined;
      case 5:
        return Icons.code_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}
