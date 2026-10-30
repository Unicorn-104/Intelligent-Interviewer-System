import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../models/job_detail_view_data.dart';
import 'job_publish_workflow.dart';

Future<void> showJobWorkflowEditor({
  required BuildContext context,
  required Map<String, dynamic> data,
  required Future<bool> Function(Map<String, Object?>) onSave,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: false,
  enableDrag: false,
  builder: (_) =>
      _WorkflowEditor(initial: jobWorkflowSaveBody(data), onSave: onSave),
);

/// 节点直接编辑单个阶段；仍使用已有完整流程保存接口。
Future<void> showJobWorkflowStageEditor({
  required BuildContext context,
  required Map<String, dynamic> data,
  required int? index,
  required Future<bool> Function(Map<String, Object?>) onSave,
}) async {
  final payload = jobWorkflowSaveBody(data);
  final stages = (payload['stages'] as List)
      .map((row) => Map<String, Object?>.from(row as Map))
      .toList();
  final source = index == null ? null : stages[index];
  final draft = JobPublishStageDraft(index ?? stages.length);
  if (source != null) {
    draft
      ..name.text = source['name']?.toString() ?? ''
      ..type = int.tryParse('${source['type']}') ?? 3
      ..duration.text = (int.tryParse('${source['duration']}') ?? 45).toString()
      ..threshold.text = (int.tryParse('${source['threshold']}') ?? 70)
          .toString()
      ..target.text = source['target']?.toString() ?? ''
      ..required = source['required'] == true
      ..skip = source['skip'] == true || '${source['skip']}' == '1'
      ..terminate =
          source['terminate'] == true || '${source['terminate']}' == '1';
  }
  final baseline = draft.toJson();
  final route = DialogRoute<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => JobPublishStageDialog(
      stage: draft,
      isNew: source == null,
      onSave: () {
        final current = draft.toJson();
        final changed = source == null
            ? current
            : <String, Object?>{
                ...source,
                for (final entry in current.entries)
                  if (entry.value != baseline[entry.key])
                    entry.key: entry.value,
              };
        final updated = [...stages];
        if (index == null) {
          updated.add(changed);
        } else {
          updated[index] = changed;
        }
        return onSave({...payload, 'stages': updated});
      },
      onDelete: index == null
          ? null
          : () {
              if (stages.length <= 1) {
                throw const FormatException('至少保留一个阶段，请先添加新的阶段');
              }
              final updated = [...stages]..removeAt(index);
              return onSave({...payload, 'stages': updated});
            },
    ),
  );
  try {
    await Navigator.of(context).push(route);
    await route.completed;
  } finally {
    draft.dispose();
  }
}

class _WorkflowEditor extends StatefulWidget {
  const _WorkflowEditor({required this.initial, required this.onSave});
  final Map<String, Object?> initial;
  final Future<bool> Function(Map<String, Object?>) onSave;
  @override
  State<_WorkflowEditor> createState() => _WorkflowEditorState();
}

class _WorkflowEditorState extends State<_WorkflowEditor> {
  late final String _templateName;
  final _stages = <JobPublishStageDraft>[];
  final _allStages = <JobPublishStageDraft>[];
  final _original = <int, Map<String, Object?>>{};
  final _baseline = <int, Map<String, Object?>>{};
  int _nextId = 0;
  bool _saving = false, _editing = false;
  String? _error;

  bool _flag(Object? value, {bool fallback = false}) => value == null
      ? fallback
      : value == true || '$value' == '1' || '$value' == 'true';

  @override
  void initState() {
    super.initState();
    _templateName = widget.initial['templateName']?.toString() ?? '岗位招聘流程';
    for (final raw in widget.initial['stages'] as List) {
      final data = Map<String, Object?>.from(raw as Map);
      final stage = JobPublishStageDraft(_nextId++)
        ..name.text = data['name']?.toString() ?? ''
        ..type = int.tryParse('${data['type']}') ?? 3
        ..duration.text = (int.tryParse('${data['duration']}') ?? 45).toString()
        ..threshold.text = (int.tryParse('${data['threshold']}') ?? 70)
            .toString()
        ..target.text = data['target']?.toString() ?? ''
        ..required = _flag(data['required'])
        ..skip = _flag(data['skip'])
        ..terminate = _flag(data['terminate']);
      _stages.add(stage);
      _allStages.add(stage);
      // Keep unexposed fields and omitted values unchanged unless edited.
      _original[stage.id] = data;
      _baseline[stage.id] = stage.toJson();
    }
  }

  @override
  void dispose() {
    for (final stage in _allStages) {
      stage.dispose();
    }
    super.dispose();
  }

  Future<void> _editStage([JobPublishStageDraft? existing]) async {
    if (_saving || _editing) return;
    final draft = existing == null
        ? JobPublishStageDraft(_nextId++)
        : JobPublishStageDraft.copy(existing);
    _allStages.add(draft);
    setState(() => _editing = true);
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) => JobPublishStageDialog(
          stage: draft,
          isNew: existing == null,
          onDelete: existing == null
              ? null
              : () async {
                  setState(() {
                    _stages.remove(existing);
                    _error = null;
                  });
                  return true;
                },
        ),
      );
      if (!mounted || saved != true) return;
      setState(() {
        if (existing == null) {
          _stages.add(draft);
        } else {
          _stages[_stages.indexOf(existing)] = draft;
        }
        _error = null;
      });
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  Map<String, Object?> _stagePayload(JobPublishStageDraft stage) {
    final original = _original[stage.id];
    final current = stage.toJson();
    if (original == null) return current;
    final baseline = _baseline[stage.id]!;
    return {
      ...original,
      for (final entry in current.entries)
        if (entry.value != baseline[entry.key]) entry.key: entry.value,
    };
  }

  Future<void> _save() async {
    if (_saving || _editing) return;
    if (_stages.isEmpty) {
      setState(() => _error = '至少添加一个阶段');
      return;
    }
    for (final stage in _stages) {
      final duration = int.tryParse(stage.duration.text);
      final threshold = int.tryParse(stage.threshold.text);
      if (stage.name.text.trim().isEmpty ||
          duration == null ||
          duration < 1 ||
          duration > 1440 ||
          threshold == null ||
          threshold < 0 ||
          threshold > 100) {
        setState(() => _error = '请编辑并完善「${stage.name.text.trim()}」的阶段设置');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, Object?>{
      'templateName': _templateName,
      'stages': _stages.map(_stagePayload).toList(),
    };
    final saved = await widget.onSave(body);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!saved) _error = '流程保存失败，请核对后重试';
    });
    if (saved) Navigator.pop(context);
  }

  void _move(int index, int delta) => setState(() {
    final stage = _stages.removeAt(index);
    _stages.insert(index + delta, stage);
  });

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '编辑招聘流程',
                      style: TextStyle(
                        color: AppColors.brand,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('job-workflow-close'),
                    tooltip: '关闭',
                    onPressed: _saving || _editing
                        ? null
                        : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('job-workflow-add-stage'),
                      onPressed: _saving || _editing
                          ? null
                          : () => _editStage(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        foregroundColor: AppColors.interactive,
                        backgroundColor: AppColors.canvas,
                        side: const BorderSide(color: AppColors.hairline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('新增招聘流程'),
                    ),
                    for (final (index, stage) in _stages.indexed) ...[
                      const SizedBox(height: 12),
                      JobPublishStageCard(
                        key: ValueKey('job-workflow-stage-${stage.id}'),
                        stage: stage,
                        index: index,
                        enabled: !_saving && !_editing,
                        onEdit: () => _editStage(stage),
                        onRemove: () => setState(() {
                          _stages.remove(stage);
                          _error = null;
                        }),
                        bottomActions: _stages.length > 1
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    key: ValueKey(
                                      'job-workflow-up-${stage.id}',
                                    ),
                                    tooltip: '上移阶段',
                                    onPressed: _saving || _editing || index == 0
                                        ? null
                                        : () => _move(index, -1),
                                    icon: const Icon(
                                      Icons.arrow_upward,
                                      size: 18,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  IconButton(
                                    key: ValueKey(
                                      'job-workflow-down-${stage.id}',
                                    ),
                                    tooltip: '下移阶段',
                                    onPressed:
                                        _saving ||
                                            _editing ||
                                            index == _stages.length - 1
                                        ? null
                                        : () => _move(index, 1),
                                    icon: const Icon(
                                      Icons.arrow_downward,
                                      size: 18,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _saving || _editing
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('job-workflow-save'),
                      onPressed: _saving || _editing ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Text(_saving ? '保存中…' : '保存流程'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
