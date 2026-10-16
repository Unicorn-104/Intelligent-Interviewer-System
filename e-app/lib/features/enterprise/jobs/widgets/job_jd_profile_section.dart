import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/page_states.dart';
import '../../../../widgets/skeleton_list.dart';
import '../models/job_detail_view_data.dart';

class JobJdProfileSection extends StatefulWidget {
  const JobJdProfileSection({
    super.key,
    required this.positionId,
    required this.state,
    required this.expanded,
    required this.onExpanded,
    required this.parsing,
    required this.onReload,
    required this.onParse,
  });
  final int positionId;
  final JobSectionState<Map<String, dynamic>> state;
  final bool expanded;
  final ValueChanged<bool> onExpanded;
  final bool parsing;
  final VoidCallback onReload;
  final Future<bool> Function(String) onParse;

  @override
  State<JobJdProfileSection> createState() => _JobJdProfileSectionState();
}

class _JobJdProfileSectionState extends State<JobJdProfileSection> {
  bool _editing = false;

  Future<void> _editAndParse() async {
    if (_editing || widget.parsing) {
      return;
    }
    setState(() => _editing = true);
    final form = GlobalKey<FormState>();
    var input = '';
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '解析 JD 生成画像',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text('粘贴 JD 文本后由你确认解析，结果将更新当前岗位画像。AI 结果仅供参考。'),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('job-jd-text'),
                    minLines: 3,
                    maxLines: 6,
                    onChanged: (value) => input = value,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '请输入 JD 文本'
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'JD 文本',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('job-jd-parse-confirm'),
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(context, input.trim());
                      }
                    },
                    child: const Text('开始解析'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _editing = false);
    if (text != null) {
      await widget.onParse(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.state.data?['jdProfile'];
    final hasProfile = profile is Map && profile.isNotEmpty;
    final legacy =
        hasProfile &&
        !const [
          'summary',
          'education',
          'years',
          'skills',
        ].any(profile.containsKey);
    final subtitle = widget.state.loading
        ? '加载中'
        : widget.state.error != null
        ? '加载失败，展开重试'
        : hasProfile
        ? '已有JD内容，点击展开'
        : '尚未生成，展开后可解析';
    return ExpansionTile(
      key: PageStorageKey('job-jd-expansion-${widget.positionId}'),
      title: const Text('JD画像'),
      subtitle: Text(subtitle),
      initiallyExpanded: widget.expanded,
      onExpansionChanged: widget.onExpanded,
      maintainState: true,
      leading: const Icon(
        Icons.auto_awesome_outlined,
        color: AppColors.accentPurple,
      ),
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
        Padding(padding: const EdgeInsets.all(12), child: _buildJdSection()),
        if (legacy && !widget.state.loading && widget.state.error == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton(
              onPressed: _editing || widget.parsing ? null : _editAndParse,
              child: Text(widget.parsing ? '解析中…' : '重新解析JD'),
            ),
          ),
      ],
    );
  }

  /// 画像区：加载中（骨架屏）/ 失败（可重试）/ 未生成（可解析）/ 已生成。
  Widget _buildJdSection() {
    if (widget.state.loading) {
      return const SkeletonList(rows: 1);
    }
    if (widget.state.error != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '加载失败',
        message: widget.state.error!,
        actionLabel: '重试',
        onAction: widget.onReload,
      );
    }
    final result = widget.state.data ?? const <String, dynamic>{};
    if (result.isEmpty) {
      return const PageMessage(
        icon: Icons.work_off_outlined,
        title: '暂无岗位画像数据',
        message: '接口未返回岗位信息，请稍后刷新',
      );
    }
    final profile = result['jdProfile'];
    if (profile is! Map || profile.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('尚未生成岗位画像', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text(
                '粘贴 JD 文本后，系统将解析学历、年限、技能标签等硬性指标与软性要求，生成结构化岗位画像',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: widget.parsing || _editing ? null : _editAndParse,
                icon: const Icon(Icons.auto_awesome),
                label: Text(widget.parsing ? '解析中…' : '解析 JD 生成画像'),
              ),
            ],
          ),
        ),
      );
    }
    // 旧数据只有 requirements / responsibilities，不应落入新画像的空字段布局。
    const newFields = ['summary', 'education', 'years', 'skills'];
    final hasNewStructure = newFields.any(profile.containsKey);
    if (!hasNewStructure &&
        (profile.containsKey('requirements') ||
            profile.containsKey('responsibilities'))) {
      return _buildLegacyProfileCard(result, profile);
    }
    return _buildProfileCard(result, profile);
  }

  /// 历史岗位的 JD JSON 没有新画像字段，直接展示已存储的两个条目列表。
  Widget _buildLegacyProfileCard(Map<String, dynamic> result, Map profile) {
    final skillNames =
        (result['skills'] as List?)
            ?.whereType<Map>()
            .map((skill) => skill['name'])
            .whereType<String>()
            .where((name) => name.trim().isNotEmpty)
            .toSet()
            .toList() ??
        const <String>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._buildLegacyItems('岗位要求', profile['requirements']),
            const SizedBox(height: 16),
            ..._buildLegacyItems('工作职责', profile['responsibilities']),
            if (skillNames.isNotEmpty) ...[
              const SizedBox(height: 16),
              _GroupLabel('技能标签'),
              _ProfileRow(field: '岗位技能', value: skillNames.join('、')),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLegacyItems(String title, Object? rawItems) {
    final items = rawItems is List
        ? rawItems
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList()
        : const <String>[];
    return [
      _GroupLabel(title),
      const SizedBox(height: 8),
      if (items.isEmpty)
        Text('暂无$title', style: Theme.of(context).textTheme.bodySmall)
      else
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: Theme.of(context).textTheme.bodyMedium),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
    ];
  }

  /// 已生成画像：按后端扁平结构渲染
  /// （summary/education/years/softRequirements/skills/parsedAt，
  ///  必备/加分技能来自外层 skills：t_pos_skill 真实数据）。
  Widget _buildProfileCard(Map<String, dynamic> result, Map profile) {
    final skills =
        (profile['skills'] as List?)
            ?.whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .toList() ??
        const <String>[];
    final softRequirements = (profile['softRequirements'] as List?) ?? const [];
    final positionSkills =
        (result['skills'] as List?)
            ?.whereType<Map>()
            .where(
              (s) =>
                  s['name'] is String &&
                  (s['name'] as String).trim().isNotEmpty,
            )
            .toList() ??
        const <Map>[];
    final requiredSkills = positionSkills
        .where((s) => int.tryParse('${s['required']}') == 1)
        .map((s) => '${s['name']}')
        .toList();
    final bonusSkills = positionSkills
        .where((s) => int.tryParse('${s['required']}') == 0)
        .map((s) => '${s['name']}')
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${profile['summary'] ?? ''}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _GroupLabel('硬性指标'),
            _ProfileRow(field: '学历', value: '${profile['education'] ?? '不限'}'),
            _ProfileRow(field: '工作年限', value: '${profile['years'] ?? '不限'}'),
            _ProfileRow(
              field: '必备技能',
              value: requiredSkills.isNotEmpty
                  ? requiredSkills.join('、')
                  : skills.isNotEmpty
                  ? skills.join('、')
                  : '未设置',
            ),
            if (bonusSkills.isNotEmpty)
              _ProfileRow(field: '加分技能', value: bonusSkills.join('、')),
            const SizedBox(height: 12),
            _GroupLabel('软性要求'),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                softRequirements.isEmpty
                    ? '未设置'
                    : softRequirements.map((s) => '$s').join('；'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (skills.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: skills
                    .map(
                      (s) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.interactive,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              '解析时间：${profile['parsedAt'] ?? '-'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: widget.parsing || _editing ? null : _editAndParse,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重新解析'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(color: AppColors.brand, fontSize: 14),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.field, required this.value});

  final String field;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(field, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
