import 'package:flutter/material.dart';

import '../../../core/formatters/backend_date.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/domain/auth_session.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/async_state_card.dart';
import '../../../widgets/section_header.dart';
import '../data/application_api.dart';
import '../domain/job_application.dart';
import 'application_screen.dart';

class ApplicationDetailScreen extends StatefulWidget {
  const ApplicationDetailScreen({
    super.key,
    required this.session,
    required this.applicationId,
    this.api,
  });
  final AuthSession session;
  final int applicationId;
  final ApplicationApi? api;

  @override
  State<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  ApiClient? _ownedClient;
  late final ApplicationApi _api;
  late Future<JobApplication> _future;
  bool _withdrawing = false;

  Future<void> _withdraw() async {
    if (_withdrawing) return;
    setState(() => _withdrawing = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('撤回投递？'),
          content: const Text('撤回后保留投递记录，暂不支持向同一岗位重复投递。确定撤回吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('暂不撤回'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认撤回'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final item = await _api.withdraw(
        widget.session.token,
        widget.applicationId,
      );
      if (!mounted) return;
      setState(() {
        _future = Future.value(item);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已撤回投递')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is ApiException ? error.message : '撤回失败，请刷新后重试'),
        ),
      );
      await _reload();
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApplicationApi(_ownedClient = ApiClient());
    _future = _api.detail(widget.session.token, widget.applicationId);
  }

  Future<void> _reload() async {
    final future = _api.detail(widget.session.token, widget.applicationId);
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {
      /* FutureBuilder displays the error. */
    }
  }

  @override
  void dispose() {
    _ownedClient?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('投递详情')),
    body: FutureBuilder<JobApplication>(
      future: _future,
      builder: (context, snapshot) => RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (snapshot.hasError)
              AsyncStateCard(
                title: '投递详情加载失败',
                message: snapshot.error is ApiException
                    ? (snapshot.error as ApiException).message
                    : '暂时无法读取投递详情，请重试',
                onRetry: _reload,
              )
            else if (snapshot.data case final item?) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.jobTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(item.companyName),
                      if (item.locationText?.isNotEmpty == true)
                        Text(item.locationText!),
                      if (item.salaryText?.isNotEmpty == true)
                        Text(item.salaryText!),
                      ApplicationStatus(application: item),
                      Text('投递时间：${displayBackendDate(item.appliedAt)}'),
                      Text('最近更新：${displayBackendDate(item.updatedAt)}'),
                      if (item.resumeName?.isNotEmpty == true)
                        Text('投递简历：${item.resumeName}'),
                      if (item.matchedScore != null)
                        Text('岗位匹配度：${item.matchedScore}%（仅供参考）'),
                    ],
                  ),
                ),
              ),
              if (item.canWithdraw) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: _withdrawing ? null : _withdraw,
                  child: Text(_withdrawing ? '正在处理…' : '撤回投递'),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              const SectionHeader(title: '投递进度', subtitle: '进度随企业处理结果更新'),
              const SizedBox(height: AppSpacing.md),
              if (item.timeline.isEmpty)
                const AsyncStateCard(
                  title: '暂无状态日志',
                  message: '企业处理投递后，可在这里查看进度。',
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < item.timeline.length;
                          index++
                        )
                          _TimelineNode(
                            node: item.timeline[index],
                            isLast: index == item.timeline.length - 1,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({required this.node, required this.isLast});
  final ApplicationTimeline node;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = switch (node.state) {
      'done' => AppColors.green,
      'current' || 'processing' => Theme.of(context).colorScheme.primary,
      'closed' => Theme.of(context).colorScheme.error,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Icon(
                node.state == 'done'
                    ? Icons.check_circle_outline
                    : Icons.radio_button_checked,
                color: color,
              ),
              if (!isLast)
                Expanded(
                  child: VerticalDivider(color: Theme.of(context).dividerColor),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    node.stateText,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: color),
                  ),
                  if (node.description?.isNotEmpty == true)
                    Text(node.description!),
                  Text(
                    displayBackendDate(node.occurredAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
