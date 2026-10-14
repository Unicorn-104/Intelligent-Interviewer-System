import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../features/auth/domain/auth_session.dart';
import '../features/profile/data/profile_api.dart';
import '../features/profile/domain/user_profile.dart';
import '../features/resume/data/resume_api.dart';
import '../features/resume/domain/app_resume.dart';
import '../theme/app_theme.dart';

class ResumeScreen extends StatefulWidget {
  const ResumeScreen({super.key, required this.session});
  final AuthSession session;

  @override
  State<ResumeScreen> createState() => _ResumeScreenState();
}

class _ResumeScreenState extends State<ResumeScreen> {
  late final ApiClient _client;
  late final ResumeApi _api;
  List<AppResume> _resumes = [];
  bool _loading = true;
  bool _parsing = false;
  String? _error;
  String? _importError;
  String? _pendingPdfPath;
  int? _pendingPdfSize;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _api = ResumeApi(_client);
    _load();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.list(widget.session.token);
      if (mounted) setState(() => _resumes = data);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadPdf() async {
    if (_parsing) return;
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (file == null || !mounted) return;
    final path = file.path;
    if (path == null) {
      _message('无法读取所选 PDF，请重新选择');
      return;
    }
    final length = file.lengthSync() ?? await file.length();
    if (length != null && length > 10 * 1024 * 1024) {
      _message('PDF 不能超过 10MB');
      return;
    }
    await _recognizePdf(path, length);
  }

  Future<void> _recognizePdf(String path, int? length) async {
    if (_parsing || !mounted) return;
    setState(() {
      _parsing = true;
      _importError = null;
      _pendingPdfPath = path;
      _pendingPdfSize = length;
    });
    try {
      final draft = await _api.parsePdf(widget.session.token, path);
      if (!mounted) return;
      draft.localPdfPath = path;
      draft.fileName = path.replaceAll('\\', '/').split('/').last;
      draft.fileSize = length;
      _message('简历已导入，请核对后保存');
      await _openEditor(draft);
      await FilePicker.clearTemporaryFiles();
      if (mounted) {
        setState(() {
          _pendingPdfPath = null;
          _pendingPdfSize = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _importError = error.message);
        _message(error.message);
      }
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  Future<void> _edit(AppResume summary) async {
    try {
      final detail = await _api.detail(widget.session.token, summary.resumeId!);
      if (mounted) await _openEditor(detail);
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    }
  }

  Future<void> _openEditor(AppResume resume) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ResumeEditorScreen(session: widget.session, resume: resume),
      ),
    );
    if (saved == true) await _load();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            Text('我的简历', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '选择一种方式创建，保存后可用于岗位投递',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _CreateCard(
                    icon: Icons.document_scanner_outlined,
                    title: _parsing ? '正在导入…' : '上传 PDF 简历',
                    subtitle: '导入已有简历，核对后保存',
                    onTap: _parsing ? null : _uploadPdf,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CreateCard(
                    icon: Icons.edit_note_outlined,
                    title: '直接输入',
                    subtitle: '自行填写简历内容',
                    onTap: () => _openEditor(AppResume(resumeName: '我的简历')),
                  ),
                ),
              ],
            ),
            if (_importError != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_importError!),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _parsing || _pendingPdfPath == null
                            ? null
                            : () => _recognizePdf(
                                _pendingPdfPath!,
                                _pendingPdfSize,
                              ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试导入'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '全部简历',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${_resumes.length} 份',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _EmptyState(
                icon: Icons.error_outline,
                text: _error!,
                action: '重新加载',
                onTap: _load,
              )
            else if (_resumes.isEmpty)
              const _EmptyState(
                icon: Icons.description_outlined,
                text: '还没有简历，请从上方选择创建方式',
              )
            else
              ..._resumes.map(
                (resume) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ResumeCard(
                    resume: resume,
                    onEdit: () => _edit(resume),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateCard extends StatelessWidget {
  const _CreateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.canvas,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: AppColors.hairline),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.interactive),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.resume, required this.onEdit});
  final AppResume resume;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  resume.resumeName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (resume.isDefault) const _Badge(text: '默认'),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            resume.jobDirection.isEmpty ? '求职方向待完善' : resume.jobDirection,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (resume.pdfUrl != null) ...[
            const SizedBox(height: 6),
            Text(
              '原始 PDF：${resume.fileName ?? '已保存'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: resume.completeness / 100,
                    minHeight: 6,
                    backgroundColor: AppColors.hairline,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${resume.completeness}%',
                style: const TextStyle(
                  color: AppColors.interactive,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('编辑简历'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class ResumeEditorScreen extends StatefulWidget {
  const ResumeEditorScreen({
    super.key,
    required this.session,
    required this.resume,
  });
  final AuthSession session;
  final AppResume resume;
  @override
  State<ResumeEditorScreen> createState() => _ResumeEditorScreenState();
}

class _ResumeEditorScreenState extends State<ResumeEditorScreen> {
  late final ApiClient _client;
  late final ResumeApi _api;
  late final TextEditingController _name;
  late final TextEditingController _direction;
  late AppResume _resume;
  UserProfile? _profile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _resume = widget.resume;
    _client = ApiClient();
    _api = ResumeApi(_client);
    _name = TextEditingController(text: _resume.resumeName);
    _direction = TextEditingController(text: _resume.jobDirection);
    ProfileApi(_client)
        .fetchProfile(widget.session.token)
        .then((value) {
          if (mounted) setState(() => _profile = value);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _name.dispose();
    _direction.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    _resume.resumeName = _name.text.trim();
    _resume.jobDirection = _direction.text.trim();
    if (_resume.resumeName.isEmpty) {
      _message('请填写简历名称');
      return;
    }
    if (_resume.educations.any((item) => item.school.trim().isEmpty) ||
        _resume.works.any(
          (item) => item.company.trim().isEmpty || item.position.trim().isEmpty,
        ) ||
        _resume.projects.any((item) => item.name.trim().isEmpty) ||
        _resume.skills.any((item) => item.name.trim().isEmpty)) {
      _message('请补全教育、工作、项目或技能中的必填信息');
      return;
    }
    setState(() => _saving = true);
    try {
      _resume = await _api.save(widget.session.token, _resume);
      if (!mounted) return;
      _message('简历已保存');
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑简历'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          _TopCard(nameController: _name, resume: _resume),
          if (_resume.structureMethod != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: const Text('简历内容已导入，请核对后保存。'),
              ),
            ),
          ],
          if (_resume.parseWarnings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '部分内容需要核对，请参考原文件确认。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (_resume.unmappedText?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Card(
              child: ExpansionTile(
                title: const Text('其他简历内容'),
                subtitle: const Text('请查看这些内容是否需要补充到简历中'),
                childrenPadding: const EdgeInsets.all(14),
                children: [SelectableText(_resume.unmappedText!)],
              ),
            ),
          ],
          if (_resume.fileName != null) ...[
            const SizedBox(height: 18),
            const _SectionLabel('简历文件'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text(_resume.fileName!),
                subtitle: Text(
                  _resume.localPdfPath != null ? '保存简历时将保留此文件' : '已保留上传的简历文件',
                ),
              ),
            ),
          ],
          if (_resume.extractedText?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Card(
              child: ExpansionTile(
                title: const Text('原文件内容'),
                subtitle: const Text('可对照原文件检查简历内容'),
                childrenPadding: const EdgeInsets.all(14),
                children: [SelectableText(_resume.extractedText!)],
              ),
            ),
          ],
          const SizedBox(height: 18),
          const _SectionLabel('基本信息'),
          _InfoCard(
            rows: [
              (
                '姓名',
                _profile?.realName ??
                    _profile?.nickName ??
                    widget.session.nickName,
              ),
              (
                '性别',
                switch (_profile?.sex) {
                  '0' => '男',
                  '1' => '女',
                  _ => '未填写',
                },
              ),
              ('当前状态', _profile?.statusLabel ?? '加载中'),
              ('所在城市', _profile?.currentCity ?? '未填写'),
              (
                '手机号',
                _maskPhone(_profile?.phoneNumber ?? widget.session.phoneNumber),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionLabel('求职意向'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _direction,
                decoration: const InputDecoration(
                  labelText: '期望职位',
                  hintText: '例如：AI 产品经理',
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _EditableSection<ResumeEducation>(
            title: '教育经历',
            items: _resume.educations,
            titleOf: (item) => item.school.isEmpty ? '待完善教育经历' : item.school,
            subtitleOf: (item) => [
              item.major,
              _degreeLabel(item.degree),
            ].where((value) => value.isNotEmpty).join(' · '),
            onAdd: () async {
              final item = await _editEducation(context, ResumeEducation());
              if (item != null) setState(() => _resume.educations.add(item));
            },
            onEdit: (index) async {
              final item = await _editEducation(
                context,
                _resume.educations[index],
              );
              if (item != null) {
                setState(() => _resume.educations[index] = item);
              }
            },
            onDelete: (index) =>
                setState(() => _resume.educations.removeAt(index)),
          ),
          const SizedBox(height: 18),
          _EditableSection<ResumeWork>(
            title: '工作经历',
            items: _resume.works,
            titleOf: (item) =>
                item.position.isEmpty ? '待完善工作经历' : item.position,
            subtitleOf: (item) => item.company,
            onAdd: () async {
              final item = await _editWork(context, ResumeWork());
              if (item != null) setState(() => _resume.works.add(item));
            },
            onEdit: (index) async {
              final item = await _editWork(context, _resume.works[index]);
              if (item != null) setState(() => _resume.works[index] = item);
            },
            onDelete: (index) => setState(() => _resume.works.removeAt(index)),
          ),
          const SizedBox(height: 18),
          _EditableSection<ResumeProject>(
            title: '项目经历',
            items: _resume.projects,
            titleOf: (item) => item.name.isEmpty ? '待完善项目经历' : item.name,
            subtitleOf: (item) => item.role,
            onAdd: () async {
              final item = await _editProject(context, ResumeProject());
              if (item != null) setState(() => _resume.projects.add(item));
            },
            onEdit: (index) async {
              final item = await _editProject(context, _resume.projects[index]);
              if (item != null) setState(() => _resume.projects[index] = item);
            },
            onDelete: (index) =>
                setState(() => _resume.projects.removeAt(index)),
          ),
          const SizedBox(height: 18),
          const _SectionLabel('技能标签'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._resume.skills.asMap().entries.map(
                    (entry) => InputChip(
                      label: Text(entry.value.name),
                      onDeleted: () =>
                          setState(() => _resume.skills.removeAt(entry.key)),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('添加'),
                    onPressed: _addSkill,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? '保存中…' : '保存修改'),
          ),
        ),
      ),
    );
  }

  Future<void> _addSkill() async {
    var skill = '';
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加技能'),
        content: TextField(
          autofocus: true,
          onChanged: (value) => skill = value,
          decoration: const InputDecoration(hintText: '例如：数据分析'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, skill.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (value != null && value.isNotEmpty) {
      setState(() => _resume.skills.add(ResumeSkill(name: value)));
    }
  }
}

class _TopCard extends StatelessWidget {
  const _TopCard({required this.nameController, required this.resume});
  final TextEditingController nameController;
  final AppResume resume;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          TextField(
            controller: nameController,
            style: const TextStyle(
              color: AppColors.brand,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(labelText: '简历名称'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: resume.completeness / 100,
                    minHeight: 6,
                    backgroundColor: AppColors.hairline,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${resume.completeness}%'),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});
  final List<(String, String)> rows;
  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: rows
          .asMap()
          .entries
          .map(
            (entry) => Column(
              children: [
                ListTile(
                  dense: true,
                  title: Text(entry.value.$1),
                  trailing: Text(
                    entry.value.$2,
                    style: const TextStyle(
                      color: AppColors.body,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (entry.key != rows.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ),
          )
          .toList(),
    ),
  );
}

class _EditableSection<T> extends StatelessWidget {
  const _EditableSection({
    required this.title,
    required this.items,
    required this.titleOf,
    required this.subtitleOf,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });
  final String title;
  final List<T> items;
  final String Function(T) titleOf;
  final String Function(T) subtitleOf;
  final VoidCallback onAdd;
  final void Function(int) onEdit;
  final void Function(int) onDelete;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: _SectionLabel(title)),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 17),
            label: const Text('添加'),
          ),
        ],
      ),
      Card(
        child: items.isEmpty
            ? InkWell(
                onTap: onAdd,
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      '点击添加',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                ),
              )
            : Column(
                children: items
                    .asMap()
                    .entries
                    .map(
                      (entry) => Column(
                        children: [
                          ListTile(
                            title: Text(titleOf(entry.value)),
                            subtitle: Text(subtitleOf(entry.value)),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) => value == 'edit'
                                  ? onEdit(entry.key)
                                  : onDelete(entry.key),
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('编辑')),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('删除'),
                                ),
                              ],
                            ),
                          ),
                          if (entry.key != items.length - 1)
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ),
                    )
                    .toList(),
              ),
      ),
    ],
  );
}

Future<ResumeEducation?> _editEducation(
  BuildContext context,
  ResumeEducation source,
) {
  var school = source.school;
  var major = source.major;
  int? degree = source.degree;
  return showDialog<ResumeEducation>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('教育经历'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: school,
                onChanged: (value) => school = value,
                decoration: const InputDecoration(labelText: '学校 *'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: major,
                onChanged: (value) => major = value,
                decoration: const InputDecoration(labelText: '专业'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: degree,
                decoration: const InputDecoration(labelText: '学历'),
                items: [1, 2, 3, 4, 5]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_degreeLabel(value)),
                      ),
                    )
                    .toList(),
                hint: const Text('学历待确认'),
                onChanged: (value) => setDialogState(() => degree = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (school.trim().isEmpty) return;
              Navigator.pop(
                context,
                ResumeEducation(
                  school: school.trim(),
                  major: major.trim(),
                  degree: degree,
                  startDate: source.startDate,
                  endDate: source.endDate,
                  gpa: source.gpa,
                  description: source.description,
                ),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    ),
  );
}

Future<ResumeWork?> _editWork(BuildContext context, ResumeWork source) {
  var company = source.company;
  var position = source.position;
  var description = source.description;
  return showDialog<ResumeWork>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('工作经历'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: company,
              onChanged: (value) => company = value,
              decoration: const InputDecoration(labelText: '公司 *'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: position,
              onChanged: (value) => position = value,
              decoration: const InputDecoration(labelText: '职位 *'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: description,
              onChanged: (value) => description = value,
              maxLines: 4,
              decoration: const InputDecoration(labelText: '工作内容与业绩'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (company.trim().isEmpty || position.trim().isEmpty) return;
            Navigator.pop(
              context,
              ResumeWork(
                company: company.trim(),
                position: position.trim(),
                description: description.trim(),
                department: source.department,
                startDate: source.startDate,
                endDate: source.endDate,
                current: source.current,
                salaryRange: source.salaryRange,
              ),
            );
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

Future<ResumeProject?> _editProject(
  BuildContext context,
  ResumeProject source,
) {
  var name = source.name;
  var role = source.role;
  var description = source.description;
  var tech = source.techStack;
  return showDialog<ResumeProject>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('项目经历'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: name,
              onChanged: (value) => name = value,
              decoration: const InputDecoration(labelText: '项目名称 *'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: role,
              onChanged: (value) => role = value,
              decoration: const InputDecoration(labelText: '担任角色'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: description,
              onChanged: (value) => description = value,
              maxLines: 4,
              decoration: const InputDecoration(labelText: '项目描述'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: tech,
              onChanged: (value) => tech = value,
              decoration: const InputDecoration(labelText: '技术栈'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (name.trim().isEmpty) return;
            Navigator.pop(
              context,
              ResumeProject(
                name: name.trim(),
                role: role.trim(),
                description: description.trim(),
                techStack: tech.trim(),
                startDate: source.startDate,
                endDate: source.endDate,
              ),
            );
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.interactive, fontSize: 11),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.text,
    this.action,
    this.onTap,
  });
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Column(
      children: [
        Icon(icon, size: 42, color: AppColors.muted),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ],
    ),
  );
}

String _degreeLabel(int? value) => switch (value) {
  1 => '中专',
  2 => '大专',
  3 => '本科',
  4 => '硕士',
  5 => '博士',
  _ => '学历待确认',
};
String _maskPhone(String? phone) {
  if (phone == null || phone.length < 7) return phone ?? '未填写';
  return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
}
