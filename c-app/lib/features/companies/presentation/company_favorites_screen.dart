import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/domain/auth_session.dart';
import '../../profile/presentation/profile_avatar.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/async_state_card.dart';
import '../data/company_api.dart';
import '../domain/company.dart';
import 'company_screen.dart';

class CompanyFavoritesScreen extends StatefulWidget {
  const CompanyFavoritesScreen({
    super.key,
    required this.session,
    this.showAppBar = true,
  });
  final AuthSession session;
  final bool showAppBar;
  @override
  State<CompanyFavoritesScreen> createState() => _CompanyFavoritesScreenState();
}

class _CompanyFavoritesScreenState extends State<CompanyFavoritesScreen> {
  final _client = ApiClient();
  late final _api = CompanyApi(_client);
  List<Company> _items = [];
  bool _loading = false, _hasNext = false;
  int _page = 0, _generation = 0;
  String? _error;
  bool _failedMore = false;
  bool _loadedOnce = false;
  final Set<int> _savingIds = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _client.close();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loading || !_hasNext)) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.favorites(
        widget.session.token,
        page: more ? _page + 1 : 1,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        final ids = more ? _items.map((item) => item.id).toSet() : <int>{};
        _items = [
          ...(more ? _items : <Company>[]),
          ...result.items.where((item) => ids.add(item.id)),
        ];
        _page = result.page;
        _hasNext = result.hasNext;
        _loadedOnce = true;
      });
    } on ApiException catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = error.message;
          _failedMore = more;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _remove(Company company) async {
    if (_savingIds.contains(company.id)) return;
    setState(() => _savingIds.add(company.id));
    try {
      final followed = await _api.setFollowed(
        widget.session.token,
        company.id,
        false,
      );
      if (!mounted) return;
      if (!followed) {
        setState(() {
          _items.removeWhere((item) => item.id == company.id);
          _savingIds.remove(company.id);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已取消收藏 ${company.name}')));
      } else {
        setState(() => _savingIds.remove(company.id));
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _savingIds.remove(company.id));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _open(Company company) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            CompanyScreen(session: widget.session, companyId: company.id),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.showAppBar ? AppBar(title: const Text('收藏的企业')) : null,
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(
            '企业发布新岗位时，可在消息中查看提醒。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_loading) const LinearProgressIndicator(),
          if (_loadedOnce && !_loading && _error == null && _items.isEmpty)
            const AsyncStateCard(
              icon: Icons.bookmark_border,
              title: '还没有收藏企业',
              message: '在职位详情中点击企业，即可查看主页并收藏。',
            ),
          for (final company in _items) ...[
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(AppSpacing.lg),
                leading: ProfileAvatar(
                  avatar: company.logoUrl,
                  name: company.name,
                  radius: 22,
                  backgroundColor: AppColors.primarySoft,
                ),
                title: Text(company.name),
                subtitle: Text(
                  [
                    company.industry,
                    company.city,
                  ].whereType<String>().join(' · '),
                ),
                trailing: IconButton(
                  tooltip: '取消收藏',
                  onPressed: _savingIds.contains(company.id)
                      ? null
                      : () => _remove(company),
                  icon: _savingIds.contains(company.id)
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bookmark),
                ),
                onTap: () => _open(company),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_error case final error?)
            AsyncStateCard(
              icon: Icons.wifi_off,
              title: '收藏加载失败',
              message: error,
              onRetry: () => _load(more: _failedMore),
            ),
          if (_hasNext && _error == null)
            OutlinedButton(
              onPressed: _loading ? null : () => _load(more: true),
              child: const Text('加载更多'),
            ),
        ],
      ),
    ),
  );
}
