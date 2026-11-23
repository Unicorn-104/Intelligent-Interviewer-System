import 'package:flutter/material.dart';

import '../../../api/talent_api.dart' as talent_api;
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import '../notification/conversation_page.dart';
import '../talent/data/talent_contact_data_source.dart';
import '../talent/data/talent_discovery_data_source.dart';
import '../talent/talent_discovery_profile.dart';

/// 岗位收藏者列表：只展示求职者主动公开的人才发现资料。
class InterestedTalentPage extends StatefulWidget {
  const InterestedTalentPage({
    super.key,
    required this.positionId,
    required this.positionTitle,
    this.initialCount,
    this.loader,
  });

  final int positionId;
  final String positionTitle;
  final int? initialCount;
  final Future<List<Map<String, dynamic>>> Function(int positionId)? loader;

  @override
  State<InterestedTalentPage> createState() => _InterestedTalentPageState();
}

class _InterestedTalentPageState extends State<InterestedTalentPage> {
  final _search = TextEditingController();
  final _contactSource = const TalentContactDataSource();
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  bool _contacting = false;
  String? _error;

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await (widget.loader ?? talent_api.listInterestedTalent)(
        widget.positionId,
      );
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object error) => switch (error) {
    ApiException() => error.message,
    FormatException() => error.message.toString(),
    _ => '加载感兴趣人才失败，请稍后重试',
  };

  List<Map<String, dynamic>> get _filtered {
    final keyword = _search.text.trim().toLowerCase();
    if (keyword.isEmpty) return _rows;
    return _rows
        .where((row) {
          final values = [
            row['name'],
            row['jobDirection'],
            row['targetCity'],
            row['currentCity'],
          ].map((value) => '$value'.toLowerCase());
          return values.any((value) => value.contains(keyword));
        })
        .toList(growable: false);
  }

  Future<void> _contact(Map<String, dynamic> profile) async {
    final id = int.tryParse('${profile['userId']}');
    if (_contacting || id == null || id <= 0) return;
    setState(() => _contacting = true);
    try {
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            session: {
              'peerId': id,
              'peerName': profile['name'],
              'peerAvatar': profile['avatar'],
              'fromTalentDiscovery': true,
            },
            source: _contactSource.messages,
          ),
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

  void _openProfile(Map<String, dynamic> profile) {
    final id = int.tryParse('${profile['userId']}');
    if (id == null || id <= 0) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TalentDiscoveryProfilePage(
          userId: id,
          source: const TalentDiscoveryDataSource(),
          onContact: _contact,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    final count = widget.initialCount ?? _rows.length;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),
      appBar: AppBar(
        title: const Text('感兴趣人才'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.interactiveSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bookmark_added_outlined,
                        color: AppColors.interactive,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.positionTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        '$count 人感兴趣',
                        style: const TextStyle(
                          color: AppColors.interactive,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '搜索姓名、求职方向或城市',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除',
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '仅展示求职者公开的基础资料，联系方式需通过主动沟通获取。',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Expanded(child: _body(rows)),
        ],
      ),
    );
  }

  Widget _body(List<Map<String, dynamic>> rows) {
    if (_loading) return const SkeletonList(rows: 4);
    if (_error != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '加载失败',
        message: _error!,
        onAction: _load,
      );
    }
    if (rows.isEmpty) {
      return PageMessage(
        icon: Icons.person_search_outlined,
        title: _search.text.trim().isEmpty ? '暂无感兴趣人才' : '没有匹配的人才',
        message: _search.text.trim().isEmpty
            ? '求职者收藏岗位后，会出现在这里。'
            : '请尝试其他姓名、方向或城市关键词。',
        actionLabel: _search.text.trim().isEmpty ? '刷新' : '清除搜索',
        onAction: _search.text.trim().isEmpty
            ? _load
            : () {
                _search.clear();
                setState(() {});
              },
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final profile = rows[index];
          return DiscoveryTalentCard(
            profile: profile,
            contactEnabled: !_contacting,
            onOpen: () => _openProfile(profile),
            onContact: () => _contact(profile),
          );
        },
      ),
    );
  }
}
