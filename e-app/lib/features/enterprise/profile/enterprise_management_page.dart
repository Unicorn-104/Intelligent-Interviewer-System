import 'package:flutter/material.dart';

import '../../../api/enterprise_management_api.dart';
import '../../../api/notification_api.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';

enum EnterpriseManagementSection { departments, members, templates }

class EnterpriseManagementPage extends StatefulWidget {
  const EnterpriseManagementPage({super.key, required this.section});

  final EnterpriseManagementSection section;

  @override
  State<EnterpriseManagementPage> createState() =>
      _EnterpriseManagementPageState();
}

class _EnterpriseManagementPageState extends State<EnterpriseManagementPage> {
  static const _roles = <int, String>{101: '管理员', 102: 'HR', 103: '面试官'};
  static const _channels = <int, String>{1: '站内信', 2: '邮件', 3: '短信'};

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _departmentData = const {};
  List<Map<String, dynamic>> _members = const [];
  List<Map<String, dynamic>> _templates = const [];
  int? _busyUserId;
  int? _busyTemplateId;

  String get _title => switch (widget.section) {
    EnterpriseManagementSection.departments => '部门管理',
    EnterpriseManagementSection.members => '成员管理',
    EnterpriseManagementSection.templates => '通知模板',
  };

  IconData get _icon => switch (widget.section) {
    EnterpriseManagementSection.departments => Icons.apartment_outlined,
    EnterpriseManagementSection.members => Icons.people_outline,
    EnterpriseManagementSection.templates => Icons.notifications_outlined,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (widget.section) {
        case EnterpriseManagementSection.departments:
          _departmentData = await loadDepartmentOverview();
        case EnterpriseManagementSection.members:
          _members = await loadEnterpriseMembers();
        case EnterpriseManagementSection.templates:
          _templates = await listNotificationTemplates();
      }
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: Text(_title),
      backgroundColor: AppColors.canvas,
      actions: [
        if (!_loading && widget.section != EnterpriseManagementSection.members)
          IconButton(
            key: const Key('enterprise-management-add'),
            tooltip: widget.section == EnterpriseManagementSection.departments
                ? '新增部门'
                : '新增模板',
            onPressed: widget.section == EnterpriseManagementSection.departments
                ? () => _showDepartmentForm()
                : () => _showTemplateForm(),
            icon: const Icon(Icons.add, color: AppColors.interactive),
          ),
        if (!_loading && widget.section == EnterpriseManagementSection.members)
          IconButton(
            key: const Key('enterprise-management-invite'),
            tooltip: '邀请成员',
            onPressed: _showInviteForm,
            icon: const Icon(
              Icons.person_add_alt_1_outlined,
              color: AppColors.interactive,
            ),
          ),
        const SizedBox(width: 6),
      ],
    ),
    body: _body(),
  );

  Widget _body() {
    if (_loading) return const SkeletonList(rows: 4);
    if (_error != null) {
      return PageMessage(
        icon: _icon,
        title: '$_title加载失败',
        message: _error!,
        onAction: _load,
      );
    }
    return switch (widget.section) {
      EnterpriseManagementSection.departments => _departmentsBody(),
      EnterpriseManagementSection.members => _membersBody(),
      EnterpriseManagementSection.templates => _templatesBody(),
    };
  }

  Widget _scroll(List<Widget> children) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: children,
    ),
  );

  Widget _departmentsBody() {
    final depts = _maps(_departmentData['depts']);
    final rows = _flattenDepartments(depts);
    return _scroll([
      _summaryRow([
        _summaryValue('${_number(_departmentData['deptCount'])}', '部门总数'),
        _summaryValue('${_number(_departmentData['memberCount'])}', '在职成员'),
        _summaryValue('${_number(_departmentData['positionCount'])}', '在招岗位'),
      ]),
      const SizedBox(height: 14),
      if (rows.isEmpty)
        _emptyCard('暂无部门，请点击右上角新增部门')
      else
        for (final row in rows) _departmentCard(row, depts),
    ]);
  }

  Widget _departmentCard(
    ({Map<String, dynamic> dept, int depth}) row,
    List<Map<String, dynamic>> all,
  ) {
    final dept = row.dept;
    final id = _int(dept['id']);
    final status = _int(dept['status']) == 1;
    return Container(
      key: ValueKey('enterprise-department-$id'),
      margin: EdgeInsets.only(left: row.depth * 14.0, bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.apartment_outlined,
                  size: 20,
                  color: AppColors.interactive,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(dept['name'], fallback: '未命名部门'),
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '负责人：${_text(dept['leader'], fallback: '待指定')}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(status ? '启用' : '停用', status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metric('成员', _number(dept['members'])),
              const SizedBox(width: 22),
              _metric('在招岗位', _number(dept['jobs'])),
              const Spacer(),
              IconButton(
                key: ValueKey('enterprise-department-add-$id'),
                tooltip: '新增子部门',
                visualDensity: VisualDensity.compact,
                onPressed: id == null
                    ? null
                    : () => _showDepartmentForm(parentId: id),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                color: AppColors.interactive,
              ),
              IconButton(
                key: ValueKey('enterprise-department-edit-$id'),
                tooltip: '编辑部门',
                visualDensity: VisualDensity.compact,
                onPressed: () => _showDepartmentForm(dept: dept),
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppColors.interactive,
              ),
              IconButton(
                key: ValueKey('enterprise-department-delete-$id'),
                tooltip: '删除部门',
                visualDensity: VisualDensity.compact,
                onPressed: id == null ? null : () => _deleteDepartment(id),
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _membersBody() => _scroll([
    if (_members.isEmpty)
      _emptyCard('暂无企业成员，请点击右上角邀请成员')
    else
      for (final member in _members) _memberCard(member),
  ]);

  Widget _memberCard(Map<String, dynamic> member) {
    final userId = _int(member['userId']);
    final enabled = _int(member['enabled']) == 1 || member['enabled'] == true;
    final busy = userId != null && _busyUserId == userId;
    return Container(
      key: ValueKey('enterprise-member-$userId'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primarySoft,
            child: Text(
              _text(member['nickName'], fallback: '?').characters.first,
              style: const TextStyle(
                color: AppColors.interactive,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(member['nickName'], fallback: '未命名成员'),
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_text(member['userName'], fallback: '无账号')} · ${_text(member['dept'], fallback: '未分配')}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    key: ValueKey('enterprise-member-role-$userId'),
                    value: _roles.containsKey(_int(member['roleId']))
                        ? _int(member['roleId'])
                        : null,
                    isDense: true,
                    style: const TextStyle(
                      color: AppColors.interactive,
                      fontSize: 12,
                    ),
                    items: [
                      for (final entry in _roles.entries)
                        DropdownMenuItem<int>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: busy || userId == null
                        ? null
                        : (value) {
                            if (value != null) _changeRole(userId, value);
                          },
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Switch.adaptive(
                key: ValueKey('enterprise-member-status-$userId'),
                value: enabled,
                onChanged: busy || userId == null
                    ? null
                    : (value) => _changeStatus(userId, value),
                activeColor: AppColors.interactive,
              ),
              Text(
                busy
                    ? '保存中…'
                    : enabled
                    ? '正常'
                    : '已停用',
                style: TextStyle(
                  color: enabled ? AppColors.success : AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _templatesBody() => _scroll([
    if (_templates.isEmpty)
      _emptyCard('暂无通知模板，请点击右上角新增模板')
    else
      for (final template in _templates) _templateCard(template),
  ]);

  Widget _templateCard(Map<String, dynamic> template) {
    final id = _int(template['id']);
    final readonly =
        template['readonly'] == true || _int(template['readonly']) == 1;
    final enabled = _int(template['status']) == 1;
    final busy = id != null && _busyTemplateId == id;
    return Container(
      key: ValueKey('enterprise-template-$id'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                color: AppColors.interactive,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _text(template['title'], fallback: '未命名模板'),
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (readonly) _tag('平台'),
              const SizedBox(width: 6),
              _statusBadge(enabled ? '已启用' : '已停用', enabled),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _text(template['content'], fallback: '暂无正文'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '渠道：${_channels[_int(template['channel'])] ?? '站内信'}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              TextButton(
                key: ValueKey('enterprise-template-edit-$id'),
                onPressed: busy || id == null
                    ? null
                    : () => _showTemplateForm(template: template),
                child: const Text('编辑'),
              ),
              if (!readonly) ...[
                TextButton(
                  key: ValueKey('enterprise-template-toggle-$id'),
                  onPressed: busy || id == null
                      ? null
                      : () => _toggleTemplate(template),
                  child: Text(enabled ? '停用' : '启用'),
                ),
                TextButton(
                  key: ValueKey('enterprise-template-delete-$id'),
                  onPressed: busy || id == null
                      ? null
                      : () => _deleteTemplate(id),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('删除'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _changeRole(int userId, int roleId) async {
    setState(() => _busyUserId = userId);
    try {
      await updateMemberRole(userId, roleId);
      await _load();
      _message('成员角色已更新');
    } catch (error) {
      _message(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  Future<void> _changeStatus(int userId, bool enabled) async {
    setState(() => _busyUserId = userId);
    try {
      await updateMemberStatus(userId, enabled);
      await _load();
      _message(enabled ? '成员已启用' : '成员已停用');
    } catch (error) {
      _message(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  Future<void> _showInviteForm() async {
    final controllers = {
      'userName': TextEditingController(),
      'nickName': TextEditingController(),
      'email': TextEditingController(),
      'dept': TextEditingController(),
    };
    var roleId = 102;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('邀请成员'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(controllers['userName']!, '登录账号', '字母/数字，登录使用'),
                _dialogField(controllers['nickName']!, '姓名', '成员姓名'),
                _dialogField(controllers['email']!, '邮箱', '选填'),
                _dialogField(controllers['dept']!, '所属部门', '部门名称'),
                DropdownButtonFormField<int>(
                  value: roleId,
                  decoration: const InputDecoration(labelText: '角色'),
                  items: [
                    for (final entry in _roles.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => roleId = value ?? 102),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const Key('enterprise-member-invite-submit'),
              onPressed: () async {
                if (controllers['userName']!.text.trim().isEmpty ||
                    controllers['nickName']!.text.trim().isEmpty) {
                  _message('登录账号与姓名不能为空');
                  return;
                }
                try {
                  final result = await inviteEnterpriseMember({
                    'userName': controllers['userName']!.text.trim(),
                    'nickName': controllers['nickName']!.text.trim(),
                    'email': _nullable(controllers['email']!.text),
                    'dept': _nullable(controllers['dept']!.text),
                    'roleId': roleId,
                  });
                  if (!context.mounted) return;
                  Navigator.pop(dialogContext, true);
                  await _showInitialPassword(result['initPassword']);
                } catch (error) {
                  _message(_friendlyError(error));
                }
              },
              child: const Text('发送邀请'),
            ),
          ],
        ),
      ),
    );
    for (final controller in controllers.values) controller.dispose();
    if (result == true && mounted) await _load();
  }

  Future<void> _showInitialPassword(Object? value) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('邀请成功'),
        content: SelectableText(
          '初始密码：${_text(value, fallback: '后端未返回')}\n请通知成员登录后立即修改密码。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTemplateForm({Map<String, dynamic>? template}) async {
    final title = TextEditingController(
      text: _text(template?['title'], fallback: ''),
    );
    final content = TextEditingController(
      text: _text(template?['content'], fallback: ''),
    );
    var channel = _int(template?['channel']) ?? 1;
    final id = _int(template?['id']);
    final status = _int(template?['status']) ?? 1;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(template == null ? '新增模板' : '编辑模板'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(title, '模板标题', '如：面试提醒：\${position_name}'),
                _dialogField(
                  content,
                  '模板正文',
                  '支持 \${candidate_name} 等变量占位符',
                  maxLines: 5,
                ),
                DropdownButtonFormField<int>(
                  value: channel,
                  decoration: const InputDecoration(labelText: '发送渠道'),
                  items: [
                    for (final entry in _channels.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => channel = value ?? 1),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const Key('enterprise-template-save'),
              onPressed: () async {
                if (title.text.trim().isEmpty || content.text.trim().isEmpty) {
                  _message('模板标题与内容不能为空');
                  return;
                }
                try {
                  if (id == null) {
                    await addNotificationTemplate(
                      title: title.text.trim(),
                      content: content.text.trim(),
                      channel: channel,
                    );
                  } else {
                    await editNotificationTemplate(
                      id,
                      title: title.text.trim(),
                      content: content.text.trim(),
                      channel: channel,
                      status: status,
                    );
                  }
                  if (context.mounted) Navigator.pop(dialogContext, true);
                } catch (error) {
                  _message(_friendlyError(error));
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    content.dispose();
    if (result == true && mounted) {
      await _load();
      _message('模板已保存');
    }
  }

  Future<void> _toggleTemplate(Map<String, dynamic> template) async {
    final id = _int(template['id']);
    if (id == null) return;
    setState(() => _busyTemplateId = id);
    try {
      await editNotificationTemplate(
        id,
        title: _text(template['title'], fallback: ''),
        content: _text(template['content'], fallback: ''),
        channel: _int(template['channel']) ?? 1,
        status: _int(template['status']) == 1 ? 0 : 1,
      );
      await _load();
      _message('模板状态已更新');
    } catch (error) {
      _message(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busyTemplateId = null);
    }
  }

  Future<void> _deleteTemplate(int id) async {
    final confirmed = await _confirm('删除模板', '确认删除这个通知模板吗？删除后不可恢复。');
    if (confirmed != true) return;
    setState(() => _busyTemplateId = id);
    try {
      await removeNotificationTemplate(id);
      await _load();
      _message('模板已删除');
    } catch (error) {
      _message(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busyTemplateId = null);
    }
  }

  Future<void> _showDepartmentForm({
    Map<String, dynamic>? dept,
    int? parentId,
  }) async {
    final all = _maps(_departmentData['depts']);
    final id = _int(dept?['id']);
    final name = TextEditingController(
      text: _text(dept?['name'], fallback: ''),
    );
    final leader = TextEditingController(
      text: _text(dept?['leader'], fallback: ''),
    );
    var selectedParent = _int(dept?['parentId']) ?? parentId ?? 0;
    var orderNum = _int(dept?['orderNum']) ?? 0;
    var status = _int(dept?['status']) ?? 1;
    final options = [
      (id: 0, name: '顶级部门'),
      for (final item in _flattenDepartments(all))
        if (_int(item.dept['id']) != id)
          (
            id: _int(item.dept['id']) ?? 0,
            name:
                '${List.filled(item.depth, '　').join()}${_text(item.dept['name'])}',
          ),
    ];
    if (!options.any((item) => item.id == selectedParent)) selectedParent = 0;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(dept == null ? '新增部门' : '编辑部门'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(name, '部门名称', '请输入部门名称'),
                DropdownButtonFormField<int>(
                  value: selectedParent,
                  decoration: const InputDecoration(labelText: '上级部门'),
                  items: [
                    for (final option in options)
                      DropdownMenuItem(
                        value: option.id,
                        child: Text(option.name),
                      ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selectedParent = value ?? 0),
                ),
                _dialogField(leader, '负责人', '负责人姓名'),
                TextFormField(
                  initialValue: '$orderNum',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '显示顺序'),
                  onChanged: (value) => orderNum = int.tryParse(value) ?? 0,
                ),
                if (dept != null)
                  DropdownButtonFormField<int>(
                    value: status,
                    decoration: const InputDecoration(labelText: '状态'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('启用')),
                      DropdownMenuItem(value: 0, child: Text('停用')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => status = value ?? 1),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const Key('enterprise-department-save'),
              onPressed: () async {
                if (name.text.trim().isEmpty) {
                  _message('部门名称不能为空');
                  return;
                }
                try {
                  final body = <String, Object?>{
                    'parentId': selectedParent,
                    'name': name.text.trim(),
                    'leader': _nullable(leader.text),
                    'orderNum': orderNum,
                    if (dept != null) 'status': status,
                  };
                  if (id == null) {
                    await addDepartment(body);
                  } else {
                    await updateDepartment(id, body);
                  }
                  if (context.mounted) Navigator.pop(dialogContext, true);
                } catch (error) {
                  _message(_friendlyError(error));
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    leader.dispose();
    if (result == true && mounted) {
      await _load();
      _message('部门已保存');
    }
  }

  Future<void> _deleteDepartment(int id) async {
    final confirmed = await _confirm('删除部门', '确认删除这个部门吗？有下级部门或成员时无法删除。');
    if (confirmed != true) return;
    try {
      await removeDepartment(id);
      await _load();
      _message('部门已删除');
    } catch (error) {
      _message(_friendlyError(error));
    }
  }

  Future<bool?> _confirm(String title, String message) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('确认'),
        ),
      ],
    ),
  );

  Widget _summaryRow(List<Widget> items) => Row(
    children: [
      for (final (index, item) in items.indexed) ...[
        if (index > 0) const SizedBox(width: 8),
        Expanded(child: item),
      ],
    ],
  );

  Widget _summaryValue(String value, String label) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.brand,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _metric(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: AppColors.body,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(
        label,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
    ],
  );

  Widget _statusBadge(String label, bool enabled) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: enabled ? AppColors.primarySoft : AppColors.hairline,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: enabled ? AppColors.interactive : AppColors.textMuted,
        fontSize: 11,
      ),
    ),
  );

  Widget _tag(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: const TextStyle(color: AppColors.interactive, fontSize: 10),
    ),
  );

  Widget _emptyCard(String message) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.hairline),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.textMuted),
    ),
  );

  Widget _dialogField(
    TextEditingController controller,
    String label,
    String hint, {
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );

  List<({Map<String, dynamic> dept, int depth})> _flattenDepartments(
    List<Map<String, dynamic>> depts,
  ) {
    final result = <({Map<String, dynamic> dept, int depth})>[];
    final children = <int, List<Map<String, dynamic>>>{};
    for (final dept in depts) {
      children.putIfAbsent(_int(dept['parentId']) ?? 0, () => []).add(dept);
    }
    for (final list in children.values) {
      list.sort(
        (a, b) =>
            (_int(a['orderNum']) ?? 0).compareTo(_int(b['orderNum']) ?? 0),
      );
    }
    void walk(int parentId, int depth, Set<int> path) {
      for (final dept in children[parentId] ?? const <Map<String, dynamic>>[]) {
        final id = _int(dept['id']);
        if (id != null && path.contains(id)) continue;
        result.add((dept: dept, depth: depth));
        if (id != null) walk(id, depth + 1, {...path, id});
      }
    }

    walk(0, 0, <int>{});
    return result;
  }

  List<Map<String, dynamic>> _maps(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : const [];

  int? _int(Object? value) => int.tryParse('$value');

  String _number(Object? value) => _int(value)?.toString() ?? '0';

  String _text(Object? value, {String fallback = '未填写'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String? _nullable(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  String _friendlyError(Object error) =>
      error is ApiException ? error.message : '请求失败，请稍后重试';

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1500),
        content: Text(message),
      ),
    );
  }
}
