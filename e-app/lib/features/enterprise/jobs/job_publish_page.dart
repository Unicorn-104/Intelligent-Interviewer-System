import 'dart:convert';

import 'package:dio/dio.dart' show CancelToken, DioException, ProgressCallback;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../api/jobs_api.dart';
import '../../../api/jd_document_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import 'data/jd_document_picker.dart';
import 'models/jd_import_draft.dart';
import 'widgets/jd_document_import_card.dart';
import 'widgets/jd_import_review_sheet.dart';
import 'widgets/job_publish_select_sheets.dart';
import 'widgets/job_publish_workflow.dart';

typedef JdDocumentParser = Future<JdImportDraft> Function(
  JdPickedDocument document, {
  CancelToken? cancelToken,
  ProgressCallback? onSendProgress,
});

/// Full job form backed by t_pos and the existing structured JD fields.
class JobPublishPage extends StatefulWidget {
  const JobPublishPage({
    super.key,
    this.loadOptions,
    this.editingPositionId,
    this.submitJob,
    this.pickDocument,
    this.parseDocument,
    this.saveWorkflow,
  });

  final int? editingPositionId;
  final Future<Map<String, dynamic>> Function()? loadOptions;
  final Future<Map<String, dynamic>> Function(Map<String, Object?>)? submitJob;
  final Future<JdPickedDocument?> Function()? pickDocument;
  final JdDocumentParser? parseDocument;
  final Future<void> Function(int positionId, Map<String, Object?> body)?
  saveWorkflow;

  @override
  State<JobPublishPage> createState() => _JobPublishPageState();
}

class _JobPublishPageState extends State<JobPublishPage> {
  final _formKey = GlobalKey<FormState>();
  final _stages = <JobPublishStageDraft>[];
  final _allStages = <JobPublishStageDraft>[];
  int _nextStageId = 0;
  int? _createdPositionId;
  final _title = TextEditingController();
  final _department = TextEditingController();
  final _city = TextEditingController();
  final _salaryMin = TextEditingController();
  final _salaryMax = TextEditingController();
  final _responsibilities = TextEditingController();
  final _requirements = TextEditingController();
  final _scroll = ScrollController();
  Map<String, dynamic>? _company;
  List<String> _departments = const [];
  bool _loading = true;
  bool _saving = false;
  bool _preview = false;
  bool _negotiable = false;
  bool _dirty = false;
  bool _allowPop = false;
  bool _needsListCheck = false;
  String? _error;
  int _education = 3;
  int _jobType = 1;
  String _experience = '经验不限';
  final _documentPicker = JdDocumentPicker();
  final _skills = <JdImportSkill>[];
  JdDocumentImportPhase _importPhase = JdDocumentImportPhase.idle;
  JdImportDraft? _importDraft;
  JdPickedDocument? _retryDocument;
  CancelToken? _importCancellation;
  String? _importFilename;
  String? _draftFilename;
  String? _importError;
  int _importEpoch = 0;
  int _sentBytes = 0;
  int _totalBytes = 0;
  int _formImportRevision = 0;
  bool _reviewOpen = false;
  bool _stageEditorOpen = false;
  bool _confirmingLeave = false;
  bool _draftApplied = false;

  bool get _editing => widget.editingPositionId != null;

  bool get _importBusy => switch (_importPhase) {
    JdDocumentImportPhase.selecting ||
    JdDocumentImportPhase.uploading ||
    JdDocumentImportPhase.parsing => true,
    _ => false,
  };

  static const _educationLabels = {
    0: '学历不限',
    1: '中专',
    2: '大专',
    3: '本科',
    4: '硕士',
    5: '博士',
  };
  static const _jobTypeLabels = {1: '全职', 2: '兼职', 3: '实习'};
  static const _experiences = [
    '经验不限',
    '应届生',
    '1年以内',
    '1-3年',
    '3-5年',
    '5-10年',
    '10年以上',
  ];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _cancelImport();
    for (final controller in [
      _title,
      _department,
      _city,
      _salaryMin,
      _salaryMax,
      _responsibilities,
      _requirements,
    ]) {
      controller.dispose();
    }
    for (final stage in _allStages) {
      stage.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final options = await (widget.loadOptions ?? _defaultOptions)();
      final company = options['company'];
      if (company is! Map || company['id'] == null || company['name'] == null) {
        throw const ApiException('无法读取所属企业，请稍后重试');
      }
      if (!mounted) return;
      if (_editing) _fillExisting(options);
      setState(() {
        _company = Map<String, dynamic>.from(company);
        _departments =
            (options['departments'] as List?)
                ?.whereType<String>()
                .where((s) => s.trim().isNotEmpty)
                .toList() ??
            [];
        if (_city.text.isEmpty) _city.text = '${company['city'] ?? ''}';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  String _message(Object error) => switch (error) {
    ApiException() => error.message,
    FormatException() => error.message,
    _ => '暂时无法连接服务，请稍后重试',
  };

  Future<void> _leave() async {
    if (_saving || _allowPop || _confirmingLeave) return;
    if (_createdPositionId != null) {
      _confirmingLeave = true;
      bool? leave;
      try {
        leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('招聘流程尚未保存'),
            content: const Text('岗位已创建，招聘流程尚未保存。可以继续重试保存，或返回岗位列表后在岗位详情中配置流程。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('继续保存'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('返回岗位列表'),
              ),
            ],
          ),
        );
      } finally {
        _confirmingLeave = false;
      }
      if (leave == true && mounted) _finishPublish(_createdPositionId!);
      return;
    }
    if (_dirty || _importBusy || _importDraft != null) {
      _confirmingLeave = true;
      bool? discard;
      try {
        discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(_editing ? '放弃岗位修改？' : '离开岗位发布？'),
            content: Text(
              _importBusy
                  ? '离开后将停止等待本次解析，已填写的内容不会保留。'
                  : (_editing
                        ? '岗位修改尚未保存，离开后将不会保留。'
                        : '已填写的内容或待核对草稿尚未发布，离开后将不会保留。'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('继续填写'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('离开'),
              ),
            ],
          ),
        );
      } finally {
        _confirmingLeave = false;
      }
      if (discard != true || !mounted) return;
    }
    _cancelImport();
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  void _cancelImport() {
    _importEpoch++;
    _importCancellation?.cancel('Leaving job publishing');
    _importCancellation = null;
    _retryDocument = null;
  }

  bool _acceptsImport(int epoch) =>
      mounted && !_allowPop && epoch == _importEpoch;

  Future<void> _startImport({bool retry = false}) async {
    if (_importBusy ||
        _saving ||
        _preview ||
        _reviewOpen ||
        _stageEditorOpen ||
        _allowPop) {
      return;
    }
    FocusScope.of(context).unfocus();
    final epoch = ++_importEpoch;
    setState(() {
      _importPhase = retry
          ? JdDocumentImportPhase.uploading
          : JdDocumentImportPhase.selecting;
      _importError = null;
      _sentBytes = 0;
      _totalBytes = 0;
      if (!retry) _retryDocument = null;
    });
    var completed = false;
    try {
      final document = retry
          ? _retryDocument
          : await (widget.pickDocument ?? _documentPicker.pick)();
      if (!_acceptsImport(epoch)) return;
      if (document == null) return;
      final cancellation = CancelToken();
      _importCancellation = cancellation;
      setState(() {
        _retryDocument = document;
        _importFilename = document.name;
        _importPhase = JdDocumentImportPhase.uploading;
      });
      final draft = await (widget.parseDocument ?? parseJdDocument)(
        document,
        cancelToken: cancellation,
        onSendProgress: (sent, total) {
          if (!_acceptsImport(epoch)) return;
          setState(() {
            _sentBytes = sent;
            _totalBytes = total;
            _importPhase = total > 0 && sent >= total
                ? JdDocumentImportPhase.parsing
                : JdDocumentImportPhase.uploading;
          });
        },
      );
      if (!_acceptsImport(epoch)) return;
      setState(() {
        _importDraft = draft;
        _draftFilename = document.name;
        _draftApplied = false;
        _importPhase = JdDocumentImportPhase.ready;
      });
      completed = true;
    } catch (error) {
      if (!_acceptsImport(epoch)) return;
      if (error is! DioException || !CancelToken.isCancel(error)) {
        setState(() {
          _importError = switch (error) {
            JdDocumentSelectionException() => error.message,
            ApiException() => error.message,
            _ => '暂时无法解析文档，请稍后重试',
          };
        });
      }
    } finally {
      if (_acceptsImport(epoch)) {
        _importCancellation = null;
        if (_importBusy) {
          setState(
            () => _importPhase = _importDraft == null
                ? JdDocumentImportPhase.idle
                : JdDocumentImportPhase.ready,
          );
        }
      }
    }
    if (completed && _acceptsImport(epoch) && !_confirmingLeave) {
      await _reviewDraft();
    }
  }

  Map<String, Object?> _importSnapshot() => {
    ..._payload(),
    'salaryMin': _salaryMin.text.trim(),
    'salaryMax': _salaryMax.text.trim(),
    'negotiable': _negotiable,
  };

  Future<void> _reviewDraft() async {
    final draft = _importDraft;
    if (draft == null ||
        _reviewOpen ||
        _stageEditorOpen ||
        _importBusy ||
        _saving ||
        _allowPop ||
        _confirmingLeave) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _reviewOpen = true);
    try {
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.canvas,
        constraints: const BoxConstraints(maxWidth: 760),
        builder: (context) => JdImportReviewSheet(
          draft: draft,
          filename: _draftFilename,
          readCurrent: _importSnapshot,
          onApply: _applyImportedPatch,
        ),
      );
    } finally {
      if (mounted) setState(() => _reviewOpen = false);
    }
  }

  void _applyImportedPatch(JdImportPatch patch) {
    if (!mounted || _allowPop) return;
    setState(() {
      if (!patch.isEmpty) _dirty = true;
      final controllers = {
        'title': _title,
        'dept': _department,
        'city': _city,
        'salaryMin': _salaryMin,
        'salaryMax': _salaryMax,
      };
      for (final entry in controllers.entries) {
        if (patch.values.containsKey(entry.key)) {
          entry.value.text = patch.values[entry.key] as String;
        }
      }
      if (patch.values.containsKey('salaryMin')) _negotiable = false;
      if (patch.values.containsKey('experience')) {
        _experience = patch.values['experience'] as String;
      }
      if (patch.values.containsKey('education')) {
        _education = patch.values['education'] as int;
      }
      if (patch.values.containsKey('jobType')) {
        _jobType = patch.values['jobType'] as int;
      }
      if (patch.values.containsKey('responsibilities')) {
        _responsibilities.text =
            (patch.values['responsibilities'] as List<String>).join('\n');
      }
      if (patch.values.containsKey('requirements')) {
        _requirements.text = (patch.values['requirements'] as List<String>)
            .join('\n');
      }
      if (patch.values.containsKey('skills')) {
        _skills
          ..clear()
          ..addAll(
            (patch.values['skills'] as List<Map<String, Object?>>).map(
              (skill) => JdImportSkill(
                name: skill['name'] as String,
                requiredFlag: skill['required'] as int?,
              ),
            ),
          );
      }
      if (!patch.isEmpty) _formImportRevision++;
      _draftApplied = true;
      _importError = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          patch.isEmpty ? '内容与当前表单一致，未覆盖任何字段' : '草稿已回填，请核对必填项后预览发布',
        ),
      ),
    );
  }

  Future<void> _pickDepartment() async {
    if (_saving || _reviewOpen || _preview || _allowPop) return;
    FocusScope.of(context).unfocus();
    final selected = await showJobDepartmentSheet(
      context,
      departments: _departments,
      current: _department.text.trim(),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _department.text = selected;
      _dirty = true;
    });
  }

  Future<void> _pickCity() async {
    if (_saving || _reviewOpen || _preview || _allowPop) return;
    FocusScope.of(context).unfocus();
    final selected = await showJobCitySheet(
      context,
      current: _city.text.trim(),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _city.text = selected;
      _dirty = true;
    });
  }

  Future<void> _editSkill([int? index]) async {
    if (_saving || _reviewOpen) return;
    if (index == null && _skills.length >= 30) return;
    final skill = await showDialog<JdImportSkill>(
      context: context,
      builder: (context) => _JdSkillEditor(
        skill: index == null ? null : _skills[index],
        existingNames: [
          for (var i = 0; i < _skills.length; i++)
            if (i != index) _skills[i].name,
        ],
      ),
    );
    if (!mounted || _allowPop || skill == null) return;
    setState(() {
      if (index == null) {
        _skills.add(skill);
      } else {
        _skills[index] = skill;
      }
      _dirty = true;
    });
  }

  Future<Map<String, dynamic>> _defaultOptions() async {
    final options = await getJobPublishingOptions();
    if (!_editing) return options;
    final detail = await getJobDetail(widget.editingPositionId!);
    return {...options, 'job': detail['job'], 'skills': detail['skills']};
  }

  void _fillExisting(Map<String, dynamic> options) {
    final raw = options['job'];
    final skills = options['skills'];
    if (raw is! Map ||
        int.tryParse('${raw['posId']}') != widget.editingPositionId ||
        skills is! List) {
      throw const FormatException('岗位编辑数据不完整，请刷新后重试');
    }
    final json = raw['jdJson'];
    final description = json == null || json == ''
        ? <String, dynamic>{}
        : json is String
        ? jsonDecode(json)
        : json;
    if (description is! Map) throw const FormatException('岗位描述格式不正确');
    String lines(Object? value) {
      if (value == null) return '';
      if (value is String) return value;
      if (value is List && value.every((item) => item is String)) {
        return value.join('\n');
      }
      throw const FormatException('岗位职责或要求格式不正确');
    }

    final loadedSkills = <JdImportSkill>[];
    for (final skill in skills) {
      if (skill is! Map ||
          skill['name'] is! String ||
          (skill['name'] as String).trim().isEmpty) {
        throw const FormatException('岗位技能格式不正确');
      }
      final flag = skill['required'] == null
          ? null
          : int.tryParse('${skill['required']}');
      if (skill['required'] != null && flag != 0 && flag != 1) {
        throw const FormatException('技能必备标识无效');
      }
      loadedSkills.add(
        JdImportSkill(name: skill['name'] as String, requiredFlag: flag),
      );
    }
    final education = raw['education'] == null
        ? 0
        : int.tryParse('${raw['education']}');
    final jobType = int.tryParse('${raw['jobType']}');
    if (!_educationLabels.containsKey(education) ||
        !_jobTypeLabels.containsKey(jobType)) {
      throw const FormatException('岗位学历或工作性质无效，请核对原岗位数据');
    }
    _title.text = '${raw['title'] ?? ''}';
    _department.text = '${raw['dept'] ?? ''}';
    _city.text = '${raw['city'] ?? ''}';
    _salaryMin.text = '${raw['salaryMin'] ?? ''}';
    _salaryMax.text = '${raw['salaryMax'] ?? ''}';
    _negotiable = raw['salaryMin'] == null && raw['salaryMax'] == null;
    _experience = '${raw['experience'] ?? '经验不限'}';
    _education = education!;
    _jobType = jobType!;
    _responsibilities.text = lines(description['responsibilities']);
    _requirements.text = lines(description['requirements']);
    _skills
      ..clear()
      ..addAll(loadedSkills);
    _formImportRevision++;
  }

  List<String> _lines(TextEditingController controller) => controller.text
      .split(RegExp(r'\r?\n'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  Map<String, Object?> _payload() => {
    'title': _title.text.trim(),
    'dept': _department.text.trim(),
    'city': _city.text.trim(),
    'salaryMin': _negotiable ? null : _salaryMin.text.trim(),
    'salaryMax': _negotiable ? null : _salaryMax.text.trim(),
    'experience': _experience,
    'education': _education == 0 ? null : _education,
    'jobType': _jobType,
    'responsibilities': _lines(_responsibilities),
    'requirements': _lines(_requirements),
    'skills': _skills.map((skill) => skill.toJson()).toList(),
    if (!_editing) 'status': 1,
  };

  void _showPreview() {
    if (_importBusy || _reviewOpen || _stageEditorOpen || _saving) return;
    FocusScope.of(context).unfocus();
    final jobValid = _formKey.currentState!.validate();
    if (!jobValid) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    setState(() {
      _preview = true;
      _error = null;
    });
    _scroll.jumpTo(0);
  }

  Map<String, Object?> _workflowPayload() {
    final title = _title.text.trim();
    return {
      'templateName':
          '${title.length > 96 ? title.substring(0, 96) : title}招聘流程',
      'stages': [for (final stage in _stages) stage.toJson()],
    };
  }

  void _finishPublish(int positionId) {
    setState(() {
      _allowPop = true;
      _dirty = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, positionId);
    });
  }

  Future<void> _publish() async {
    if (_saving || _importBusy || _reviewOpen || _needsListCheck) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_editing) {
        final id = widget.editingPositionId!;
        final result =
            await (widget.submitJob ?? (body) => updateJob(id, body))(
              _payload(),
            );
        if (!mounted) return;
        if (int.tryParse('${result['posId']}') != id) {
          throw const ApiException('保存响应的岗位编号不一致，请刷新核对');
        }
        _finishPublish(id);
        return;
      }
      if (_createdPositionId == null) {
        final result = await (widget.submitJob ?? createJob)(_payload());
        final positionId = int.tryParse('${result['posId']}');
        if (!mounted) return;
        if (positionId == null || positionId <= 0) {
          setState(() {
            _error = '服务已响应，但未返回岗位编号。请返回岗位列表核对，避免重复发布。';
            _allowPop = true;
            _saving = false;
            _needsListCheck = true;
          });
          return;
        }
        _createdPositionId = positionId;
      }
      if (_stages.isNotEmpty) {
        await (widget.saveWorkflow ?? saveJobWorkflow)(
          _createdPositionId!,
          _workflowPayload(),
        );
      }
      if (!mounted) return;
      _finishPublish(_createdPositionId!);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _createdPositionId == null
            ? _message(error)
            : '岗位已创建，招聘流程保存失败：${_message(error)}。请重试保存流程，避免重复发布。';
      });
    }
  }

  Future<void> _editStage({JobPublishStageDraft? existing}) async {
    if (_saving || _preview || _reviewOpen || _stageEditorOpen || _allowPop) {
      return;
    }
    FocusScope.of(context).unfocus();
    final stage = existing == null
        ? JobPublishStageDraft(_nextStageId++)
        : JobPublishStageDraft.copy(existing);
    _allStages.add(stage);
    setState(() => _stageEditorOpen = true);
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) => JobPublishStageDialog(
          stage: stage,
          isNew: existing == null,
          onDelete: existing == null
              ? null
              : () async {
                  setState(() {
                    _stages.remove(existing);
                    _dirty = true;
                  });
                  return true;
                },
        ),
      );
      if (!mounted || saved != true) return;
      setState(() {
        if (existing == null) {
          _stages.add(stage);
        } else {
          _stages[_stages.indexOf(existing)] = stage;
        }
        _dirty = true;
      });
    } finally {
      if (mounted) setState(() => _stageEditorOpen = false);
    }
  }

  Widget _workflowEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Material(
        color: AppColors.tealSoft,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: const Key('job-publish-add-stage'),
          borderRadius: BorderRadius.circular(12),
          onTap: _saving || _reviewOpen || _stageEditorOpen
              ? null
              : () => _editStage(),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.teal.withValues(alpha: .4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.teal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '新增招聘流程',
                    style: TextStyle(
                      color: AppColors.tealDeep,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.tealDeep,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
      for (final (index, stage) in _stages.indexed) ...[
        const SizedBox(height: 12),
        JobPublishStageCard(
          key: ValueKey('job-publish-stage-card-${stage.id}'),
          stage: stage,
          index: index,
          enabled: !_saving && !_stageEditorOpen,
          onEdit: () => _editStage(existing: stage),
          onRemove: () => setState(() {
            _stages.remove(stage);
            _dirty = true;
          }),
        ),
      ],
    ],
  );

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? '请填写$label' : null;

  String? _salary(String? value, {bool upper = false}) {
    if (_negotiable) return null;
    final text = value?.trim() ?? '';
    final amount = num.tryParse(text);
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text) ||
        amount == null ||
        amount <= 0 ||
        amount >= 100000000) {
      return '请输入有效月薪，最多两位小数';
    }
    final lower = num.tryParse(_salaryMin.text.trim());
    if (upper && lower != null && amount < lower) return '最高月薪不得低于最低月薪';
    return null;
  }

  String? _description(String? value, String label) {
    final required = _required(value, label);
    if (required != null) return required;
    final lines = value!
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (lines.length > 30) return '最多填写30条';
    if (lines.any((line) => line.length > 1000)) return '每条最多1000个字符';
    if (lines.join('\n').length > 10000) return '总长度最多10000个字符';
    return null;
  }

  InputDecoration _decoration(
    String label, {
    String? hint,
    IconData? icon,
    Widget? suffixIcon,
    bool showCounter = false,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    alignLabelWithHint: true,
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    suffixIcon: suffixIcon,
    counterText: showCounter ? null : '',
    errorMaxLines: 2,
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
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop:
        _allowPop ||
        (!_dirty && !_saving && !_importBusy && _importDraft == null),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.pageBackground,
        leading: IconButton(
          onPressed: _needsListCheck
              ? () => Navigator.pop(context, 0)
              : _saving
              ? null
              : _leave,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          _preview
              ? (_editing ? '预览修改' : '预览岗位')
              : (_editing ? '编辑岗位' : '发布岗位'),
        ),
        actions: [
          if (!_loading && _company != null)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Center(
                child: Text(
                  _preview ? '2 / 2' : '1 / 2',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _company == null
          ? PageMessage(
              icon: Icons.business_outlined,
              title: _editing ? '暂时无法编辑岗位' : '暂时无法发布岗位',
              message: _error ?? '请确认企业绑定状态',
              actionLabel: '重试',
              onAction: _loadOptions,
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _hero(),
                      const SizedBox(height: 20),
                      if (_preview)
                        ..._previewContent()
                      else ...[
                        JdDocumentImportCard(
                          phase: _importPhase,
                          filename: _importFilename,
                          error: _importError,
                          sentBytes: _sentBytes,
                          totalBytes: _totalBytes,
                          hasDraft: _importDraft != null,
                          applied: _draftApplied,
                          enabled:
                              !_saving && !_reviewOpen && !_stageEditorOpen,
                          onImport: _startImport,
                          onRetry: _retryDocument == null
                              ? null
                              : () => _startImport(retry: true),
                          onReview: _reviewDraft,
                        ),
                        const SizedBox(height: 12),
                        if (!_editing) _workflowEditor(),
                        const SizedBox(height: 20),
                        _form(),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: const TextStyle(color: AppColors.red),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar:
          _loading || _company == null || _reviewOpen || _stageEditorOpen
          ? null
          : _footer(),
    ),
  );

  Widget _hero() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.teal, Color(0xFF00A3C6)],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x2200BFA5),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: -18,
          bottom: -22,
          child: Icon(
            Icons.apartment_rounded,
            size: 130,
            color: AppColors.canvas.withValues(alpha: 0.1),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.canvas.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.business_outlined,
                    color: AppColors.canvas,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_company!['name']}',
                    style: const TextStyle(
                      color: AppColors.canvas,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _editing
                  ? '完善岗位信息'
                  : (_preview ? '好的岗位，值得被看见' : '让合适的人才找到你'),
              style: const TextStyle(
                color: AppColors.canvas,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _editing
                  ? '修改职位信息，清晰表达团队的期待。'
                  : (_preview
                        ? '确认信息后发布，岗位将进入招聘中状态。'
                        : '完善职位信息，清晰表达团队的期待。'),
              style: TextStyle(
                color: AppColors.canvas.withValues(alpha: 0.9),
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _section(
    String number,
    String title,
    String subtitle,
    List<Widget> children,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12152B49),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.tealSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                number,
                style: const TextStyle(
                  color: AppColors.tealDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.brand,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        ...children,
      ],
    ),
  );

  Widget _pair(Widget left, Widget right) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < 360
        ? Column(children: [left, const SizedBox(height: 16), right])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              Expanded(child: right),
            ],
          ),
  );

  Widget _form() => Form(
    key: _formKey,
    onChanged: () {
      if (!_dirty) setState(() => _dirty = true);
    },
    child: Column(
      children: [
        _section('01', '基本信息', '带 * 的信息为必填，帮助候选人快速了解岗位', [
          TextFormField(
            key: const Key('job-title'),
            controller: _title,
            maxLength: 100,
            textInputAction: TextInputAction.next,
            decoration: _decoration(
              '岗位名称 *',
              hint: '请输入岗位名称',
              icon: Icons.work_outline,
            ),
            validator: (value) => _required(value, '岗位名称'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('job-department'),
            controller: _department,
            readOnly: true,
            onTap: _pickDepartment,
            decoration: _decoration(
              '所属部门 *',
              hint: '请选择所属部门',
              icon: Icons.apartment_outlined,
              suffixIcon: const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.textMuted,
              ),
            ),
            validator: (value) => _required(value, '所属部门'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('job-city'),
            controller: _city,
            readOnly: true,
            onTap: _pickCity,
            decoration: _decoration(
              '工作城市 *',
              hint: '请选择工作城市',
              icon: Icons.location_on_outlined,
              suffixIcon: const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.textMuted,
              ),
            ),
            validator: (value) => _required(value, '工作城市'),
          ),
        ]),
        _section('02', '薪资与任职条件', '月薪单位为人民币元，面议时无需填写薪资范围', [
          Material(
            color: Colors.transparent,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('薪资面议'),
              subtitle: const Text('开启后，候选人将看到“面议”'),
              value: _negotiable,
              activeThumbColor: AppColors.teal,
              activeTrackColor: AppColors.tealSoft,
              onChanged: (value) => setState(() {
                _negotiable = value;
                _dirty = true;
              }),
            ),
          ),
          if (!_negotiable) ...[
            const SizedBox(height: 12),
            _pair(
              TextFormField(
                key: const Key('job-salary-min'),
                controller: _salaryMin,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: _decoration('最低月薪 *', hint: '例如：15000'),
                validator: (value) => _salary(value),
              ),
              TextFormField(
                key: const Key('job-salary-max'),
                controller: _salaryMax,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: _decoration('最高月薪 *', hint: '例如：25000'),
                validator: (value) => _salary(value, upper: true),
              ),
            ),
          ],
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            key: ValueKey('job-experience-$_formImportRevision'),
            initialValue: _experience,
            isExpanded: true,
            borderRadius: BorderRadius.circular(10),
            dropdownColor: AppColors.canvas,
            decoration: _decoration('经验要求'),
            items: {..._experiences, _experience}
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _experience = value;
                  _dirty = true;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          _pair(
            DropdownButtonFormField<int>(
              key: ValueKey('job-education-$_formImportRevision'),
              initialValue: _education,
              isExpanded: true,
              borderRadius: BorderRadius.circular(10),
              dropdownColor: AppColors.canvas,
              decoration: _decoration('学历要求'),
              items: _educationLabels.entries
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.key,
                      child: Text(item.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _education = value;
                    _dirty = true;
                  });
                }
              },
            ),
            DropdownButtonFormField<int>(
              key: ValueKey('job-type-$_formImportRevision'),
              initialValue: _jobType,
              isExpanded: true,
              borderRadius: BorderRadius.circular(10),
              dropdownColor: AppColors.canvas,
              decoration: _decoration('工作性质'),
              items: _jobTypeLabels.entries
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.key,
                      child: Text(item.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _jobType = value;
                    _dirty = true;
                  });
                }
              },
            ),
          ),
        ]),
        _section('03', '岗位描述', '每行一条，清晰的职责和要求能帮助双方更好地匹配', [
          TextFormField(
            key: const Key('job-responsibilities'),
            controller: _responsibilities,
            minLines: 5,
            maxLines: 10,
            maxLength: 10000,
            decoration: _decoration(
              '工作职责 *',
              hint: '这个岗位主要负责哪些工作？\n请按实际职责逐行填写',
              showCounter: true,
            ),
            validator: (value) => _description(value, '工作职责'),
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('job-requirements'),
            controller: _requirements,
            minLines: 5,
            maxLines: 10,
            maxLength: 10000,
            decoration: _decoration(
              '任职要求 *',
              hint: '期望候选人具备哪些技能与经历？\n请按实际要求逐行填写',
              showCounter: true,
            ),
            validator: (value) => _description(value, '任职要求'),
          ),
        ]),
        _skillSection(),
      ],
    ),
  );

  List<Widget> _previewContent() => [
    _section(
      '01',
      _title.text.trim(),
      '${_department.text.trim()} · ${_city.text.trim()}',
      [
        Text(
          _negotiable
              ? '薪资面议'
              : '¥${_salaryMin.text.trim()} – ${_salaryMax.text.trim()} / 月',
          style: const TextStyle(
            color: AppColors.accentOrange,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              [
                    _experience,
                    _educationLabels[_education]!,
                    _jobTypeLabels[_jobType]!,
                  ]
                  .map(
                    (label) => Chip(
                      label: Text(label),
                      backgroundColor: AppColors.background,
                      side: BorderSide.none,
                    ),
                  )
                  .toList(),
        ),
      ],
    ),
    _section(
      '02',
      '工作职责',
      _editing ? '保存后将按以下条目展示' : '发布后将按以下条目展示',
      _lines(_responsibilities).map(_bullet).toList(),
    ),
    _section(
      '03',
      '任职要求',
      '请确认内容真实、清晰且与岗位相关',
      _lines(_requirements).map(_bullet).toList(),
    ),
    if (_skills.isNotEmpty)
      _section('04', '技能标签', '以下技能及必备标识将随岗位保存', [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _skills
              .map(
                (skill) => Chip(
                  label: Text('${skill.name} · ${skill.requirementLabel}'),
                  labelStyle: const TextStyle(color: AppColors.tealDeep),
                  backgroundColor: AppColors.tealSoft,
                  side: BorderSide.none,
                ),
              )
              .toList(),
        ),
      ]),
    if (_stages.isNotEmpty) ...[
      JobPublishWorkflowPreview(stages: _stages),
      const SizedBox(height: 20),
    ],
    if (_draftApplied) ...[
      const Text(
        'AI 结果仅供参考，请确认导入内容已核对。',
        style: TextStyle(color: AppColors.accentPurple),
      ),
      const SizedBox(height: 12),
    ],
  ];

  Widget _skillSection() =>
      _section('04', '技能标签', '最多30项；“未注明”会保留为空，不会自动视为必备', [
        if (_skills.isEmpty)
          const Text(
            '可从文档导入技能，也可手动添加。',
            style: TextStyle(color: AppColors.textMuted),
          ),
        if (_skills.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < _skills.length; index++)
                _skillTag(index),
            ],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('job-add-skill'),
            onPressed: _skills.length >= 30 ? null : () => _editSkill(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.tealDeep,
              backgroundColor: AppColors.tealSoft,
              side: const BorderSide(color: AppColors.teal, width: 1.2),
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              '添加技能',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ]);

  /// 技能浅青标签：点击编辑，标签内关闭图标删除。
  Widget _skillTag(int index) {
    final skill = _skills[index];
    return Material(
      color: AppColors.tealSoft,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: ValueKey('job-skill-$index'),
        borderRadius: BorderRadius.circular(8),
        onTap: _saving ? null : () => _editSkill(index),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.teal.withValues(alpha: .35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${skill.name} · ${skill.requirementLabel}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.tealDeep,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _saving
                    ? null
                    : () => setState(() {
                        _skills.removeAt(index);
                        _dirty = true;
                      }),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 15,
                    color: AppColors.tealDeep,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '•  ',
          style: TextStyle(color: AppColors.interactive, height: 1.6),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.body, height: 1.6),
          ),
        ),
      ],
    ),
  );

  Widget _footer() => Container(
    decoration: const BoxDecoration(
      color: AppColors.canvas,
      border: Border(top: BorderSide(color: AppColors.hairline)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          children: [
            if (_preview && !_needsListCheck && _createdPositionId == null) ...[
              OutlinedButton(
                onPressed: _saving
                    ? null
                    : () {
                        setState(() {
                          _preview = false;
                          _error = null;
                        });
                        _scroll.jumpTo(0);
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.tealDeep,
                  minimumSize: const Size(0, 52),
                  side: const BorderSide(color: AppColors.hairline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('返回修改'),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [AppColors.teal, Color(0xFF00A3C6)],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3300BFA5),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                key: const Key('job-publish-action'),
                onPressed: _needsListCheck
                    ? () => Navigator.pop(context, 0)
                    : _saving || _importBusy
                    ? null
                    : _preview
                    ? _publish
                    : _showPreview,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _preview
                            ? Icons.check_circle_outline
                            : Icons.arrow_forward_rounded,
                        size: 20,
                      ),
                label: Text(
                  _needsListCheck
                      ? '返回岗位列表'
                      : _saving
                      ? (_editing
                            ? '正在保存…'
                            : (_createdPositionId == null
                                  ? '正在发布…'
                                  : '正在保存流程…'))
                      : _preview
                      ? (_editing
                            ? '保存修改'
                            : (_createdPositionId == null ? '确认发布' : '重试保存流程'))
                      : (_editing ? '预览修改' : '预览岗位'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _JdSkillEditor extends StatefulWidget {
  const _JdSkillEditor({required this.existingNames, this.skill});

  final List<String> existingNames;
  final JdImportSkill? skill;

  @override
  State<_JdSkillEditor> createState() => _JdSkillEditorState();
}

class _JdSkillEditorState extends State<_JdSkillEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  int? _requiredFlag;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.skill?.name ?? '');
    _requiredFlag = widget.skill?.requiredFlag;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.canvas,
    surfaceTintColor: AppColors.canvas,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: Text(
      widget.skill == null ? '添加技能' : '编辑技能',
      style: const TextStyle(
        color: AppColors.brand,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('job-skill-name'),
                controller: _name,
                maxLength: 50,
                decoration: InputDecoration(
                  labelText: '技能名称',
                  hintText: '请输入技能名称',
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
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return '请填写技能名称';
                  if (name.length > 50) return '技能名称最多50个字符';
                  if (widget.existingNames.any(
                    (existing) => existing.toLowerCase() == name.toLowerCase(),
                  )) {
                    return '该技能已存在';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                '技能要求',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final (flag, label) in const [(-1, '未注明'), (1, '必备'), (0, '加分')]) ...[
                    if (flag != -1) const SizedBox(width: 8),
                    Expanded(
                      child: _requiredSegment(
                        key: ValueKey('job-skill-required-$flag'),
                        flag: flag,
                        label: label,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        key: const Key('job-skill-cancel'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          minimumSize: const Size(0, 44),
        ),
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const Key('job-skill-save'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal,
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(
              context,
              JdImportSkill(
                name: _name.text.trim(),
                requiredFlag: _requiredFlag,
              ),
            );
          }
        },
        child: const Text('保存技能'),
      ),
    ],
  );

  /// 技能要求分段选择：选中青绿底，未选中浅灰底。
  Widget _requiredSegment({
    required Key key,
    required int flag,
    required String label,
  }) {
    final selected = (_requiredFlag ?? -1) == flag;
    return Material(
      key: key,
      color: selected ? AppColors.teal : AppColors.fieldBackground,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(
          () => _requiredFlag = flag == -1 ? null : flag,
        ),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.teal : AppColors.hairline,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
