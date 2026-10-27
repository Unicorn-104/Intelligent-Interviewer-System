import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/page_states.dart';
import '../../../../widgets/skeleton_list.dart';
import '../models/job_detail_view_data.dart';

class JobBasicInfoTab extends StatelessWidget {
  const JobBasicInfoTab({
    super.key,
    required this.detail,
    required this.profile,
    required this.onReload,
    required this.onReloadProfile,
    required this.onInterviews,
    this.onEdit,
    this.onPreview,
    this.onDelete,
    required this.jdSection,
    required this.workflowSection,
    required this.workflowTimeline,
  });
  final JobSectionState<JobDetailViewData> detail;
  final JobSectionState<Map<String, dynamic>> profile;
  final Future<void> Function() onReload;
  final VoidCallback onReloadProfile;
  final VoidCallback onInterviews;
  final VoidCallback? onEdit;
  final VoidCallback? onPreview;
  final VoidCallback? onDelete;
  final Widget jdSection;
  final Widget workflowSection;
  final Widget workflowTimeline;

  @override
  Widget build(BuildContext context) {
    if (detail.loading) {
      return const SkeletonList(rows: 3);
    }
    if (detail.error != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '岗位信息加载失败',
        message: detail.error!,
        onAction: onReload,
      );
    }
    final data = detail.data;
    if (data == null) {
      return PageMessage(
        icon: Icons.work_off_outlined,
        title: '暂无岗位信息',
        message: '请刷新岗位详情',
        onAction: onReload,
      );
    }
    final job = data.job;
    const education = {1: '中专', 2: '大专', 3: '本科', 4: '硕士', 5: '博士'};
    const jobTypes = {1: '全职', 2: '兼职', 3: '实习'};
    const statuses = {0: '已下线', 1: '在招', 2: '暂停'};
    return RefreshIndicator(
      onRefresh: onReload,
      child: ListView(
        key: const PageStorageKey('job-basic-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _section(null, [
            workflowTimeline,
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow =
                    constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: narrow ? constraints.maxWidth : null,
                      child: OutlinedButton.icon(
                        key: const Key('job-interviews-entry'),
                        onPressed: onInterviews,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        icon: const Icon(Icons.event_outlined, size: 18),
                        label: const Text('查看面试安排'),
                      ),
                    ),
                    if (onPreview != null)
                      SizedBox(
                        width: narrow ? constraints.maxWidth : null,
                        child: OutlinedButton.icon(
                          key: const Key('job-preview-entry'),
                          onPressed: onPreview,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('预览'),
                        ),
                      ),
                    if (onDelete != null)
                      SizedBox(
                        width: narrow ? constraints.maxWidth : null,
                        child: OutlinedButton.icon(
                          key: const Key('job-delete-entry'),
                          onPressed: onDelete,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('删除岗位'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ]),
          _section(null, [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    jobValue(job['title']),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  key: const Key('job-edit-entry'),
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('编辑'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              jobSalary(job),
              style: const TextStyle(
                color: AppColors.accentOrange,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text('所属部门：${jobValue(job['dept'])}'),
            Text('工作城市：${jobValue(job['city'])}'),
            Text('经验要求：${jobValue(job['experience'])}'),
            Text(
              '学历要求：${education[int.tryParse('${job['education']}')] ?? '未提供'}',
            ),
            Text(
              '工作性质：${jobTypes[int.tryParse('${job['jobType']}')] ?? '未提供'}',
            ),
            Text('岗位状态：${statuses[int.tryParse('${job['status']}')] ?? '未提供'}'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _highlightChip(
                  key: const Key('job-basic-published'),
                  icon: Icons.calendar_today_outlined,
                  label: '发布日期：${jobValue(job['date'], fallback: '未提供')}',
                  background: AppColors.primarySoft,
                  foreground: AppColors.brand,
                ),
                _highlightChip(
                  key: const Key('job-basic-applicants'),
                  icon: Icons.group_outlined,
                  label: '投递人数：${jobValue(data.funnel['total'], fallback: '未提供')}',
                  background: AppColors.interactiveSoft,
                  foreground: AppColors.interactive,
                ),
              ],
            ),
          ]),
          _section('职责要求', [_description(data)]),
          _section('技能', [_skills()]),
          jdSection,
          const SizedBox(height: 16),
          workflowSection,
        ],
      ),
    );
  }

  /// 资料卡高亮项：投递人数、发布日期等关键信息以彩色胶囊突出展示。
  Widget _highlightChip({
    required Key key,
    required IconData icon,
    required String label,
    required Color background,
    required Color foreground,
  }) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: foreground),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: foreground,
          ),
        ),
      ],
    ),
  );

  Widget _section(String? title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [if (title != null) SectionTitle(title), ...children],
    ),
  );

  Widget _description(JobDetailViewData data) {
    try {
      final description = data.description;
      final duties = jobLines(description['responsibilities']);
      final requirements = jobLines(description['requirements']);
      if (duties.isEmpty && requirements.isEmpty) {
        return PageMessage(
          icon: Icons.description_outlined,
          title: '暂无职责要求',
          message: '当前岗位没有可展示的正文',
          actionLabel: '刷新',
          onAction: onReload,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('工作职责', style: TextStyle(fontWeight: FontWeight.w600)),
          if (duties.isEmpty)
            const Text('未提供')
          else
            for (final line in duties)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('• $line'),
              ),
          const SizedBox(height: 16),
          const Text('任职要求', style: TextStyle(fontWeight: FontWeight.w600)),
          if (requirements.isEmpty)
            const Text('未提供')
          else
            for (final line in requirements)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('• $line'),
              ),
        ],
      );
    } on FormatException {
      return PageMessage(
        icon: Icons.error_outline,
        title: '职责要求加载失败',
        message: '岗位描述格式不正确',
        onAction: onReload,
      );
    }
  }

  Widget _skills() {
    if (profile.loading) {
      return const SkeletonList(rows: 1);
    }
    if (profile.error != null) {
      return PageMessage(
        icon: Icons.cloud_off_outlined,
        title: '技能加载失败',
        message: profile.error!,
        onAction: onReloadProfile,
      );
    }
    final skills = jobProfileSkills(profile.data ?? const {});
    if (skills.isEmpty) {
      return PageMessage(
        icon: Icons.label_outline,
        title: '暂无技能标签',
        message: '可在JD画像区解析或重新读取',
        actionLabel: '刷新',
        onAction: onReloadProfile,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills
          .map(
            (skill) => Chip(
              label: Text(
                '${skill['name']} · ${jobSkillLabel(skill['required'])}',
              ),
              side: BorderSide.none,
              backgroundColor: AppColors.interactiveSoft,
            ),
          )
          .toList(),
    );
  }
}
