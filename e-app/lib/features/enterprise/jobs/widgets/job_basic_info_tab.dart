import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/page_states.dart';
import '../../../../widgets/skeleton_list.dart';
import '../models/job_detail_view_data.dart';

/// 岗位「基础信息」页：面试流程与操作、岗位信息、职责要求、技能四个卡片。
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _section(null, [
            workflowTimeline,
            const SizedBox(height: 20),
            _actionRow(context),
          ]),
          _section(null, [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    jobValue(job['title']),
                    style: const TextStyle(
                      color: AppColors.brand,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  key: const Key('job-edit-entry'),
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.teal,
                    minimumSize: const Size(44, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text(
                    '编辑',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              jobSalary(job),
              style: const TextStyle(
                color: AppColors.accentOrange,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _infoField(
                        Icons.business_outlined,
                        '所属部门',
                        jobValue(job['dept']),
                      ),
                      _infoField(
                        Icons.location_on_outlined,
                        '工作城市',
                        jobValue(job['city']),
                      ),
                      _infoField(
                        Icons.work_history_outlined,
                        '经验要求',
                        jobValue(job['experience']),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _infoField(
                        Icons.school_outlined,
                        '学历要求',
                        education[int.tryParse('${job['education']}')] ??
                            '未提供',
                      ),
                      _infoField(
                        Icons.work_outline,
                        '工作性质',
                        jobTypes[int.tryParse('${job['jobType']}')] ??
                            '未提供',
                      ),
                      _infoField(
                        Icons.campaign_outlined,
                        '岗位状态',
                        statuses[int.tryParse('${job['status']}')] ??
                            '未提供',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _highlightChip(
                  key: const Key('job-basic-published'),
                  icon: Icons.calendar_today_outlined,
                  label: '发布日期：${jobValue(job['date'], fallback: '未提供')}',
                ),
                _highlightChip(
                  key: const Key('job-basic-applicants'),
                  icon: Icons.group_outlined,
                  label: '投递人数：${jobValue(data.funnel['total'], fallback: '未提供')}',
                ),
              ],
            ),
          ]),
          _section(
            '职责要求',
            [_description(data)],
            icon: Icons.description_outlined,
          ),
          _section('技能', [_skills()], icon: Icons.view_in_ar_outlined),
        ],
      ),
    );
  }

  /// 面试安排 / 预览 / 删除岗位三个操作按钮；窄屏自动改为纵向全宽。
  Widget _actionRow(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow =
          constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final buttons = [
        _actionButton(
          key: const Key('job-interviews-entry'),
          icon: Icons.event_outlined,
          label: '面试安排',
          onPressed: onInterviews,
          background: AppColors.teal,
          foreground: Colors.white,
        ),
        if (onPreview != null)
          _actionButton(
            key: const Key('job-preview-entry'),
            icon: Icons.visibility_outlined,
            label: '预览',
            onPressed: onPreview,
            background: AppColors.tealSoft,
            foreground: AppColors.tealDeep,
          ),
        if (onDelete != null)
          _actionButton(
            key: const Key('job-delete-entry'),
            icon: Icons.delete_outline,
            label: '删除岗位',
            onPressed: onDelete,
            background: AppColors.dangerSoft,
            foreground: AppColors.error,
          ),
      ];
      if (narrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, button) in buttons.indexed) ...[
              if (index > 0) const SizedBox(height: 10),
              button,
            ],
          ],
        );
      }
      return Row(
        children: [
          for (final (index, button) in buttons.indexed) ...[
            if (index > 0) const SizedBox(width: 10),
            Expanded(child: button),
          ],
        ],
      );
    },
  );

  Widget _actionButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color background,
    required Color foreground,
  }) => FilledButton.icon(
    key: key,
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      backgroundColor: background,
      foregroundColor: foreground,
      elevation: 0,
      disabledBackgroundColor: background.withValues(alpha: .55),
      disabledForegroundColor: foreground.withValues(alpha: .55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    icon: Icon(icon, size: 18),
    label: Text(
      label,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  );

  /// 两列信息字段：线性图标 + 浅灰标签 + 深灰取值，长文本自动换行。
  Widget _infoField(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.body,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  /// 资料卡高亮项：发布日期、投递人数以浅青绿标签突出展示。
  Widget _highlightChip({
    required Key key,
    required IconData icon,
    required String label,
  }) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.tealSoft,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.tealDeep),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.tealDeep,
          ),
        ),
      ],
    ),
  );

  /// 白色圆角卡片：14-18px 圆角 + 轻微阴影，卡片间统一间距。
  Widget _section(String? title, List<Widget> children, {IconData? icon}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x121A3C6E),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Icon(icon ?? Icons.circle_outlined, size: 20, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.brand,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            ...children,
          ],
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
          _bulletGroup('工作职责', duties),
          const SizedBox(height: 12),
          _bulletGroup('任职要求', requirements),
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

  /// 浅色背景子区域：青绿强调线标题 + 项目符号正文，长文本自动换行。
  Widget _bulletGroup(String title, List<String> lines) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF7FAFB),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFEAF0F4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.body,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (lines.isEmpty)
          const Text(
            '未提供',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          )
        else
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '•  ',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(
                        color: AppColors.body,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    ),
  );

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
        message: '发布岗位时配置技能后，刷新即可展示',
        actionLabel: '刷新',
        onAction: onReloadProfile,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills
          .map(
            (skill) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.tealSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${skill['name']} · ${jobSkillLabel(skill['required'])}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.tealDeep,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
