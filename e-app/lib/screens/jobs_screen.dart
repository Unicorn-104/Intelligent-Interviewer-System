import 'package:flutter/material.dart';

import '../features/enterprise/enterprise_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/page_states.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key, required this.repository});
  final EnterpriseRepository repository;

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>>? _jobs;
  String? _error;
  int? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final rows = await widget.repository.jobs(keyword: _search.text.trim(), status: _status);
      if (mounted) setState(() => _jobs = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _changeStatus(Map<String, dynamic> job, int status) async {
    try {
      await widget.repository.changeJobStatus(job['posId'] ?? job['positionId'], status);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openCreate() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CreateJobSheet(repository: widget.repository),
    );
    if (created == true) await _load();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: Text('岗位管理', style: Theme.of(context).textTheme.titleLarge)),
                  FilledButton.icon(onPressed: _openCreate, icon: const Icon(Icons.add), label: const Text('发布岗位')),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(hintText: '搜索岗位或部门', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.arrow_forward))),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _filterChip('全部', null),
                    _filterChip('在招', 1),
                    _filterChip('暂停', 2),
                    _filterChip('已下线', 0),
                  ]),
                ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      );

  Widget _filterChip(String label, int? value) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _status == value,
          onSelected: (_) {
            setState(() => _status = value);
            _load();
          },
        ),
      );

  Widget _body() {
    if (_jobs == null && _error == null) return const PageLoading();
    if (_error != null) return PageMessage(icon: Icons.cloud_off_outlined, title: '岗位加载失败', message: _error!, onAction: _load);
    if (_jobs!.isEmpty) return PageMessage(icon: Icons.work_off_outlined, title: '暂无岗位', message: '调整筛选条件，或发布第一个岗位', actionLabel: '发布岗位', onAction: _openCreate);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: _jobs!.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final job = _jobs![index];
          final status = int.tryParse('${job['status']}') ?? 0;
          final statusText = switch (status) { 1 => '在招', 2 => '暂停', _ => '已下线' };
          final tone = switch (status) { 1 => AppColors.green, 2 => AppColors.orange, _ => AppColors.muted };
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${job['title'] ?? '未命名岗位'}', style: Theme.of(context).textTheme.titleMedium)),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: tone.withValues(alpha: .1), borderRadius: BorderRadius.circular(4)), child: Text(statusText, style: TextStyle(color: tone, fontSize: 12))),
                ]),
                const SizedBox(height: 8),
                Text('${job['dept'] ?? '未设置部门'} · ${job['city'] ?? '未设置城市'}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Text('${job['salaryMin'] ?? '-'}-${job['salaryMax'] ?? '-'} 元/月', style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w500)),
                const Divider(height: 24),
                Row(children: [
                  Text('${job['applicantCount'] ?? 0} 位候选人', style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  PopupMenuButton<int>(
                    onSelected: (value) => _changeStatus(job, value),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 1, child: Text('设为在招')),
                      PopupMenuItem(value: 2, child: Text('暂停招聘')),
                      PopupMenuItem(value: 0, child: Text('下线岗位')),
                    ],
                    child: const Row(children: [Text('更改状态', style: TextStyle(color: AppColors.interactive)), Icon(Icons.arrow_drop_down, color: AppColors.interactive)]),
                  ),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _CreateJobSheet extends StatefulWidget {
  const _CreateJobSheet({required this.repository});
  final EnterpriseRepository repository;

  @override
  State<_CreateJobSheet> createState() => _CreateJobSheetState();
}

class _CreateJobSheetState extends State<_CreateJobSheet> {
  final _key = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _dept = TextEditingController();
  final _city = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _experience = TextEditingController();
  final _description = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [_title, _dept, _city, _min, _max, _experience, _description]) { controller.dispose(); }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.createJob({
        'title': _title.text.trim(),
        'dept': _dept.text.trim(),
        'city': _city.text.trim(),
        'salaryMin': num.tryParse(_min.text),
        'salaryMax': num.tryParse(_max.text),
        'experience': _experience.text.trim(),
        'education': 3,
        'jobType': 1,
        'description': _description.text.trim(),
        'status': 1,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Form(
            key: _key,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('发布岗位', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              TextFormField(controller: _title, decoration: const InputDecoration(labelText: '岗位名称 *'), validator: (v) => v == null || v.trim().isEmpty ? '请输入岗位名称' : null),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: TextField(controller: _dept, decoration: const InputDecoration(labelText: '招聘部门'))), const SizedBox(width: 10), Expanded(child: TextField(controller: _city, decoration: const InputDecoration(labelText: '工作城市')))]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: TextField(controller: _min, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '最低月薪'))), const SizedBox(width: 10), Expanded(child: TextField(controller: _max, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '最高月薪')))]),
              const SizedBox(height: 12),
              TextField(controller: _experience, decoration: const InputDecoration(labelText: '经验要求')),
              const SizedBox(height: 12),
              TextField(controller: _description, minLines: 4, maxLines: 7, decoration: const InputDecoration(labelText: '岗位描述')),
              const SizedBox(height: 20),
              FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? '发布中…' : '确认发布')),
            ]),
          ),
        ),
      );
}
