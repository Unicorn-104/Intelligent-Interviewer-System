import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/page_states.dart';
import '../../../../widgets/skeleton_list.dart';
import '../models/job_detail_view_data.dart';

class JobWorkflowSection extends StatefulWidget {
  const JobWorkflowSection({
    super.key,
    required this.positionId,
    required this.state,
    required this.expanded,
    required this.onExpanded,
    required this.saving,
    required this.onReload,
    required this.onSave,
  });
  final int positionId;
  final JobSectionState<Map<String, dynamic>> state;
  final bool expanded;
  final ValueChanged<bool> onExpanded;
  final bool saving;
  final VoidCallback onReload;
  final Future<bool> Function(Map<String, Object?>) onSave;

  @override
  State<JobWorkflowSection> createState() => _JobWorkflowSectionState();
}

class _JobWorkflowSectionState extends State<JobWorkflowSection> {
  bool _editing = false;

  Future<void> _edit() async {
    if (_editing || widget.saving || widget.state.data == null) {
      return;
    }
    setState(() => _editing = true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => _WorkflowEditor(
          initial: jobWorkflowSaveBody(widget.state.data!),
          onSave: widget.onSave,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _editing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.state.data?['stages'];
    final stages = raw is List ? raw.whereType<Map>().toList() : const <Map>[];
    final subtitle = widget.state.loading
        ? '加载中'
        : widget.state.error != null
        ? '加载失败，展开重试'
        : stages.isEmpty
        ? '未配置，点击展开'
        : '已配置${stages.length}个阶段，点击展开';
    return ExpansionTile(
      key: PageStorageKey('job-workflow-expansion-${widget.positionId}'),
      title: const Text('招聘流程'),
      subtitle: Text(subtitle),
      initiallyExpanded: widget.expanded,
      onExpansionChanged: widget.onExpanded,
      maintainState: true,
      leading: const Icon(Icons.route_outlined, color: AppColors.interactive),
      backgroundColor: AppColors.canvas,
      collapsedBackgroundColor: AppColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.hairline),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.hairline),
      ),
      children: [
        Padding(padding: const EdgeInsets.all(16), child: _body(stages)),
      ],
    );
  }

  Widget _body(List<Map> stages) {
    if (widget.state.loading) {
      return const SkeletonList(rows: 1);
    }
    if (widget.state.error != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '招聘流程加载失败',
        message: widget.state.error!,
        onAction: widget.onReload,
      );
    }
    if (widget.state.data == null) {
      return PageMessage(
        icon: Icons.route_outlined,
        title: '暂无招聘流程数据',
        message: '请刷新后再配置',
        onAction: widget.onReload,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stages.isEmpty)
          const Text('尚未配置招聘流程')
        else
          for (var index = 0; index < stages.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('${index + 1}. ${jobValue(stages[index]['name'])}'),
            ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('job-workflow-edit'),
            onPressed: widget.saving || _editing ? null : _edit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(
              widget.saving
                  ? '保存中…'
                  : stages.isEmpty
                  ? '配置流程'
                  : '编辑流程',
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkflowStageDraft {
  _WorkflowStageDraft(this.id, this.data)
    : name = TextEditingController(text: data['name']?.toString() ?? ''),
      threshold = TextEditingController(
        text: data['threshold']?.toString() ?? '70',
      ),
      requiredStage = data['required'] == true;
  final int id;
  final Map<String, Object?> data;
  final TextEditingController name;
  final TextEditingController threshold;
  bool requiredStage;
  void dispose() {
    name.dispose();
    threshold.dispose();
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
  final _form = GlobalKey<FormState>();
  late final TextEditingController _templateName;
  final _stages = <_WorkflowStageDraft>[];
  final _allStages = <_WorkflowStageDraft>[];
  int _nextId = 0;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _templateName = TextEditingController(
      text: widget.initial['templateName']?.toString() ?? '岗位招聘流程',
    );
    for (final raw in widget.initial['stages'] as List) {
      final stage = _WorkflowStageDraft(
        _nextId++,
        Map<String, Object?>.from(raw as Map),
      );
      _stages.add(stage);
      _allStages.add(stage);
    }
  }

  @override
  void dispose() {
    _templateName.dispose();
    for (final stage in _allStages) {
      stage.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    if (_stages.isEmpty) {
      setState(() => _error = '至少添加一个阶段');
      return;
    }
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, Object?>{
      'templateName': _templateName.text.trim(),
      'stages': _stages
          .map(
            (stage) => <String, Object?>{
              ...stage.data,
              'name': stage.name.text.trim(),
              'required': stage.requiredStage,
              'threshold': int.parse(stage.threshold.text),
            },
          )
          .toList(),
    };
    final saved = await widget.onSave(body);
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      if (!saved) {
        _error = '流程保存失败，请核对后重试';
      }
    });
    if (saved) Navigator.pop(context);
  }

  void _move(int index, int delta) => setState(() {
    final stage = _stages.removeAt(index);
    _stages.insert(index + delta, stage);
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '编辑招聘流程',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('保留现有阶段类型及面试配置；可调整名称、顺序、必经标识和通过阈值。'),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('job-workflow-name'),
                      controller: _templateName,
                      enabled: !_saving,
                      maxLength: 100,
                      decoration: const InputDecoration(labelText: '流程名称'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '请填写流程名称'
                          : null,
                    ),
                    for (var index = 0; index < _stages.length; index++)
                      _stageEditor(index),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const Key('job-workflow-add-stage'),
                        onPressed: _saving
                            ? null
                            : () => setState(() {
                                final stage = _WorkflowStageDraft(_nextId++, {
                                  'name': '',
                                  'type': 3,
                                  'required': true,
                                  'threshold': 70,
                                });
                                _stages.add(stage);
                                _allStages.add(stage);
                              }),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('添加阶段'),
                      ),
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('job-workflow-save'),
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? '保存中…' : '保存流程'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _stageEditor(int index) {
    final stage = _stages[index];
    return Card(
      key: ValueKey('job-workflow-stage-${stage.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextFormField(
              controller: stage.name,
              enabled: !_saving,
              maxLength: 100,
              decoration: InputDecoration(labelText: '阶段${index + 1}名称'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请填写阶段名称' : null,
            ),
            TextFormField(
              controller: stage.threshold,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '通过阈值（0–100）'),
              validator: (value) {
                final threshold = int.tryParse(value ?? '');
                return threshold == null || threshold < 0 || threshold > 100
                    ? '请输入0至100的整数'
                    : null;
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('必经阶段'),
              value: stage.requiredStage,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => stage.requiredStage = value),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: '上移阶段',
                  onPressed: _saving || index == 0
                      ? null
                      : () => _move(index, -1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: '下移阶段',
                  onPressed: _saving || index == _stages.length - 1
                      ? null
                      : () => _move(index, 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: '移除阶段',
                  onPressed: _saving
                      ? null
                      : () => setState(() => _stages.removeAt(index)),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
