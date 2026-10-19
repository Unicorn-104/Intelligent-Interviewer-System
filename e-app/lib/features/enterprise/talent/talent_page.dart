import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import 'data/talent_pool_data_source.dart';
import 'models/talent_detail_view_data.dart';
import 'talent_detail_page.dart';
import 'widgets/talent_status_badge.dart';

class TalentPage extends StatefulWidget {
  const TalentPage({
    super.key,
    this.source = const TalentPoolDataSource(),
    this.detailBuilder,
  });
  final TalentPoolDataSource source;
  final Widget Function(Map<String, dynamic>)? detailBuilder;

  @override
  State<TalentPage> createState() => _TalentPageState();
}

class _TalentPageState extends State<TalentPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _talents = const [];
  List<String> _tagOptions = const [];
  String _keyword = '';
  String? _tag, _error, _pageError;
  int? _status;
  bool _loading = true,
      _loadingMore = false,
      _hasMore = false,
      _limited = false;
  int _request = 0, _nextPage = 1;
  bool get _hasFilters =>
      _keyword.isNotEmpty || _tag != null || _status != null;

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

  String _friendlyError(Object error) => switch (error) {
    ApiException() => error.message,
    FormatException() => error.message.toString(),
    _ => '网络异常，请检查网络后重试',
  };

  Future<void> _load({bool reset = true}) async {
    if (!reset && (_loading || _loadingMore || !_hasMore || _status != null)) {
      return;
    }
    final request = ++_request;
    final page = reset ? 1 : _nextPage;
    final keyword = _keyword;
    final tag = _tag;
    final status = _status;
    setState(() {
      _pageError = null;
      if (reset) {
        _loading = true;
        _loadingMore = false;
        _error = null;
        _talents = const [];
        _hasMore = false;
        _limited = false;
        _nextPage = 1;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final result = await widget.source.load(
        keyword: keyword,
        tag: tag,
        status: status,
        pageNum: page,
      );
      if (!mounted || request != _request) {
        return;
      }
      final rows = mergeTalentPoolRows(
        reset ? const [] : _talents,
        result.rows,
      );
      setState(() {
        _talents = rows;
        _tagOptions = {..._tagOptions, ...result.tags}.take(12).toList();
        _nextPage = result.nextPage;
        _hasMore = result.hasMore;
        _limited = result.limited;
      });
    } catch (error) {
      if (!mounted || request != _request) {
        return;
      }
      setState(() {
        if (reset) {
          _error = _friendlyError(error);
        } else {
          _pageError = _friendlyError(error);
        }
      });
    } finally {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _applyFilters() {
    _keyword = _search.text.trim();
    _load();
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _keyword = '';
      _tag = null;
      _status = null;
    });
    _load();
  }

  Future<void> _chooseTag() async {
    var input = _tag ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('标签筛选'),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('talent-tag-input'),
                  initialValue: input,
                  onChanged: (value) => input = value,
                  onFieldSubmitted: (value) =>
                      Navigator.pop(dialogContext, value.trim()),
                  decoration: const InputDecoration(
                    labelText: '标签名称',
                    helperText: '按标签名称精确匹配',
                  ),
                ),
                if (_tagOptions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '已加载记录中的标签建议',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in _tagOptions)
                        ActionChip(
                          label: Text(tag),
                          onPressed: () => Navigator.pop(dialogContext, tag),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: const Text('全部标签'),
          ),
          TextButton(
            key: const ValueKey('talent-tag-apply'),
            onPressed: () => Navigator.pop(dialogContext, input.trim()),
            child: const Text('应用'),
          ),
        ],
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() => _tag = result.isEmpty ? null : result);
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('候选人管理')),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '人才库 · 当前企业全部候选人',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                  if (_hasFilters)
                    TextButton(
                      key: const ValueKey('talent-clear'),
                      onPressed: _clearFilters,
                      child: const Text('清除条件'),
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('talent-search'),
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _applyFilters(),
                      decoration: const InputDecoration(
                        hintText: '搜索候选人姓名 / 手机号',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('talent-search-submit'),
                    tooltip: '搜索',
                    onPressed: _applyFilters,
                    icon: const Icon(Icons.search),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: SingleChildScrollView(
                        key: const ValueKey('talent-status'),
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final status in <int?>[
                              null,
                              for (var value = 0; value <= 9; value++) value,
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: _statusChip(status),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('talent-tag-filter'),
                      onPressed: _chooseTag,
                      icon: const Icon(Icons.sell_outlined, size: 17),
                      label: Text(
                        _tag == null ? '全部标签' : '标签：$_tag',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '通用评分，非岗位维度',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    ),
  );

  Widget _statusChip(int? status) {
    final selected = _status == status;
    final visual = status == null ? null : TalentStatusBadge.visualFor(status);
    return ChoiceChip(
      key: ValueKey(
        status == null ? 'talent-status-all' : 'talent-status-$status',
      ),
      selected: selected,
      showCheckmark: false,
      label: Text(status == null ? '全部' : talentStatus(status)),
      avatar: visual == null
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: AppColors.canvas,
                shape: BoxShape.circle,
              ),
              child: Icon(visual.$1, size: 15, color: visual.$2),
            ),
      selectedColor: AppColors.interactive,
      backgroundColor: AppColors.interactiveSoft,
      labelStyle: TextStyle(
        color: selected ? AppColors.canvas : AppColors.interactive,
        fontSize: 12,
      ),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      onSelected: (_) {
        setState(() => _status = status);
        _applyFilters();
      },
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const SkeletonList(rows: 4);
    }
    if (_error != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '加载失败',
        message: _error!,
        onAction: () => _load(),
      );
    }
    if (_talents.isEmpty) {
      return PageMessage(
        icon: Icons.person_search_outlined,
        title: _limited
            ? '结果较多，请补充关键词'
            : _hasFilters
            ? '当前条件无匹配'
            : '暂无候选人',
        message: _limited
            ? '仅检查前3页，已检查记录中暂无匹配。请补充关键词或标签缩小范围。'
            : _hasFilters
            ? '请调整关键词、状态或标签后重试'
            : '当前企业暂无候选人，可稍后刷新',
        actionLabel: _hasFilters ? '清除条件' : '刷新',
        onAction: _hasFilters ? _clearFilters : () => _load(),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView.builder(
        key: const ValueKey('talent-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        itemCount: _talents.length + 1,
        itemBuilder: (context, index) {
          if (index == _talents.length) {
            return _footer();
          }
          final talent = _talents[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TalentCard(
              talent: talent,
              onOpen: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      widget.detailBuilder?.call(talent) ??
                      TalentDetailPage(talent: talent),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _footer() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '已加载 ${_talents.length} 位候选人',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        if (_limited) ...[
          const SizedBox(height: 8),
          const Text(
            '结果较多，请补充关键词',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.warning),
          ),
          const Text(
            '仅检查前3页，当前结果可能不完整',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ] else if (_loadingMore)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: CircularProgressIndicator(
                key: ValueKey('talent-page-loading'),
              ),
            ),
          )
        else if (_pageError != null) ...[
          const SizedBox(height: 8),
          Text(
            _pageError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error),
          ),
          TextButton(
            key: const ValueKey('talent-page-retry'),
            onPressed: () => _load(reset: false),
            child: const Text('重试'),
          ),
        ] else if (_hasMore && _status == null)
          TextButton(
            key: const ValueKey('talent-load-more'),
            onPressed: () => _load(reset: false),
            child: const Text('加载更多'),
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '已显示全部',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
      ],
    ),
  );
}

class _TalentCard extends StatelessWidget {
  const _TalentCard({required this.talent, required this.onOpen});
  final Map<String, dynamic> talent;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final id = talentId(talent['talentId']);
    final name = talentText(talent['name'], '未知候选人');
    final score = talentNumber(talent['matchedScore']);
    final tags = talentPoolTags(talent['tags']);
    return Card(
      child: InkWell(
        key: ValueKey('talent-card-$id'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primarySoft,
                    child: Text(
                      name.characters.first,
                      style: const TextStyle(color: AppColors.interactive),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 6),
                  TalentStatusBadge(status: talent['status']),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '求职方向：${talentText(talent['jobDirection'])}',
                style: const TextStyle(fontSize: 12, color: AppColors.bodySoft),
              ),
              const SizedBox(height: 4),
              Text(
                score == null ? '通用评分：暂无评分数据' : '通用评分：$score 分',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.interactive,
                ),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
