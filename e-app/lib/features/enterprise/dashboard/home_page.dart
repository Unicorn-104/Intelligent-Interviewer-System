import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'widgets/home_section.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onNotifications,
    required this.onFeatures,
    required this.onInterviews,
    required this.onJobs,
  });
  final VoidCallback onNotifications;
  final VoidCallback onFeatures;
  final VoidCallback onInterviews;
  final VoidCallback onJobs;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('首页'),
      actions: [
        IconButton(
          tooltip: '通知与公告',
          onPressed: onNotifications,
          icon: const Icon(Icons.notifications_none),
        ),
        IconButton(
          tooltip: '更多功能',
          onPressed: onFeatures,
          icon: const Icon(Icons.apps_outlined),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      bottom: false,
      child: ListView(
        key: const PageStorageKey('enterprise-home-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text('企业信息待接入', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('更多信息正在接入', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 24),
          Container(
            key: const ValueKey('home-carousel-placeholder'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                colors: [AppColors.brand, AppColors.brandDeep],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.business_center_outlined,
                  color: AppColors.canvas,
                  size: 28,
                ),
                SizedBox(height: 16),
                Text(
                  '招聘工作台',
                  style: TextStyle(
                    color: AppColors.canvas,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text('更多信息正在接入', style: TextStyle(color: AppColors.canvas)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          HomeSection(
            title: '近期面试',
            onMore: onInterviews,
            child: const HomeSkeleton(),
          ),
          const SizedBox(height: 24),
          HomeSection(
            title: '新投递简历的岗位',
            onMore: onJobs,
            child: const HomeSkeleton(),
          ),
          const SizedBox(height: 24),
          HomeSection(
            title: '快捷统计',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 560 ? 4 : 2;
                final width =
                    (constraints.maxWidth - (columns - 1) * 16) / columns;
                return Wrap(
                  spacing: 16,
                  runSpacing: 24,
                  children: [
                    for (final label in ['在招岗位', '待面试', '待终审', '本周完成'])
                      SizedBox(
                        width: width,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '—',
                              style: TextStyle(
                                color: AppColors.brand,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              label,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
