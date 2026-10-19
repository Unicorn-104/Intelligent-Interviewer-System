import 'package:flutter/material.dart';

import '../../../core/formatters/backend_date.dart';
import '../../../core/network/api_client.dart';
import '../../../features/auth/domain/auth_session.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/async_state_card.dart';
import '../data/application_api.dart';
import '../domain/job_application.dart';
import 'application_controller.dart';
import 'application_detail_screen.dart';

class ApplicationScreen extends StatefulWidget {
  const ApplicationScreen({super.key, required this.session, this.api});
  final AuthSession session;
  final ApplicationApi? api;

  @override
  State<ApplicationScreen> createState() => _ApplicationScreenState();
}

class _ApplicationScreenState extends State<ApplicationScreen> {
  ApiClient? _ownedClient;
  late final ApplicationApi _api;
  late final ApplicationController _controller;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApplicationApi(_ownedClient = ApiClient());
    _controller = ApplicationController(_api, widget.session.token)..refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    _ownedClient?.close();
    super.dispose();
  }

  Future<void> _open(JobApplication application) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ApplicationDetailScreen(
          session: widget.session,
          applicationId: application.id,
          api: _api,
        ),
      ),
    );
    if (mounted) await _controller.refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('投递跟踪')),
    body: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final controller = _controller;
        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                children: [
                  for (final filter in const <(String, String?)>[
                    ('全部', null),
                    ('正在进行', 'active'),
                    ('面试中', 'interview'),
                    ('已结束', 'closed'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(filter.$1),
                        selected: controller.status == filter.$2,
                        onSelected: (_) => controller.refresh(
                          filter: filter.$2,
                          changeFilter: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.extentAfter < AppSpacing.xxxl * 4 &&
                      controller.error == null) {
                    controller.loadMore();
                  }
                  return false;
                },
                child: RefreshIndicator(
                  onRefresh: controller.refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    children: [
                      if (controller.loading) const LinearProgressIndicator(),
                      if (controller.initialized) ...[
                        Text(
                          '共 ${controller.total} 条投递记录',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      for (final item in controller.items) ...[
                        Card(
                          child: InkWell(
                            onTap: () => _open(item),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.jobTitle,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(item.companyName),
                                  const SizedBox(height: AppSpacing.sm),
                                  ApplicationStatus(application: item),
                                  Text(
                                    '投递于 ${displayBackendDate(item.appliedAt)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  Text(
                                    '最近更新 ${displayBackendDate(item.updatedAt)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  const Row(
                                    children: [
                                      Text('查看投递进度'),
                                      Icon(Icons.chevron_right),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (controller.error case final error?)
                        AsyncStateCard(
                          title: '投递记录加载失败',
                          message: error,
                          icon: Icons.wifi_off_outlined,
                          onRetry: controller.retry,
                        )
                      else if (controller.initialized &&
                          controller.items.isEmpty &&
                          !controller.loading)
                        const AsyncStateCard(
                          title: '暂无投递记录',
                          message: '当前筛选条件下还没有投递记录。',
                          icon: Icons.send_outlined,
                        ),
                      if (controller.loadingMore)
                        const Center(child: CircularProgressIndicator())
                      else if (controller.initialized &&
                          controller.hasNext &&
                          controller.error == null)
                        TextButton(
                          onPressed: controller.loadMore,
                          child: const Text('加载更多'),
                        )
                      else if (controller.items.isNotEmpty &&
                          !controller.hasNext)
                        const Center(child: Text('已显示全部投递记录')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class ApplicationStatus extends StatelessWidget {
  const ApplicationStatus({super.key, required this.application});
  final JobApplication application;

  @override
  Widget build(BuildContext context) {
    final color = switch (application.status) {
      'active' => AppColors.warning,
      'interview' => AppColors.green,
      'closed' => Theme.of(context).colorScheme.error,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return Chip(
      label: Text(
        application.statusText,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}
