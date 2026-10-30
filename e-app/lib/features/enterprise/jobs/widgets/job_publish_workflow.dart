import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_theme.dart';

const jobPublishStageTypes = <int, String>{
  1: '在线笔试',
  2: 'AI 技术面试',
  3: 'HR 综合面试',
  4: '编程实操',
};

class JobPublishStageDraft {
  JobPublishStageDraft(this.id);
  JobPublishStageDraft.copy(JobPublishStageDraft source) : id = source.id {
    name.text = source.name.text;
    duration.text = source.duration.text;
    threshold.text = source.threshold.text;
    target.text = source.target.text;
    type = source.type;
    required = source.required;
    skip = source.skip;
    terminate = source.terminate;
  }

  final int id;
  final name = TextEditingController(text: jobPublishStageTypes[3]);
  final duration = TextEditingController(text: '45');
  final threshold = TextEditingController(text: '70');
  final target = TextEditingController();
  int type = 3;
  bool required = false;
  bool skip = true;
  bool terminate = false;

  Map<String, Object?> toJson() => {
    'name': name.text.trim(),
    'type': type,
    'duration': int.parse(duration.text),
    'threshold': int.parse(threshold.text),
    'target': target.text.trim(),
    'interviewer': '待指定',
    'required': required,
    'skip': skip,
    'terminate': terminate,
  };

  void dispose() {
    name.dispose();
    duration.dispose();
    threshold.dispose();
    target.dispose();
  }
}

class JobPublishStageEditor extends StatelessWidget {
  const JobPublishStageEditor({
    super.key,
    required this.stage,
    required this.onChanged,
    this.enabled = true,
  });

  final JobPublishStageDraft stage;
  final VoidCallback onChanged;
  final bool enabled;

  String? _integer(String? value, int min, int max) {
    final integer = int.tryParse(value?.trim() ?? '');
    return integer == null || integer < min || integer > max
        ? '请输入$min至$max的整数'
        : null;
  }

  void _step(TextEditingController controller, int delta, int min, int max) {
    final current = int.tryParse(controller.text.trim()) ?? min;
    final next = (current + delta).clamp(min, max).toInt();
    controller.value = controller.value.copyWith(
      text: '$next',
      selection: TextSelection.collapsed(offset: '$next'.length),
      composing: TextRange.empty,
    );
    onChanged();
  }

  Widget _stepper({
    required String field,
    required TextEditingController controller,
    required int min,
    required int max,
  }) => SizedBox(
    width: 44,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepButton(
          key: ValueKey('job-publish-stage-$field-increment-${stage.id}'),
          tooltip: '增加1',
          icon: Icons.keyboard_arrow_up,
          onPressed: enabled ? () => _step(controller, 1, min, max) : null,
        ),
        _stepButton(
          key: ValueKey('job-publish-stage-$field-decrement-${stage.id}'),
          tooltip: '减少1',
          icon: Icons.keyboard_arrow_down,
          onPressed: enabled ? () => _step(controller, -1, min, max) : null,
        ),
      ],
    ),
  );

  Widget _stepButton({
    required Key key,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) => IconButton(
    key: key,
    tooltip: tooltip,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
    visualDensity: VisualDensity.compact,
    onPressed: onPressed,
    icon: Icon(icon, size: 18, color: AppColors.tealDeep),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<int>(
        key: ValueKey('job-publish-stage-type-${stage.id}'),
        initialValue: stage.type,
        isExpanded: true,
        borderRadius: BorderRadius.circular(10),
        dropdownColor: AppColors.canvas,
        decoration: InputDecoration(
          labelText: '面试方式 *',
          filled: true,
          fillColor: AppColors.fieldBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
          ),
        ),
        items: [
          for (final entry in jobPublishStageTypes.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        selectedItemBuilder: (context) => [
          for (final entry in jobPublishStageTypes.entries)
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.teal,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  entry.value,
                  style: const TextStyle(
                    color: AppColors.tealDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
        onChanged: enabled
            ? (value) {
                if (value == null) return;
                stage.type = value;
                onChanged();
              }
            : null,
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final duration = TextFormField(
            key: ValueKey('job-publish-stage-duration-${stage.id}'),
            controller: stage.duration,
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: '时长（分钟）*',
              suffixIcon: _stepper(
                field: 'duration',
                controller: stage.duration,
                min: 1,
                max: 1440,
              ),
              filled: true,
              fillColor: AppColors.fieldBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.teal,
                  width: 1.5,
                ),
              ),
            ),
            validator: (value) => _integer(value, 1, 1440),
          );
          final threshold = TextFormField(
            key: ValueKey('job-publish-stage-threshold-${stage.id}'),
            controller: stage.threshold,
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: '通过阈值（0–100）',
              suffixIcon: _stepper(
                field: 'threshold',
                controller: stage.threshold,
                min: 0,
                max: 100,
              ),
              filled: true,
              fillColor: AppColors.fieldBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.teal,
                  width: 1.5,
                ),
              ),
            ),
            validator: (value) => _integer(value, 0, 100),
          );
          if (constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3) {
            return Column(
              children: [duration, const SizedBox(height: 12), threshold],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: duration),
              const SizedBox(width: 12),
              Expanded(child: threshold),
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      TextFormField(
        key: ValueKey('job-publish-stage-target-${stage.id}'),
        controller: stage.target,
        enabled: enabled,
        maxLines: 2,
        maxLength: 1000,
        decoration: InputDecoration(
          labelText: '重点考察项',
          hintText: '例如：高并发场景设计、系统架构能力',
          filled: true,
          fillColor: AppColors.fieldBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
          ),
        ),
      ),
      const SizedBox(height: 8),
      CheckboxListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.teal,
        title: const Text('必选阶段', style: TextStyle(fontSize: 14)),
        value: stage.required,
        onChanged: enabled
            ? (value) {
                stage.required = value ?? false;
                if (stage.required) stage.skip = false;
                onChanged();
              }
            : null,
      ),
      CheckboxListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.teal,
        title: const Text('允许跳过', style: TextStyle(fontSize: 14)),
        value: stage.skip,
        onChanged: enabled
            ? (value) {
                stage.skip = value ?? false;
                if (stage.skip) stage.required = false;
                onChanged();
              }
            : null,
      ),
      CheckboxListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.teal,
        title: const Text('未通过可终止流程', style: TextStyle(fontSize: 14)),
        value: stage.terminate,
        onChanged: enabled
            ? (value) {
                stage.terminate = value ?? false;
                onChanged();
              }
            : null,
      ),
    ],
  );
}

class JobPublishStageDialog extends StatefulWidget {
  const JobPublishStageDialog({
    super.key,
    required this.stage,
    required this.isNew,
    this.onSave,
    this.onDelete,
  });
  final JobPublishStageDraft stage;
  final bool isNew;
  final Future<bool> Function()? onSave;
  final Future<bool> Function()? onDelete;

  @override
  State<JobPublishStageDialog> createState() => _JobPublishStageDialogState();
}

class _JobPublishStageDialogState extends State<JobPublishStageDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  Future<void> _submit({bool delete = false}) async {
    if (_saving) return;
    if (!delete) {
      if (!_formKey.currentState!.validate()) return;
      widget.stage.name.text = jobPublishStageTypes[widget.stage.type]!;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved =
          await (delete ? widget.onDelete?.call() : widget.onSave?.call()) ??
          true;
      if (!mounted) return;
      if (saved) {
        Navigator.pop(context, !delete);
      } else {
        setState(() => _error = delete ? '删除失败，请核对后重试' : '流程保存失败，请核对后重试');
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message.toString());
    } catch (_) {
      if (mounted) setState(() => _error = delete ? '删除失败，请重试' : '流程保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Dialog(
      backgroundColor: AppColors.canvas,
      surfaceTintColor: AppColors.canvas,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.isNew ? '新增招聘流程' : '编辑招聘流程',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('job-publish-stage-close'),
                    tooltip: '关闭',
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: JobPublishStageEditor(
                      stage: widget.stage,
                      enabled: !_saving,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              const SizedBox(height: 8),
              if (!widget.isNew && widget.onDelete != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('job-publish-stage-delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: _saving ? null : () => _submit(delete: true),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('删除阶段'),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: const Key('job-publish-stage-cancel'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _saving
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('job-publish-stage-save'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _saving ? null : () => _submit(),
                      child: Text(_saving ? '处理中…' : '保存流程'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class JobPublishStageCard extends StatelessWidget {
  const JobPublishStageCard({
    super.key,
    required this.stage,
    required this.index,
    required this.onEdit,
    required this.onRemove,
    this.enabled = true,
    this.bottomActions,
  });
  final JobPublishStageDraft stage;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final bool enabled;
  final Widget? bottomActions;

  @override
  Widget build(BuildContext context) => Card(
    key: ValueKey('job-publish-stage-${stage.id}'),
    margin: EdgeInsets.zero,
    elevation: 0,
    color: AppColors.canvas,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppColors.hairline),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: enabled ? onEdit : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.tealSoft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.tealDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stage.name.text.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.brand,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey('job-publish-stage-edit-${stage.id}'),
                  tooltip: '编辑第${index + 1}个流程',
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  onPressed: enabled ? onEdit : null,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: AppColors.tealDeep,
                  ),
                ),
                IconButton(
                  key: ValueKey('job-publish-stage-remove-${stage.id}'),
                  tooltip: '删除第${index + 1}个流程',
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  onPressed: enabled ? onRemove : null,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  jobPublishStageTypes[stage.type]!,
                  style: const TextStyle(
                    color: AppColors.tealDeep,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${stage.duration.text.trim()}分钟',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '通过阈值 ${stage.threshold.text.trim()}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (stage.target.text.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '考察：${stage.target.text.trim()}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
            if (stage.required || stage.skip || stage.terminate) ...[
              const SizedBox(height: 6),
              Text(
                [
                  if (stage.required) '必选阶段',
                  if (stage.skip) '允许跳过',
                  if (stage.terminate) '未通过可终止流程',
                ].join(' · '),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
            ?bottomActions,
          ],
        ),
      ),
    ),
  );
}

class JobPublishWorkflowPreview extends StatelessWidget {
  const JobPublishWorkflowPreview({super.key, required this.stages});
  final List<JobPublishStageDraft> stages;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '招聘流程',
            style: TextStyle(
              color: AppColors.brand,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '按下列顺序进行',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          for (final (index, stage) in stages.indexed) ...[
            if (index > 0) const Divider(height: 24, color: AppColors.hairline),
            const SizedBox(height: 8),
            Text(
              '${index + 1}. ${stage.name.text.trim()}',
              key: ValueKey('job-publish-stage-preview-${stage.id}'),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${jobPublishStageTypes[stage.type]} · ${stage.duration.text.trim()}分钟 · 通过阈值 ${stage.threshold.text.trim()}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            if (stage.target.text.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                stage.target.text.trim(),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              [
                if (stage.required) '必选阶段',
                if (stage.skip) '允许跳过',
                if (stage.terminate) '未通过可终止流程',
              ].join(' · '),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    ),
  );
}
