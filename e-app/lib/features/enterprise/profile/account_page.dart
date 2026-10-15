import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/skeleton_list.dart';
import 'settings_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<AccountPage> createState() => AccountPageState();
}

class AccountPageState extends State<AccountPage> {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'enterprise_access_token';

  final _client = ApiClient();
  Map<String, dynamic>? _user;
  String? _error;
  bool _loading = true;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  /// 每次进入“我的”均重新获取当前用户，不缓存登录时的资料。
  Future<void> reload() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null || token.isEmpty) {
        throw const ApiException('登录已失效，请重新登录');
      }
      final response = await _client.get('/getInfo', token: token);
      final user = response['user'];
      if (user is! Map) throw const ApiException('用户资料暂不可用，请重试');
      if (!mounted || request != _request) return;
      setState(() => _user = Map<String, dynamic>.from(user));
    } on ApiException catch (error) {
      if (!mounted || request != _request) return;
      setState(
        () => _error = error.isUnauthorized ? '登录已失效，请退出后重新登录' : error.message,
      );
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() => _error = '获取用户信息失败，请重试');
    } finally {
      if (mounted && request == _request) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonList(rows: 3);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_outline,
                size: 48,
                color: AppColors.muted,
              ),
              const SizedBox(height: 12),
              Text('当前登录用户', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: reload, child: const Text('重试')),
              TextButton(onPressed: widget.onLogout, child: const Text('退出登录')),
            ],
          ),
        ),
      );
    }
    final user = _user!;
    final username = user['userName']?.toString().trim();
    final nickName = user['nickName']?.toString().trim();
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前登录用户',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    username == null || username.isEmpty ? '账号未提供' : username,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (nickName != null && nickName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '用户昵称：$nickName',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('设置'),
              subtitle: const Text('企业组织与通知配置'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => const EnterpriseSettingsPage(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('退出登录'),
          ),
        ],
      ),
    );
  }
}
