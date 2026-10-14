import 'package:flutter/material.dart';
import '../../../widgets/demo_data_badge.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/filter_chips.dart';
import '../../../widgets/page_states.dart';
import '../../../widgets/skeleton_list.dart';
import '../interview/mock_execution.dart';

/// 模块五：面试执行与级联评估 - Offer 管理页（P4，替换 P0 占位页）。
///
/// 依据《业务功能分析》UC-12 步骤9（终面分支）：
/// 终面审核通过后自动触发 Offer 发送引擎，生成录用意向书
/// （含岗位、薪资区间、入职时间等），通过邮件/短信发送给候选人。
/// 数据来源：本地 Mock 数据（mock_execution.dart 的 mockOffers），
/// TODO: P7阶段替换为真实接口（lib/api/offer_api.dart 的
/// triggerOffer / listOffers / getOfferDetail）。
class OfferPage extends StatefulWidget {
  const OfferPage({super.key});

  @override
  State<OfferPage> createState() => _OfferPageState();
}

class _OfferPageState extends State<OfferPage> {
  List<Map<String, dynamic>>? _offers;
  bool _loading = true;
  int _filterIndex = 0; // 0=全部 1=已发送 2=已接受 3=已拒绝

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 模拟加载 Offer 列表。
  /// TODO: P7阶段替换为真实接口（offer_api.listOffers）。
  Future<void> _load() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final statusFilter = switch (_filterIndex) {
      1 => 'sent',
      2 => 'accepted',
      3 => 'rejected',
      _ => null,
    };
    setState(() {
      _offers = mockOffers
          .where((o) => statusFilter == null || o['status'] == statusFilter)
          .toList();
      _loading = false;
    });
  }

  /// 模拟触发 Offer（终面通过候选人的待触发入口）。
  /// TODO: P7阶段替换为真实接口（offer_api.triggerOffer）。
  Future<void> _triggerOffer() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('触发 Offer'),
        content: const Text(
          '陈思远（高级 Flutter 开发工程师 · 终面已通过）\n'
          '将生成录用意向书（岗位、薪资区间、入职时间），\n'
          '通过邮件/短信发送给候选人（模拟）。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('触发发送'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      mockOffers.insert(0, {
        'offerId': 904,
        'candidateName': '陈思远',
        'positionName': '高级 Flutter 开发工程师',
        'salary': '35-50K·14薪',
        'onboardDate': '2026-11-24',
        'status': 'sent',
        'sentAt': '刚刚',
      });
    });
    messenger.showSnackBar(
      const SnackBar(content: Text('Offer 已发送（模拟），等待候选人确认')),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return DemoDataBadge(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Offer 管理'),
          actions: [
            TextButton.icon(
              onPressed: _triggerOffer,
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('触发 Offer'),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: FilterChips(
                labels: const ['全部', '已发送', '已接受', '已拒绝'],
                selectedIndex: _filterIndex,
                onChanged: (index) {
                  setState(() => _filterIndex = index);
                  _load();
                },
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const SkeletonList(rows: 4);
    final offers = _offers ?? const <Map<String, dynamic>>[];
    if (offers.isEmpty) {
      return PageMessage(
        icon: Icons.mail_outline,
        title: '暂无 Offer 记录',
        message: '终面审核通过后将自动触发 Offer 发送流程',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: offers.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) => _OfferCard(offer: offers[index]),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer});

  final Map<String, dynamic> offer;

  @override
  Widget build(BuildContext context) {
    final status = offer['status'] as String;
    final (statusLabel, statusColor, statusIcon) = switch (status) {
      'accepted' => ('已接受', AppColors.green, Icons.check_circle_outline),
      'rejected' => ('已拒绝', AppColors.red, Icons.cancel_outlined),
      _ => ('已发送', AppColors.interactive, Icons.schedule_outlined),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${offer['candidateName']} · ${offer['positionName']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  statusLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.payments_outlined, size: 16, color: AppColors.muted),
                const SizedBox(width: 6),
                Text(
                  '薪资区间：${offer['salary']}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.event_available_outlined,
                  size: 16,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  '预计入职：${offer['onboardDate']}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '发送于 ${offer['sentAt']}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
