import 'package:flutter/material.dart';

import '../../../config/app_config.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import 'data/talent_discovery_data_source.dart';

String _text(Object? value, [String fallback = '未填写']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

class _PublicAvatar extends StatelessWidget {
  const _PublicAvatar(this.profile);
  final Map<String, dynamic> profile;
  @override
  Widget build(BuildContext context) {
    final name = _text(profile['name'], '求职者');
    final base = Uri.parse(AppConfig.apiBaseUrl);
    final path = Uri.tryParse(_text(profile['avatar'], ''));
    final uri = path == null ? null : base.resolveUri(path);
    final safe =
        uri != null &&
        ['http', 'https'].contains(uri.scheme) &&
        uri.origin == base.origin &&
        uri.userInfo.isEmpty &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty &&
        uri.path.startsWith('/profile/');
    return SizedBox(
      width: 48,
      height: 48,
      child: ClipOval(
        child: safe
            ? Image.network(
                uri.toString(),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(name),
              )
            : _fallback(name),
      ),
    );
  }

  Widget _fallback(String name) => ColoredBox(
    color: AppColors.primarySoft,
    child: Center(
      child: Text(
        name.characters.first,
        style: const TextStyle(fontSize: 20, color: AppColors.interactive),
      ),
    ),
  );
}

class DiscoveryTalentCard extends StatelessWidget {
  const DiscoveryTalentCard({
    super.key,
    required this.profile,
    required this.contactEnabled,
    required this.onOpen,
    required this.onContact,
  });
  final Map<String, dynamic> profile;
  final bool contactEnabled;
  final VoidCallback onOpen, onContact;
  static const _teal = Color(0xFF00AFA6);

  Widget _identity(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _PublicAvatar(profile),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _text(profile['name'], '求职者'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  discoverySalary(profile),
                  key: ValueKey('discovery-salary-${profile['userId']}'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: profile['salaryNegotiable'] == null
                        ? AppColors.muted
                        : const Color(0xFFDF7A22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                Text(
                  discoveryEducation(profile['highestEducation']),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.bodySoft,
                  ),
                ),
                Text(
                  discoveryExperience(profile['workMonths']),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.bodySoft,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _intention() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _line(
        Icons.work_outline_rounded,
        '期望岗位：${_text(profile['jobDirection'], '暂未填写期望岗位')}',
        emphasize: true,
      ),
      const SizedBox(height: 6),
      _line(Icons.location_on_outlined, '期望城市：${_text(profile['targetCity'])}'),
      const SizedBox(height: 6),
      _line(Icons.school_outlined, discoverySchool(profile)),
    ],
  );

  Widget _line(IconData icon, String text, {bool emphasize = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, size: 16, color: emphasize ? _teal : AppColors.muted),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: emphasize ? 14 : 12,
            fontWeight: emphasize ? FontWeight.w500 : FontWeight.normal,
            color: emphasize ? AppColors.textPrimary : AppColors.bodySoft,
            height: 1.45,
          ),
        ),
      ),
    ],
  );

  Widget _status() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        discoveryStatus(profile['currentStatus']),
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.bodySoft,
          height: 1.4,
        ),
      ),
      if (_text(profile['currentCity'], '').isNotEmpty) ...[
        const SizedBox(height: 3),
        Text(
          '现居 ${profile['currentCity']}',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
      ],
    ],
  );

  Widget _contactButton(BuildContext context) => FilledButton(
    key: ValueKey('discovery-contact-${profile['userId']}'),
    onPressed: contactEnabled ? onContact : null,
    style: FilledButton.styleFrom(
      backgroundColor: _teal,
      foregroundColor: AppColors.canvas,
      minimumSize: const Size(92, 44),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      textStyle: Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    child: const Text('主动沟通'),
  );

  @override
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: AppColors.hairline),
    ),
    child: InkWell(
      key: ValueKey('discovery-user-${profile['userId']}'),
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 640 &&
                MediaQuery.textScalerOf(context).scale(14) <= 21;
            if (wide) {
              return Row(
                key: const Key('discovery-card-wide'),
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _identity(context),
                        const SizedBox(height: 10),
                        _status(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(flex: 5, child: _intention()),
                  const SizedBox(width: 20),
                  _contactButton(context),
                ],
              );
            }
            return Column(
              key: const Key('discovery-card-compact'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _identity(context),
                const SizedBox(height: 12),
                _intention(),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _status()),
                    const SizedBox(width: 12),
                    _contactButton(context),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

/// 平台人才详情只读取公开基础资料，绝不进入企业岗位候选人详情。
class TalentDiscoveryProfilePage extends StatefulWidget {
  const TalentDiscoveryProfilePage({
    super.key,
    required this.userId,
    required this.source,
    required this.onContact,
  });
  final int userId;
  final TalentDiscoveryDataSource source;
  final Future<void> Function(Map<String, dynamic>) onContact;
  @override
  State<TalentDiscoveryProfilePage> createState() =>
      _TalentDiscoveryProfilePageState();
}

class _TalentDiscoveryProfilePageState
    extends State<TalentDiscoveryProfilePage> {
  Map<String, dynamic>? _profile;
  bool _loading = true, _contacting = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = TalentDiscoveryDataSource.publicProfile(
        await widget.source.detail(widget.userId),
      );
      if (row['userId'] != widget.userId) {
        throw const FormatException('用户资料关联不一致');
      }
      if (mounted) setState(() => _profile = row);
    } catch (error) {
      if (mounted) {
        setState(() => _error = TalentDiscoveryDataSource.errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _contact() async {
    if (_contacting || _profile == null) return;
    setState(() => _contacting = true);
    try {
      await widget.onContact(_profile!);
    } finally {
      if (mounted) setState(() => _contacting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('人才资料')),
    body: _loading
        ? const SkeletonList(rows: 2)
        : _error != null
        ? PageMessage(
            icon: Icons.person_search_outlined,
            title: '人才资料暂不可用',
            message: _error!,
            onAction: _load,
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              key: const Key('discovery-profile'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _PublicAvatar(_profile!),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _text(_profile!['name'], '求职者'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          '基础信息',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '最高学历：${discoveryEducation(_profile!['highestEducation'])}',
                        ),
                        Text(
                          '工作经验：${discoveryExperience(_profile!['workMonths'])}',
                        ),
                        Text('毕业院校：${discoverySchool(_profile!)}'),
                        Text('所在城市：${_text(_profile!['currentCity'])}'),
                        Text(
                          '求职状态：${discoveryStatus(_profile!['currentStatus'])}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '求职期望',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '期望岗位：${_text(_profile!['jobDirection'], '暂未填写期望岗位')}',
                        ),
                        Text('期望城市：${_text(_profile!['targetCity'])}'),
                        Text('期望薪资：${discoverySalary(_profile!)}'),
                        const Text(
                          '薪资口径：人民币税前月薪',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('discovery-profile-contact'),
                  onPressed: _contacting ? null : _contact,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(_contacting ? '正在核对账号…' : '主动沟通'),
                ),
                const SizedBox(height: 10),
                const Text(
                  '仅展示公开基础资料与求职期望，联系方式请在沟通中向本人确认。',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
  );
}
