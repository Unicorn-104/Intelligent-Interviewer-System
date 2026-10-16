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
    this.submitJob,
    this.pickDocument,
    this.parseDocument,
  });

  final Future<Map<String, dynamic>> Function()? loadOptions;
  final Future<Map<String, dynamic>> Function(Map<String, Object?>)? submitJob;
  final Future<JdPickedDocument?> Function()? pickDocument;
  final JdDocumentParser? parseDocument;

  @override
  State<JobPublishPage> createState() => _JobPublishPageState();
}

class _JobPublishPageState extends State<JobPublishPage> {
  final _formKey = GlobalKey<FormState>();
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
  bool _confirmingLeave = false;
  bool _draftApplied = false;

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
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final options = await (widget.loadOptions ?? getJobPublishingOptions)();
      final company = options['company'];
      if (company is! Map || company['id'] == null || company['name'] == null) {
        throw const ApiException('无法读取所属企业，请稍后重试');
      }
      if (!mounted) return;
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

  String _message(Object error) =>
      error is ApiException ? error.message : '暂时无法连接服务，请稍后重试';

  Future<void> _leave() async {
    if (_saving || _allowPop || _confirmingLeave) return;
    if (_dirty || _importBusy || _importDraft != null) {
      _confirmingLeave = true;
      bool? discard;
      try {
        discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('离开岗位发布？'),
            content: Text(
              _importBusy
                  ? '离开后将停止等待本次解析，已填写的内容不会保留。'
                  : '已填写的内容或待核对草稿尚未发布，离开后将不会保留。',
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
    if (_importBusy || _saving || _preview || _reviewOpen || _allowPop) return;
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
    'status': 1,
  };

  void _showPreview() {
    if (_importBusy || _reviewOpen || _saving) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
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

  Future<void> _publish() async {
    if (_saving || _importBusy || _reviewOpen || _needsListCheck) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await (widget.submitJob ?? createJob)(_payload());
      final positionId = int.tryParse('${result['posId']}');
      if (!mounted) return;
      if (positionId == null) {
        // A successful response may already have created the job. Prevent a
        // second submission when the response cannot identify it.
        setState(() {
          _error = '服务已响应，但未返回岗位编号。请返回岗位列表核对，避免重复发布。';
          _allowPop = true;
          _saving = false;
          _needsListCheck = true;
        });
        return;
      }
      setState(() {
        _allowPop = true;
        _dirty = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, positionId);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _message(error);
      });
    }
  }

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

  InputDecoration _decoration(String label, {String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
        counterText: '',
        errorMaxLines: 2,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.hairline),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: _needsListCheck
              ? () => Navigator.pop(context, 0)
              : _saving
              ? null
              : _leave,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(_preview ? '预览岗位' : '发布岗位'),
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
              title: '暂时无法发布岗位',
              message: _error ?? '请确认企业绑定状态',
              actionLabel: '重试',
              onAction: _loadOptions,
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
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
                        enabled: !_saving && !_reviewOpen,
                        onImport: _startImport,
                        onRetry: _retryDocument == null
                            ? null
                            : () => _startImport(retry: true),
                        onReview: _reviewDraft,
                      ),
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
      bottomNavigationBar: _loading || _company == null || _reviewOpen
          ? null
          : _footer(),
    ),
  );

  Widget _hero() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.brandDeep, AppColors.brand, AppColors.interactive],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.business_center_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${_company!['name']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          _preview ? '好的岗位，值得被看见' : '让合适的人才找到你',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _preview ? '确认信息后发布，岗位将进入招聘中状态。' : '完善职位信息，清晰表达团队的期待。',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 13,
            height: 1.6,
          ),
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
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                number,
                style: const TextStyle(
                  color: AppColors.interactive,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
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
              hint: '例如：Flutter 开发工程师',
              icon: Icons.work_outline,
            ),
            validator: (value) => _required(value, '岗位名称'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('job-department'),
            controller: _department,
            maxLength: 50,
            textInputAction: TextInputAction.next,
            decoration: _decoration(
              '所属部门 *',
              hint: '例如：产品研发部',
              icon: Icons.apartment_outlined,
            ),
            validator: (value) => _required(value, '所属部门'),
          ),
          if (_departments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                children: _departments
                    .take(6)
                    .map(
                      (name) => ActionChip(
                        label: Text(name),
                        onPressed: () {
                          _department.text = name;
                          _dirty = true;
                        },
                        backgroundColor: AppColors.background,
                        side: BorderSide.none,
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('job-city'),
            controller: _city,
            maxLength: 50,
            textInputAction: TextInputAction.next,
            decoration: _decoration(
              '工作城市 *',
              hint: '例如：上海',
              icon: Icons.location_on_outlined,
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
            color: AppColors.interactive,
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
      '发布后将按以下条目展示',
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
                  backgroundColor: AppColors.interactiveSoft,
                  side: BorderSide.none,
                ),
              )
              .toList(),
        ),
      ]),
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
        for (var index = 0; index < _skills.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              key: ValueKey('job-skill-$index'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _skills[index].name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _skills[index].requirementLabel,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '编辑技能',
                  onPressed: () => _editSkill(index),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
                IconButton(
                  tooltip: '移除技能',
                  onPressed: () => setState(() {
                    _skills.removeAt(index);
                    _dirty = true;
                  }),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('job-add-skill'),
            onPressed: _skills.length >= 30 ? null : () => _editSkill(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加技能'),
          ),
        ),
      ]);

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
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.hairline)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          children: [
            if (_preview && !_needsListCheck) ...[
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('返回修改'),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
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
                      ? '正在发布…'
                      : _preview
                      ? '确认发布'
                      : '预览岗位',
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
    title: Text(widget.skill == null ? '添加技能' : '编辑技能'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('job-skill-name'),
                controller: _name,
                maxLength: 50,
                decoration: const InputDecoration(labelText: '技能名称'),
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
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: const Key('job-skill-required'),
                initialValue: _requiredFlag ?? -1,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '技能要求'),
                items: const [
                  DropdownMenuItem(value: -1, child: Text('未注明')),
                  DropdownMenuItem(value: 1, child: Text('必备')),
                  DropdownMenuItem(value: 0, child: Text('加分')),
                ],
                onChanged: (value) =>
                    setState(() => _requiredFlag = value == -1 ? null : value),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      TextButton(
        key: const Key('job-skill-save'),
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
}
