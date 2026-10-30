import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

/// 常用城市目录（仅用于选择展示，接口仍提交所选城市名称字符串）。
const jobHotCities = [
  '北京',
  '上海',
  '广州',
  '深圳',
  '杭州',
  '成都',
  '武汉',
  '西安',
  '南京',
  '重庆',
  '苏州',
  '天津',
];

const _jobAllCities = [
  '北京',
  '上海',
  '广州',
  '深圳',
  '杭州',
  '成都',
  '武汉',
  '西安',
  '南京',
  '重庆',
  '苏州',
  '天津',
  '长沙',
  '郑州',
  '青岛',
  '济南',
  '合肥',
  '福州',
  '厦门',
  '宁波',
  '无锡',
  '东莞',
  '佛山',
  '大连',
  '沈阳',
  '哈尔滨',
  '长春',
  '昆明',
  '贵阳',
  '南宁',
  '海口',
  '石家庄',
  '太原',
  '南昌',
  '兰州',
  '银川',
  '西宁',
  '乌鲁木齐',
  '呼和浩特',
  '拉萨',
];

/// 单选选择弹层公共骨架：标题 + 搜索框 + 可滚动内容 + 取消/确定。
class _JobSelectSheet extends StatefulWidget {
  const _JobSelectSheet({
    required this.title,
    required this.searchHint,
    required this.current,
    required this.optionKeyPrefix,
    required this.confirmKey,
    required this.cancelKey,
    required this.searchKey,
    required this.options,
    this.hotOptions = const [],
  });

  final String title;
  final String searchHint;
  final String current;
  final String optionKeyPrefix;
  final Key confirmKey;
  final Key cancelKey;
  final Key searchKey;
  final List<String> options;
  final List<String> hotOptions;

  @override
  State<_JobSelectSheet> createState() => _JobSelectSheetState();
}

class _JobSelectSheetState extends State<_JobSelectSheet> {
  late final TextEditingController _search = TextEditingController();
  late String _selected = widget.current;

  List<String> get _filtered {
    final query = _search.text.trim().toLowerCase();
    final source = widget.hotOptions.isNotEmpty
        ? [...widget.hotOptions, ...widget.options]
        : widget.options;
    final seen = <String>{};
    return [
      for (final name in source)
        if (seen.add(name) && (query.isEmpty || name.toLowerCase().contains(query)))
          name,
    ];
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final hot = [
      for (final name in filtered)
        if (widget.hotOptions.contains(name)) name,
    ];
    final all = [
      for (final name in filtered)
        if (!widget.hotOptions.contains(name)) name,
    ];
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.72,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: AppColors.brand,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              key: widget.searchKey,
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.fieldBackground,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      '暂无匹配选项',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    children: [
                      if (widget.hotOptions.isNotEmpty &&
                          _search.text.trim().isEmpty) ...[
                        if (hot.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              '热门城市',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [for (final city in hot) _optionChip(city)],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(height: 1, color: AppColors.hairline),
                          ),
                        ],
                        if (all.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              '全部城市',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          for (final name in all) _optionRow(name),
                        ],
                      ] else
                        for (final name in filtered) _optionRow(name),
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(
              color: AppColors.canvas,
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: widget.cancelKey,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        foregroundColor: AppColors.textSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: widget.confirmKey,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () =>
                          Navigator.pop(context, _selected.isEmpty ? null : _selected),
                      child: const Text('确定'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionChip(String name) {
    final selected = name == _selected;
    return InkWell(
      key: ValueKey('${widget.optionKeyPrefix}$name'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _selected = name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.tealSoft : AppColors.fieldBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.teal : Colors.transparent,
          ),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: selected ? AppColors.tealDeep : AppColors.textPrimary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _optionRow(String name) {
    final selected = name == _selected;
    return InkWell(
      key: ValueKey('${widget.optionKeyPrefix}$name'),
      onTap: () => setState(() => _selected = name),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.tealSoft.withValues(alpha: .55)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: selected ? AppColors.tealDeep : AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.teal, size: 20),
          ],
        ),
      ),
    );
  }
}

/// 选择所属部门：单选底部弹层，确定后返回所选部门名称。
Future<String?> showJobDepartmentSheet(
  BuildContext context, {
  required List<String> departments,
  required String current,
}) {
  final options = <String>[];
  if (current.isNotEmpty && !departments.contains(current)) {
    options.add(current);
  }
  options.addAll(departments);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _JobSelectSheet(
      title: '选择所属部门',
      searchHint: '搜索部门名称',
      current: current,
      optionKeyPrefix: 'job-dept-option-',
      confirmKey: const Key('job-dept-confirm'),
      cancelKey: const Key('job-dept-cancel'),
      searchKey: const Key('job-dept-search'),
      options: options,
    ),
  );
}

/// 选择工作城市：热门城市 + 全部城市，确定后返回所选城市名称。
Future<String?> showJobCitySheet(
  BuildContext context, {
  required String current,
}) {
  final options = <String>[
    if (current.isNotEmpty && !_jobAllCities.contains(current)) current,
    ..._jobAllCities,
  ];
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _JobSelectSheet(
      title: '选择工作城市',
      searchHint: '搜索城市',
      current: current,
      optionKeyPrefix: 'job-city-option-',
      confirmKey: const Key('job-city-confirm'),
      cancelKey: const Key('job-city-cancel'),
      searchKey: const Key('job-city-search'),
      options: options,
      hotOptions: jobHotCities,
    ),
  );
}
