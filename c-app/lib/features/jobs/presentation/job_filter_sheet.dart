import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/async_state_card.dart';
import '../domain/job_search.dart';
import '../domain/job_filter_catalog.dart';
import 'job_search_controller.dart';

enum JobFilterPanel { sort, city, category, experience, more }

const jobSortLabels = {'match': '匹配度优先', 'latest': '最新发布', 'salary': '薪资优先'};

class JobFilterSheet extends StatefulWidget {
  const JobFilterSheet({
    super.key,
    required this.controller,
    required this.panel,
  });
  final JobSearchController controller;
  final JobFilterPanel panel;

  @override
  State<JobFilterSheet> createState() => _JobFilterSheetState();
}

class _JobFilterSheetState extends State<JobFilterSheet> {
  late JobSearchQuery _draft = widget.controller.query;
  late String _positionGroup = widget.controller.query.category.isEmpty
      ? 'all'
      : 'published';
  String _positionSearch = '';
  String _industryGroup = pcJobIndustries.first.title;
  final _expandedRoles = <String>{};

  String get _title => switch (widget.panel) {
    JobFilterPanel.sort => '岗位排序',
    JobFilterPanel.city => '工作城市',
    JobFilterPanel.category => '职位类别',
    JobFilterPanel.experience => '工作经验',
    JobFilterPanel.more => '更多筛选',
  };

  void _reset() => setState(() {
    _draft = switch (widget.panel) {
      JobFilterPanel.sort => _draft.copyWith(sort: 'match'),
      JobFilterPanel.city => _draft.copyWith(city: ''),
      JobFilterPanel.category => _draft.copyWith(
        category: '',
        positionLabel: '',
        keyword: '',
      ),
      JobFilterPanel.experience => _draft.copyWith(experienceMin: ''),
      JobFilterPanel.more => JobSearchQuery(
        keyword: _draft.keyword,
        sort: _draft.sort,
      ),
    };
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .8,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: '取消筛选',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                if (widget.panel == JobFilterPanel.sort) {
                  return ListView(
                    children: [
                      for (final entry in jobSortLabels.entries)
                        ListTile(
                          title: Text(entry.value),
                          selected: _draft.sort == entry.key,
                          trailing: _draft.sort == entry.key
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => setState(
                            () => _draft = _draft.copyWith(sort: entry.key),
                          ),
                        ),
                    ],
                  );
                }
                final controller = widget.controller;
                final options = controller.options;
                return ListView(
                  children: [
                    if (controller.optionsLoading)
                      const LinearProgressIndicator(),
                    if (controller.optionsError != null) ...[
                      AsyncStateCard(
                        title: '部分筛选选项加载失败',
                        message: '可继续选择已有条件，或重新加载公司规模等选项。',
                        onRetry: controller.loadOptions,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (widget.panel == JobFilterPanel.city)
                      _group(
                        '工作城市',
                        {
                          ...pcJobCities.where((v) => v != '全国'),
                          ...?options?.cities,
                        }.toList(),
                        _draft.city,
                        (v) => _draft.copyWith(city: v == '全国' ? '' : v),
                      ),
                    if (widget.panel == JobFilterPanel.category)
                      _positionPicker(options?.categories ?? const []),
                    if (widget.panel == JobFilterPanel.experience)
                      _group(
                        '工作经验',
                        pcJobExperiences,
                        _draft.experienceMin,
                        (v) => _draft.copyWith(experienceMin: v),
                      ),
                    if (widget.panel == JobFilterPanel.more) ...[
                      ExpansionTile(
                        title: const Text('工作城市'),
                        childrenPadding: const EdgeInsets.only(
                          top: AppSpacing.lg,
                        ),
                        subtitle: Text(
                          _draft.city.isEmpty ? '不限' : _draft.city,
                        ),
                        children: [
                          _group(
                            '工作城市',
                            {
                              ...pcJobCities.where((v) => v != '全国'),
                              ...?options?.cities,
                            }.toList(),
                            _draft.city,
                            (v) => _draft.copyWith(city: v == '全国' ? '' : v),
                            showTitle: false,
                          ),
                        ],
                      ),
                      ExpansionTile(
                        title: const Text('职位类别'),
                        childrenPadding: const EdgeInsets.only(
                          top: AppSpacing.lg,
                        ),
                        subtitle: Text(
                          _draft.positionLabel.isEmpty
                              ? '不限'
                              : _draft.positionLabel,
                        ),
                        children: [
                          _positionPicker(options?.categories ?? const []),
                        ],
                      ),
                      ExpansionTile(
                        title: const Text('工作经验'),
                        childrenPadding: const EdgeInsets.only(
                          top: AppSpacing.lg,
                        ),
                        subtitle: Text(
                          _draft.experienceMin.isEmpty
                              ? '不限'
                              : _draft.experienceMin,
                        ),
                        children: [
                          _group(
                            '工作经验',
                            pcJobExperiences,
                            _draft.experienceMin,
                            (v) => _draft.copyWith(experienceMin: v),
                            showTitle: false,
                          ),
                        ],
                      ),
                      ExpansionTile(
                        title: const Text('所属行业'),
                        childrenPadding: const EdgeInsets.only(
                          top: AppSpacing.lg,
                        ),
                        subtitle: Text(
                          _draft.industry.isEmpty ? '不限' : _draft.industry,
                        ),
                        children: [
                          _industryPicker(options?.industries ?? const []),
                        ],
                      ),
                      ExpansionTile(
                        title: const Text('公司规模'),
                        childrenPadding: const EdgeInsets.only(
                          top: AppSpacing.lg,
                        ),
                        subtitle: Text(
                          _draft.companySize.isEmpty
                              ? '不限'
                              : _draft.companySize,
                        ),
                        children: [
                          _group(
                            '公司规模',
                            options?.companySizes ?? const [],
                            _draft.companySize,
                            (v) => _draft.copyWith(companySize: v),
                            showTitle: false,
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  child: const Text('重置'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _draft),
                  child: const Text('确定'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _positionPicker(List<String> published) {
    bool matches(String value) =>
        _positionSearch.isEmpty ||
        value.toLowerCase().contains(_positionSearch.toLowerCase());
    Widget roles(String key) => Column(
      children: [
        for (final section in pcJobRoles[key] ?? const <JobCatalogSection>[])
          if (section.items.any(matches))
            _group(
              section.title,
              section.items.where(matches).toList(),
              _draft.category.isEmpty ? _draft.positionLabel : '',
              (v) => _draft.copyWith(
                category: '',
                positionLabel: v,
                keyword: v.isEmpty ? _draft.keyword : v,
              ),
            ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: '查找职位',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => _positionSearch = value),
        ),
        const SizedBox(height: AppSpacing.xl),
        DropdownButtonFormField<String>(
          initialValue: _positionGroup,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '职位方向'),
          items: [
            for (final group in pcPositionGroups)
              DropdownMenuItem(
                value: group.$1,
                child: Text(group.$2, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _positionGroup = value);
          },
        ),
        TextButton(
          onPressed: () => setState(
            () => _draft = _draft.copyWith(
              keyword: '',
              category: '',
              positionLabel: '',
            ),
          ),
          child: const Text('不限职位'),
        ),
        if (_positionGroup == 'all' || _positionGroup == 'published')
          _group(
            '已发布岗位类别',
            published.where(matches).toList(),
            _draft.category,
            (v) => _draft.copyWith(category: v, positionLabel: v),
          ),
        if (_positionGroup == 'all')
          for (final group in pcPositionGroups.where(
            (g) => pcJobRoles.containsKey(g.$1),
          ))
            if ((pcJobRoles[group.$1] ?? []).any((s) => s.items.any(matches)))
              ExpansionTile(
                key: ValueKey('roles-${group.$1}'),
                title: Text(group.$2),
                onExpansionChanged: (expanded) => setState(() {
                  if (expanded) {
                    _expandedRoles.add(group.$1);
                  } else {
                    _expandedRoles.remove(group.$1);
                  }
                }),
                children: [
                  if (_expandedRoles.contains(group.$1)) roles(group.$1),
                ],
              ),
        if (_positionGroup != 'all' && _positionGroup != 'published')
          roles(_positionGroup),
      ],
    );
  }

  Widget _industryPicker(List<String> published) {
    final known = pcJobIndustries.expand((group) => group.items).toSet();
    final extra = published.where((value) => !known.contains(value)).toList();
    final groups = [
      if (extra.isNotEmpty) JobCatalogSection('已发布企业行业', extra),
      ...pcJobIndustries,
    ];
    final current = groups.firstWhere(
      (group) => group.title == _industryGroup,
      orElse: () => groups.first,
    );
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: current.title,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '行业分类'),
          items: [
            for (final group in groups)
              DropdownMenuItem(
                value: group.title,
                child: Text(group.title, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _industryGroup = value);
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        _group(
          current.title,
          current.items,
          _draft.industry,
          (v) => _draft.copyWith(industry: v),
        ),
      ],
    );
  }

  Widget _group(
    String title,
    List<String> options,
    String selected,
    JobSearchQuery Function(String) update, {
    bool showTitle = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (options.isEmpty && selected.isEmpty) ...[
          Text('暂无可选条件', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
        ],
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final value in {
                '',
                ...options,
                if (selected.isNotEmpty) selected,
              })
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth,
                    minHeight: AppSpacing.minTouch,
                  ),
                  child: ChoiceChip(
                    label: Text(
                      value.isEmpty ? '不限' : value,
                      overflow: TextOverflow.ellipsis,
                    ),
                    tooltip: value.isEmpty ? '不限' : value,
                    selected: selected == value,
                    onSelected: (checked) =>
                        setState(() => _draft = update(checked ? value : '')),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
