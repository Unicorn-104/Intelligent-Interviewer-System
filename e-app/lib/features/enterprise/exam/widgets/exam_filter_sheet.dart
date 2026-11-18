import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../theme/app_theme.dart';

/// 题库筛选结果：题库归属 + 题型 + 难度。
class ExamFilterResult {
  const ExamFilterResult({this.scope, this.type, this.difficulty});

  /// null=全部 platform=平台 enterprise=企业。
  final String? scope;

  /// 题型：null=全部 1单选 2多选 3判断 4简答 5编程。
  final int? type;

  /// 难度：null=全部 1简单 2中等 3困难。
  final int? difficulty;

  /// 已选中的筛选条件数量（用于筛选图标角标）。
  int get count =>
      (scope == null ? 0 : 1) +
      (type == null ? 0 : 1) +
      (difficulty == null ? 0 : 1);
}

/// 题库筛选弹窗：参考人才库筛选（TalentFilterSheet），
/// 左侧分类导航 + 右侧选项标签云，底部「清除 / 确定」。
/// 选项与原下拉选择器完全一致，仅改为弹窗交互。
class ExamFilterSheet extends StatefulWidget {
  const ExamFilterSheet({super.key, this.scope, this.type, this.difficulty});

  final String? scope;
  final int? type;
  final int? difficulty;

  @override
  State<ExamFilterSheet> createState() => _ExamFilterSheetState();
}

class _ExamFilterSheetState extends State<ExamFilterSheet> {
  late String? _scope = widget.scope;
  late int? _type = widget.type;
  late int? _difficulty = widget.difficulty;
  int _category = 0;
  final _scroll = ScrollController();
  final _sectionKeys = List.generate(3, (_) => GlobalKey());
  bool _jumping = false;

  static const _sections = ['题库', '题型', '难度'];

  // 选项与原 exam_management_page 下拉选择器保持一致。
  static const _scopeOptions = <List<Object?>>[
    [null, '全部题库'],
    ['platform', '平台题库'],
    ['enterprise', '企业题库'],
  ];
  static const _typeOptions = <List<Object?>>[
    [null, '全部题型'],
    [1, '单选题'],
    [2, '多选题'],
    [3, '判断题'],
    [4, '简答题'],
    [5, '编程题'],
  ];
  static const _difficultyOptions = <List<Object?>>[
    [null, '全部难度'],
    [1, '简单'],
    [2, '中等'],
    [3, '困难'],
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_syncCategory);
  }

  @override
  void dispose() {
    _scroll.removeListener(_syncCategory);
    _scroll.dispose();
    super.dispose();
  }

  /// 左侧分类点选：滚动到对应 section（与人才库一致）。
  Future<void> _jumpToSection(int index) async {
    final target = _sectionKeys[index].currentContext;
    if (target == null || !_scroll.hasClients) return;
    setState(() => _category = index);
    _jumping = true;
    try {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        alignment: 0,
      );
    } finally {
      _jumping = false;
    }
  }

  /// 滚动时同步左侧分类高亮（与人才库一致）。
  void _syncCategory() {
    if (!mounted || _jumping || !_scroll.hasClients) return;
    var current = 0;
    for (var index = 0; index < _sectionKeys.length; index++) {
      final render = _sectionKeys[index].currentContext?.findRenderObject();
      if (render == null || !render.attached) continue;
      final viewport = RenderAbstractViewport.maybeOf(render);
      if (viewport == null) continue;
      final offset = viewport.getOffsetToReveal(render, 0).offset;
      if (offset <= _scroll.offset + 20) current = index;
    }
    if (_scroll.position.maxScrollExtent > 0 &&
        _scroll.offset >= _scroll.position.maxScrollExtent - 1) {
      current = _sectionKeys.length - 1;
    }
    if (_category != current) setState(() => _category = current);
  }

  void _clear() => setState(() {
        _scope = null;
        _type = null;
        _difficulty = null;
      });

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('exam-filter-close'),
                    tooltip: '取消筛选',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  const Expanded(
                    child: Text(
                      '筛选题目',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 左侧分类导航
                  SizedBox(
                    width: 88,
                    child: ColoredBox(
                      color: AppColors.background,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (index, title) in _sections.indexed)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: _category == index
                                    ? AppColors.canvas
                                    : null,
                                border: Border(
                                  left: BorderSide(
                                    width: 3,
                                    color: _category == index
                                        ? AppColors.interactive
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                              child: TextButton(
                                key: ValueKey('exam-filter-category-$index'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 18,
                                  ),
                                  foregroundColor: _category == index
                                      ? AppColors.interactive
                                      : AppColors.textSecondary,
                                  shape: const RoundedRectangleBorder(),
                                ),
                                onPressed: () => _jumpToSection(index),
                                child: Semantics(
                                  selected: _category == index,
                                  child: Text(title, textAlign: TextAlign.center),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // 右侧选项区（三个 section 同滚动列表）
                  Expanded(
                    child: SingleChildScrollView(
                      key: const Key('exam-filter-scroll'),
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _section(0, [
                            _optionGrid([
                              for (final opt in _scopeOptions)
                                _option(
                                  opt[1] as String,
                                  _scope == opt[0],
                                  () => setState(
                                      () => _scope = opt[0] as String?),
                                  'scope-${opt[0]}',
                                ),
                            ]),
                          ]),
                          _section(1, [
                            _optionGrid([
                              for (final opt in _typeOptions)
                                _option(
                                  opt[1] as String,
                                  _type == opt[0],
                                  () =>
                                      setState(() => _type = opt[0] as int?),
                                  'type-${opt[0]}',
                                ),
                            ]),
                          ]),
                          _section(2, [
                            _optionGrid([
                              for (final opt in _difficultyOptions)
                                _option(
                                  opt[1] as String,
                                  _difficulty == opt[0],
                                  () => setState(
                                      () => _difficulty = opt[0] as int?),
                                  'difficulty-${opt[0]}',
                                ),
                            ]),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 底部清除 / 确定
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('exam-filter-clear'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.background,
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _clear,
                      child: const Text('清除'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: const Key('exam-filter-apply'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(
                        context,
                        ExamFilterResult(
                          scope: _scope,
                          type: _type,
                          difficulty: _difficulty,
                        ),
                      ),
                      child: const Text('确定'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _section(int index, List<Widget> children) => Padding(
        key: _sectionKeys[index],
        padding: const EdgeInsets.only(bottom: 36),
        child: Column(
          key: ValueKey('exam-filter-section-$index'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
              TextSpan(
                text: _sections[index],
                children: const [
                  TextSpan(
                    text: '（单选）',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );

  Widget _optionGrid(List<Widget> children) => LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
          final columns = constraints.maxWidth < 180 ||
                  (largeText && constraints.maxWidth < 300)
              ? 1
              : 2;
          final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
          return Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              for (final child in children) SizedBox(width: width, child: child),
            ],
          );
        },
      );

  Widget _option(
    String title,
    bool selected,
    VoidCallback onTap,
    String name,
  ) =>
      OutlinedButton(
        key: ValueKey('exam-filter-$name'),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          foregroundColor:
              selected ? AppColors.interactive : AppColors.textSecondary,
          backgroundColor: selected ? AppColors.canvas : AppColors.background,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: BorderSide(
            color: selected ? AppColors.interactive : Colors.transparent,
          ),
        ),
        child: Semantics(
          selected: selected,
          child: Text(title, textAlign: TextAlign.center),
        ),
      );
}
