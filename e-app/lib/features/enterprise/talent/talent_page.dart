import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import 'data/talent_pool_data_source.dart';
import 'data/talent_discovery_data_source.dart';
import 'talent_discovery_profile.dart';
import 'data/talent_contact_data_source.dart';
import '../notification/conversation_page.dart';
import 'widgets/talent_filter_sheet.dart';
import 'widgets/talent_filter_icon.dart';
import 'models/talent_detail_view_data.dart';
import 'talent_detail_page.dart';
import 'widgets/talent_status_badge.dart';

class TalentPage extends StatefulWidget {
  const TalentPage({
    super.key,
    TalentPoolDataSource? source,
    this.discovery = false,
    this.detailBuilder,
    this.contactSource = const TalentContactDataSource(),
    this.chatBuilder,
  }) : source =
           source ??
           (discovery
               ? const TalentDiscoveryDataSource()
               : const TalentPoolDataSource());
  final bool discovery;
  final TalentPoolDataSource source;
  final Widget Function(Map<String, dynamic>)? detailBuilder;
  final TalentContactDataSource contactSource;
  final Widget Function(Map<String, dynamic>)? chatBuilder;

  @override
  State<TalentPage> createState() => _TalentPageState();
}

class _TalentPageState extends State<TalentPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _talents = const [];
  String _keyword = '';
  String? _error, _pageError;
  int? _status;
  String? _direction;
  bool _contacting = false;
  TalentPoolFilters _extended = const TalentPoolFilters();
  TalentPoolFilters get _filters => TalentPoolFilters(
    status: _status,
    direction: _direction,
    minimumEducation: _extended.minimumEducation,
    experienceRange: _extended.experienceRange,
    city: _extended.city,
    cityType: _extended.cityType,
    loginWithinDays: _extended.loginWithinDays,
  );
  bool _loading = true,
      _loadingMore = false,
      _hasMore = false,
      _limited = false;
  int _request = 0, _nextPage = 1;
  bool get _hasFilters => _keyword.isNotEmpty || _filters.count > 0;

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

  String _friendlyError(Object error) => widget.discovery
      ? TalentDiscoveryDataSource.errorMessage(error)
      : switch (error) {
          ApiException() => error.message,
          FormatException() => error.message.toString(),
          _ => '网络异常，请检查网络后重试',
        };

  Future<void> _load({bool reset = true}) async {
    if (!reset && (_loading || _loadingMore || !_hasMore)) {
      return;
    }
    final request = ++_request;
    final page = reset ? 1 : _nextPage;
    final keyword = _keyword;
    final status = _status;
    final direction = _direction;
    final extended = _extended;
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
        status: status,
        direction: direction,
        extended: extended,
        pageNum: page,
      );
      if (!mounted || request != _request) {
        return;
      }
      final rows = widget.discovery
          ? mergeDiscoveryRows(
              reset ? const [] : _talents,
              result.rows.map(TalentDiscoveryDataSource.publicProfile),
            )
          : mergeTalentPoolRows(reset ? const [] : _talents, result.rows);
      setState(() {
        _talents = rows;
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
      _status = null;
      _direction = null;
      _extended = const TalentPoolFilters();
    });
    _load();
  }

  Future<void> _chooseFilters() async {
    FocusScope.of(context).unfocus();
    final filters = await showModalBottomSheet<TalentPoolFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(),
      builder: (_) => FractionallySizedBox(
        heightFactor: 1,
        child: TalentFilterSheet(
          initial: _filters,
          loadOptions: widget.source.loadOptions,
          discovery: widget.discovery,
        ),
      ),
    );
    if (!mounted || filters == null) return;
    setState(() {
      _status = filters.status;
      _direction = filters.direction;
      _extended = filters;
    });
    _applyFilters();
  }

  Future<void> _contact(Map<String, dynamic> talent) async {
    final id = talentId(talent[widget.discovery ? 'userId' : 'talentId']);
    if (_contacting || id == null) return;
    setState(() => _contacting = true);
    try {
      // 平台资料使用真实用户ID，直接进入聊天；不发送占位消息来创建会话。
      final Map<String, dynamic> session;
      if (widget.discovery) {
        session = {
          'peerId': id,
          'peerName': talent['name'],
          'peerAvatar': talent['avatar'],
          'fromTalentDiscovery': true,
        };
      } else {
        final target = await widget.contactSource.loadTarget(id);
        final existing = await widget.contactSource.findSession(target);
        session = {
          ...?existing,
          'peerId': target.userId,
          'peerName': target.name,
          'peerAvatar': target.avatar,
        };
      }
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              widget.chatBuilder?.call(session) ??
              ChatPage(session: session, source: widget.contactSource.messages),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _contacting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.discovery ? '人才库' : '候选人管理')),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.discovery ? '发现全站已注册求职者' : '人才库 · 当前企业全部候选人',
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
                    child: DecoratedBox(
                      key: const ValueKey('talent-search-bar'),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B8B0),
                        border: Border.all(
                          color: const Color(0xFF00B8B0),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(1.5),
                        child: SizedBox(
                          height:
                              MediaQuery.textScalerOf(context).scale(14) + 34,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  key: const ValueKey(
                                    'talent-search-input-shape',
                                  ),
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(6.5),
                                  ),
                                  child: ColoredBox(
                                    color: AppColors.canvas,
                                    child: TextField(
                                      key: const ValueKey('talent-search'),
                                      controller: _search,
                                      style: const TextStyle(fontSize: 14),
                                      textAlignVertical:
                                          TextAlignVertical.center,
                                      textInputAction: TextInputAction.search,
                                      onSubmitted: (_) => _applyFilters(),
                                      decoration: InputDecoration(
                                        hintText: widget.discovery
                                            ? '搜索姓名 / 期望岗位'
                                            : '搜索姓名 / 手机号',
                                        hintStyle: TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 14,
                                        ),
                                        filled: false,
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 50,
                                child: IconButton.filled(
                                  key: const ValueKey('talent-search-submit'),
                                  tooltip: '搜索',
                                  onPressed: _applyFilters,
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF00B8B0),
                                    foregroundColor: AppColors.canvas,
                                    padding: EdgeInsets.zero,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.horizontal(
                                        right: Radius.circular(6.5),
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.search, size: 24),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const ValueKey('talent-filter-open'),
                    tooltip: _filters.count == 0
                        ? '筛选'
                        : '筛选(${_filters.count})',
                    onPressed: _chooseFilters,
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(48),
                      padding: const EdgeInsets.all(10),
                    ),
                    icon: Badge(
                      key: const ValueKey('talent-filter-count'),
                      isLabelVisible: _filters.count > 0,
                      label: Text('${_filters.count}'),
                      backgroundColor: AppColors.interactive,
                      child: TalentFilterIcon(
                        color: _filters.count > 0
                            ? AppColors.interactive
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              if (_filters.count > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    [
                      if (_extended.minimumEducation != null)
                        TalentPoolFilters.educationLabels[_extended
                            .minimumEducation]!,
                      if (_extended.experienceRange != null)
                        TalentPoolFilters.experienceLabels[_extended
                            .experienceRange]!,
                      if (_extended.city != null)
                        '${_extended.cityType == 'current' ? '所在' : '期望'}城市：${_extended.city}',
                      if (_extended.loginWithinDays != null)
                        '活跃度：近${_extended.loginWithinDays}天',
                      if (_direction != null) '方向：$_direction',
                      if (_status != null)
                        '状态：${widget.discovery ? discoveryStatus(_status) : talentStatus(_status!)}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.interactive,
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.discovery ? '仅展示基础资料与求职期望' : '通用评分，非岗位维度',
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
            : widget.discovery
            ? '暂无可展示的人才'
            : '暂无候选人',
        message: _limited
            ? '仅检查前3页，已检查记录中暂无匹配。请补充关键词或求职方向缩小范围。'
            : _hasFilters
            ? '请调整关键词或筛选条件后重试'
            : widget.discovery
            ? '暂无已注册求职者资料，可稍后刷新'
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
            child: widget.discovery
                ? DiscoveryTalentCard(
                    profile: talent,
                    contactEnabled: !_contacting,
                    onContact: () => _contact(talent),
                    onOpen: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            widget.detailBuilder?.call(talent) ??
                            TalentDiscoveryProfilePage(
                              userId: talentId(talent['userId'])!,
                              source: widget.source is TalentDiscoveryDataSource
                                  ? widget.source as TalentDiscoveryDataSource
                                  : const TalentDiscoveryDataSource(),
                              onContact: _contact,
                            ),
                      ),
                    ),
                  )
                : _TalentCard(
                    talent: talent,
                    contactEnabled: !_contacting,
                    onContact: () => _contact(talent),
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
          '已加载 ${_talents.length} 位${widget.discovery ? '人才' : '候选人'}',
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
        ] else if (_hasMore)
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
  const _TalentCard({
    required this.talent,
    required this.onOpen,
    required this.onContact,
    required this.contactEnabled,
  });
  final Map<String, dynamic> talent;
  final VoidCallback onOpen, onContact;
  final bool contactEnabled;

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
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: ValueKey('talent-contact-$id'),
                  onPressed: contactEnabled && id != null ? onContact : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 17),
                  label: const Text('主动沟通'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
