import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../theme/app_theme.dart';
import '../data/talent_pool_data_source.dart';
import '../models/talent_detail_view_data.dart';

class TalentFilterSheet extends StatefulWidget {
  const TalentFilterSheet({
    super.key,
    required this.initial,
    required this.loadOptions,
    this.discovery = false,
  });
  final bool discovery;
  final TalentPoolFilters initial;
  final Future<TalentPoolOptions> Function() loadOptions;
  @override
  State<TalentFilterSheet> createState() => _TalentFilterSheetState();
}

class _TalentFilterSheetState extends State<TalentFilterSheet> {
  late int? _status = widget.initial.status;
  late String? _direction = widget.initial.direction;
  late int? _education = widget.initial.minimumEducation;
  late String? _experience = widget.initial.experienceRange;
  late String _cityType = widget.initial.cityType;
  late final _city = TextEditingController(text: widget.initial.city ?? '');
  late int? _loginDays = widget.initial.loginWithinDays;
  TalentPoolOptions _options = const TalentPoolOptions();
  bool _loading = true;
  String? _error;
  int _category = 0;
  final _scroll = ScrollController();
  final _sectionKeys = List.generate(6, (_) => GlobalKey());
  bool _jumping = false;
  List<String> get _sections => [
    '求职方向',
    widget.discovery ? '求职状态' : '招聘状态',
    '学历要求',
    '工作经验',
    '城市',
    '活跃度',
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_syncCategory);
    _loadOptions();
  }

  @override
  void dispose() {
    _scroll.removeListener(_syncCategory);
    _scroll.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _jumpToSection(int index) async {
    final target = _sectionKeys[index].currentContext;
    if (target == null || !_scroll.hasClients) return;
    FocusScope.of(context).unfocus();
    setState(() => _category = index);
    _jumping = true;
    try {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        alignment: 0,
      );
    } finally {
      _jumping = false;
    }
  }

  void _syncCategory() {
    if (!mounted || _jumping || !_scroll.hasClients) return;
    var current = 0;
    for (var index = 0; index < _sectionKeys.length; index++) {
      final render = _sectionKeys[index].currentContext?.findRenderObject();
      if (render == null || !render.attached) continue;
      final viewport = RenderAbstractViewport.maybeOf(render);
      if (viewport == null) continue;
      final offset = viewport.getOffsetToReveal(render, 0).offset;
      if (offset <= _scroll.offset + 20) current = index;
    }
    if (_scroll.position.maxScrollExtent > 0 &&
        _scroll.offset >= _scroll.position.maxScrollExtent - 1) {
      current = _sectionKeys.length - 1;
    }
    if (_category != current) setState(() => _category = current);
  }

  Widget _section(int index, List<Widget> children) => Padding(
    key: _sectionKeys[index],
    padding: const EdgeInsets.only(bottom: 36),
    child: Column(
      key: ValueKey('talent-filter-section-$index'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: _sections[index],
            children: const [
              TextSpan(
                text: '（单选）',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );

  Future<void> _loadOptions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.loadOptions();
      if (mounted) setState(() => _options = data);
    } catch (_) {
      if (mounted) setState(() => _error = '筛选选项暂不可用，可重试或继续按状态筛选');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clear() => setState(() {
    _status = null;
    _direction = null;
    _education = null;
    _experience = null;
    _city.clear();
    _cityType = 'target';
    _loginDays = null;
  });

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  key: const Key('talent-filter-close'),
                  tooltip: '取消筛选',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
                const Expanded(
                  child: Text(
                    '筛选人才',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 88,
                  child: ColoredBox(
                    color: AppColors.background,
                    child: SingleChildScrollView(
                      key: const Key('talent-filter-sidebar'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (index, title) in _sections.indexed)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: _category == index
                                    ? AppColors.canvas
                                    : null,
                                border: Border(
                                  left: BorderSide(
                                    width: 3,
                                    color: _category == index
                                        ? AppColors.interactive
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                              child: TextButton(
                                key: ValueKey('talent-filter-category-$index'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 18,
                                  ),
                                  foregroundColor: _category == index
                                      ? AppColors.interactive
                                      : AppColors.textSecondary,
                                  shape: const RoundedRectangleBorder(),
                                ),
                                onPressed: () => _jumpToSection(index),
                                child: Semantics(
                                  selected: _category == index,
                                  child: Text(
                                    title,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('talent-filter-scroll'),
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _section(0, [
                          if (_loading) const Text('正在读取筛选选项…'),
                          if (_error != null) ...[
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            TextButton(
                              onPressed: _loadOptions,
                              child: const Text('重试读取筛选项'),
                            ),
                          ],
                          _optionGrid([
                            _option(
                              '不限',
                              _direction == null,
                              () => setState(() => _direction = null),
                              'direction-all',
                            ),
                            for (final direction in {
                              ..._options.directions,
                              ?_direction,
                            })
                              _option(
                                direction,
                                _direction == direction,
                                () => setState(() => _direction = direction),
                                'direction-$direction',
                              ),
                          ]),
                        ]),
                        _section(1, [
                          _optionGrid([
                            _option(
                              '全部',
                              _status == null,
                              () => setState(() => _status = null),
                              'status-all',
                            ),
                            for (final status
                                in widget.discovery
                                    ? TalentPoolFilters.seekingStatusLabels.keys
                                    : List.generate(10, (i) => i))
                              _option(
                                widget.discovery
                                    ? TalentPoolFilters
                                          .seekingStatusLabels[status]!
                                    : talentStatus(status),
                                _status == status,
                                () => setState(() => _status = status),
                                'status-$status',
                              ),
                          ]),
                        ]),
                        _section(2, [
                          _optionGrid([
                            _option(
                              '不限',
                              _education == null,
                              () => setState(() => _education = null),
                              'education-all',
                            ),
                            for (final entry
                                in TalentPoolFilters.educationLabels.entries)
                              _option(
                                entry.value,
                                _education == entry.key,
                                () => setState(() => _education = entry.key),
                                'education-${entry.key}',
                              ),
                          ]),
                          const SizedBox(height: 8),
                          const Text(
                            '按简历最高学历筛选，未填写学历不匹配指定条件。',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ]),
                        _section(3, [
                          _optionGrid([
                            _option(
                              '不限',
                              _experience == null,
                              () => setState(() => _experience = null),
                              'experience-all',
                            ),
                            for (final entry
                                in TalentPoolFilters.experienceLabels.entries)
                              _option(
                                entry.value,
                                _experience == entry.key,
                                () => setState(() => _experience = entry.key),
                                'experience-${entry.key}',
                              ),
                          ]),
                          const SizedBox(height: 8),
                          const Text(
                            '按有效工作经历合并计算，重叠月份不重复；资料缺失不作为零经验。',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ]),
                        _section(4, [
                          _optionGrid([
                            _option(
                              '期望城市',
                              _cityType == 'target',
                              () => setState(() {
                                _cityType = 'target';
                                _city.clear();
                              }),
                              'city-type-target',
                            ),
                            _option(
                              '所在城市',
                              _cityType == 'current',
                              () => setState(() {
                                _cityType = 'current';
                                _city.clear();
                              }),
                              'city-type-current',
                            ),
                          ]),
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('talent-filter-city'),
                            controller: _city,
                            onChanged: (_) => setState(() {}),
                            maxLength: 50,
                            decoration: const InputDecoration(
                              labelText: '城市名称',
                              helperText: '完整城市名称精确匹配，不填表示不限',
                              helperMaxLines: 3,
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 8),
                          _optionGrid([
                            for (final city
                                in (_cityType == 'target'
                                    ? _options.targetCities
                                    : _options.currentCities))
                              _option(
                                city,
                                _city.text == city,
                                () => setState(() => _city.text = city),
                                'city-option-$city',
                              ),
                          ]),
                        ]),
                        _section(5, [
                          _optionGrid([
                            _option(
                              '不限',
                              _loginDays == null,
                              () => setState(() => _loginDays = null),
                              'login-all',
                            ),
                            for (final days in [1, 3, 7, 14, 30, 90])
                              _option(
                                '近$days天',
                                _loginDays == days,
                                () => setState(() => _loginDays = days),
                                'login-$days',
                              ),
                          ]),
                          const SizedBox(height: 8),
                          const Text(
                            '按最近登录时间筛选，不代表实时在线或回复意愿。未记录登录时间的人才不匹配指定范围。',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 24),
                        Text(
                          widget.discovery
                              ? '筛选全站已注册求职者，不按企业投递记录限制'
                              : '仅筛选当前企业人才库中的人才',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('talent-filter-clear'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.background,
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _clear,
                    child: const Text('清除'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: const Key('talent-filter-apply'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(
                      context,
                      TalentPoolFilters(
                        status: _status,
                        direction: _direction,
                        minimumEducation: _education,
                        experienceRange: _experience,
                        city: _city.text.trim().isEmpty
                            ? null
                            : _city.text.trim(),
                        cityType: _cityType,
                        loginWithinDays: _loginDays,
                      ),
                    ),
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _optionGrid(List<Widget> children) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
      final columns =
          constraints.maxWidth < 180 ||
              (largeText && constraints.maxWidth < 300)
          ? 1
          : 2;
      final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 10,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );

  Widget _option(
    String title,
    bool selected,
    VoidCallback onTap,
    String name,
  ) => OutlinedButton(
    key: ValueKey('talent-filter-$name'),
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      foregroundColor: selected
          ? AppColors.interactive
          : AppColors.textSecondary,
      backgroundColor: selected ? AppColors.canvas : AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(
        color: selected ? AppColors.interactive : Colors.transparent,
      ),
    ),
    child: Semantics(
      selected: selected,
      child: Text(title, textAlign: TextAlign.center),
    ),
  );
}
