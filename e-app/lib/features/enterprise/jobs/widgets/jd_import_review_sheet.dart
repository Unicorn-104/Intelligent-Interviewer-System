import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../models/jd_import_draft.dart';

class JdImportReviewSheet extends StatefulWidget {
  const JdImportReviewSheet({
    super.key,
    required this.draft,
    required this.readCurrent,
    required this.onApply,
    this.filename,
  });

  final JdImportDraft draft;
  final Map<String, Object?> Function() readCurrent;
  final ValueChanged<JdImportPatch> onApply;
  final String? filename;

  @override
  State<JdImportReviewSheet> createState() => _JdImportReviewSheetState();
}

class _JdImportReviewSheetState extends State<JdImportReviewSheet> {
  bool _appendSummary = false;
  bool _appendSoftRequirements = false;
  bool _applying = false;
  String? _error;

  static const _educationLabels = {
    0: '学历不限',
    1: '中专',
    2: '大专',
    3: '本科',
    4: '硕士',
    5: '博士',
  };
  static const _jobTypeLabels = {1: '全职', 2: '兼职', 3: '实习'};

  Future<void> _apply() async {
    if (_applying) return;
    setState(() {
      _applying = true;
      _error = null;
    });
    try {
      final current = widget.readCurrent();
      final patch = widget.draft.prepareImport(
        current,
        appendSummary: _appendSummary,
        appendSoftRequirements: _appendSoftRequirements,
      );
      if (patch.needsOverwriteConfirmation) {
        final overwrite = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认覆盖已有内容？'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('以下字段与当前输入不同。确认后将替换这些字段；其他已有内容保持不变。'),
                    const SizedBox(height: 16),
                    for (final field in patch.overwrittenFields)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              JdImportPatch.fieldLabels[field]!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '当前：${_display(field, current)}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '导入后：${_display(field, patch.values)}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                key: const Key('jd-import-keep-current'),
                onPressed: () => Navigator.pop(context, false),
                child: const Text('保留原内容'),
              ),
              FilledButton(
                key: const Key('jd-import-confirm-overwrite'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认覆盖'),
              ),
            ],
          ),
        );
        if (overwrite != true || !mounted) return;
      }
      if (!mounted) return;
      widget.onApply(patch);
      if (mounted) Navigator.pop(context, true);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  String _display(String field, Map<String, Object?> form) {
    if (field == 'salary') {
      if (form['negotiable'] == true) return '薪资面议';
      final min = form['salaryMin'];
      final max = form['salaryMax'];
      return '${min == null || '$min'.isEmpty ? '未填写' : min} – ${max == null || '$max'.isEmpty ? '未填写' : max} 元/月';
    }
    final value = form[field];
    if (value == null) return '未填写';
    if (field == 'education') return _educationLabels[value] ?? '$value';
    if (field == 'jobType') return _jobTypeLabels[value] ?? '$value';
    if (value is List) {
      if (value.isEmpty) return '未填写';
      return value
          .map((item) {
            if (field == 'skills' && item is Map) {
              final label = switch (item['required']) {
                1 => '必备',
                0 => '加分',
                _ => '未注明',
              };
              return '${item['name']} · $label';
            }
            return '$item';
          })
          .join('\n');
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final missing = <String>[
      if (draft.title == null) '岗位名称',
      if (draft.dept == null) '所属部门',
      if (draft.city == null) '工作城市',
      if (draft.salaryMin == null) '最低月薪',
      if (draft.salaryMax == null) '最高月薪',
      if (draft.experience == null) '经验要求',
      if (draft.education == null) '学历要求',
      if (draft.jobType == null) '工作性质',
      if (draft.responsibilities.isEmpty) '工作职责',
      if (draft.requirements.isEmpty) '任职要求',
      if (draft.skills.isEmpty) '技能标签',
      if (draft.summary == null) '摘要',
      if (draft.softRequirements.isEmpty) '软性要求',
    ];
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    color: AppColors.accentPurple,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '解析完成，请核对',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('jd-import-review-close'),
                    tooltip: '关闭核对面板',
                    onPressed: _applying ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('jd-import-review-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'AI 结果仅供参考',
                      style: TextStyle(color: AppColors.accentPurple),
                    ),
                    if (widget.filename != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.filename!,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                    if (missing.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        key: const Key('jd-import-missing-fields'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warningSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '未识别：${missing.join('、')}。缺失字段不会清空已有输入，请补充或核对。',
                        ),
                      ),
                    ],
                    if (draft.hasPartialSalary) ...[
                      const SizedBox(height: 12),
                      const Text(
                        '仅识别到一端月薪。应用后请补齐另一端，不会沿用原薪资的另一端。',
                        style: TextStyle(color: AppColors.warning),
                      ),
                    ],
                    _group('基本信息', [
                      _value('岗位名称', draft.title),
                      _value('所属部门', draft.dept),
                      _value('工作城市', draft.city),
                      _value(
                        '月薪（元/月）',
                        draft.hasSalary
                            ? '${draft.salaryMin ?? '未识别'} – ${draft.salaryMax ?? '未识别'}'
                            : null,
                      ),
                      _value('经验要求', draft.experience),
                      _value('学历要求', _educationLabels[draft.education]),
                      _value('工作性质', _jobTypeLabels[draft.jobType]),
                    ]),
                    _group('工作职责', _lineWidgets(draft.responsibilities)),
                    _group('任职要求', _lineWidgets(draft.requirements)),
                    _group('技能标签', [
                      if (draft.skills.isEmpty)
                        const Text('文档未提及')
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: draft.skills
                              .map(
                                (skill) => Chip(
                                  label: Text(
                                    '${skill.name} · ${skill.requirementLabel}',
                                  ),
                                  backgroundColor: AppColors.interactiveSoft,
                                  side: BorderSide.none,
                                ),
                              )
                              .toList(),
                        ),
                    ]),
                    _group('摘要与软性要求', [
                      const Text(
                        '摘要和软性要求会追加到正文，不会单独保存。只有主动选择后，才会随本次草稿应用。',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      _value('摘要', draft.summary),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          key: const Key('jd-import-append-summary'),
                          onPressed: draft.summary == null || _applying
                              ? null
                              : () => setState(
                                  () => _appendSummary = !_appendSummary,
                                ),
                          icon: Icon(
                            _appendSummary ? Icons.check : Icons.add,
                            size: 18,
                          ),
                          label: Text(
                            _appendSummary ? '已选择加入工作职责，点击取消' : '加入工作职责',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._lineWidgets(draft.softRequirements),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          key: const Key('jd-import-append-soft-requirements'),
                          onPressed: draft.softRequirements.isEmpty || _applying
                              ? null
                              : () => setState(
                                  () => _appendSoftRequirements =
                                      !_appendSoftRequirements,
                                ),
                          icon: Icon(
                            _appendSoftRequirements ? Icons.check : Icons.add,
                            size: 18,
                          ),
                          label: Text(
                            _appendSoftRequirements
                                ? '已选择加入任职要求，点击取消'
                                : '加入任职要求',
                          ),
                        ),
                      ),
                    ]),
                    _group('文档解析提示', [
                      if (draft.warnings.isEmpty)
                        const Text('无额外警告')
                      else
                        for (
                          var index = 0;
                          index < draft.warnings.length;
                          index++
                        )
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SelectableText(
                              draft.warnings[index],
                              key: ValueKey('jd-import-warning-$index'),
                            ),
                          ),
                    ]),
                    if (_error != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: FilledButton(
                key: const Key('jd-import-apply'),
                onPressed: _applying ? null : _apply,
                child: Text(_applying ? '正在确认…' : '应用草稿'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _group(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );

  Widget _value(String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(value ?? '文档未提及'),
      ],
    ),
  );

  List<Widget> _lineWidgets(List<String> lines) => lines.isEmpty
      ? [const Text('文档未提及', style: TextStyle(color: AppColors.textMuted))]
      : lines
            .map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(line),
              ),
            )
            .toList();
}
