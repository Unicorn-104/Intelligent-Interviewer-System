import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../models/talent_detail_view_data.dart';
import 'talent_match_analysis_section.dart';

class TalentResumeSection extends StatelessWidget {
  const TalentResumeSection({
    super.key,
    required this.state,
    required this.onRetry,
  });
  final TalentSectionState<Map<String, dynamic>> state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final resume = state.data;
    if (state.loading ||
        state.error != null ||
        resume == null ||
        resume.isEmpty) {
      return TalentSectionFrame(
        title: '',
        ai: true,
        loading: state.loading,
        error: state.error,
        empty: resume == null || resume.isEmpty,
        emptyText: '暂无结构化简历',
        onRetry: onRetry,
      );
    }
    final education =
        (resume['educationList'] as List?)?.whereType<Map>().toList() ??
        const <Map>[];
    final work =
        (resume['workList'] as List?)?.whereType<Map>().toList() ??
        const <Map>[];
    final projects =
        (resume['projectList'] as List?)?.whereType<Map>().toList() ??
        const <Map>[];
    final skills =
        (resume['skills'] as List?)?.whereType<Map>().toList() ?? const <Map>[];
    final missing =
        (resume['missingFields'] as List?)?.map((field) => '$field').toList() ??
        const <String>[];
    final rawIntegrity = talentNumber(resume['integrity']);
    final integrity =
        rawIntegrity != null && rawIntegrity >= 0 && rawIntegrity <= 100
        ? rawIntegrity.round()
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        integrity == null ? '完整度未提供' : '完整度 $integrity%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.bodySoft,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: integrity == null
                            ? const SizedBox.shrink()
                            : LinearProgressIndicator(
                                value: integrity / 100,
                                minHeight: 4,
                                color: AppColors.interactive,
                                backgroundColor: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(3),
                              ),
                      ),
                      const TalentAiInfoButton(),
                    ],
                  ),
                  if (missing.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '缺失：${missing.join('、')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        _ResumeCard(
          title: '教育经历',
          icon: Icons.school_outlined,
          children: education.isEmpty
              ? const [_EmptyHint('暂无教育经历记录')]
              : [
                  for (final item in education)
                    _ResumeEntry(
                      title:
                          '${talentText(item['school'])} · ${talentDegree(item['degree'])}',
                      meta:
                          '${talentText(item['major'])} · ${_period(item['startDate'], item['endDate'])}',
                    ),
                ],
        ),
        _ResumeCard(
          title: '工作经历',
          icon: Icons.work_outline,
          children: work.isEmpty
              ? const [_EmptyHint('暂无工作经历记录')]
              : [
                  for (final item in work)
                    _ResumeEntry(
                      title:
                          '${talentText(item['company'])} · ${talentText(item['position'])}',
                      meta: _period(item['startDate'], item['endDate']),
                      summary: talentText(item['summary'], ''),
                    ),
                ],
        ),
        _ResumeCard(
          title: '项目经验',
          icon: Icons.account_tree_outlined,
          children: projects.isEmpty
              ? const [_EmptyHint('暂无项目经验记录')]
              : [
                  for (final item in projects)
                    _ResumeEntry(
                      title:
                          '${talentText(item['name'])} · ${talentText(item['role'])}',
                      meta: item['techStack'] == null
                          ? ''
                          : '技术栈：${item['techStack']}',
                      summary: talentText(item['summary'], ''),
                    ),
                ],
        ),
        _ResumeCard(
          title: '技能标签',
          icon: Icons.code,
          children: skills.isEmpty
              ? const [_EmptyHint('暂无技能标签记录')]
              : [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final skill in skills)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            [
                              talentText(skill['name']),
                              _levelLabel(skill['level']),
                            ].where((part) => part.isNotEmpty).join('·'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.interactive,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
        ),
      ],
    );
  }
}

String _period(Object? start, Object? end) {
  final from = talentText(start, '时间未填写');
  final to = talentText(end, '时间未填写');
  if (from == to && from == '时间未填写') {
    return from;
  }
  return '$from ~ $to';
}

String _levelLabel(Object? level) => switch (int.tryParse('$level')) {
  1 => '了解',
  2 => '熟悉',
  3 => '精通',
  4 => '专家',
  _ => '',
};

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: AppColors.interactive),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class _ResumeEntry extends StatelessWidget {
  const _ResumeEntry({
    required this.title,
    required this.meta,
    this.summary = '',
  });
  final String title, meta, summary;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.body,
          ),
        ),
        if (meta.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              meta,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        if (summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TalentExpandableText(text: summary),
          ),
      ],
    ),
  );
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 12, color: AppColors.muted));
}
