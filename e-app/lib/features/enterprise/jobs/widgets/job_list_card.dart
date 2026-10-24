import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

class JobListCard extends StatelessWidget {
  const JobListCard({
    super.key,
    required this.job,
    required this.onOpen,
    required this.onApplicants,
    required this.onToggle,
    this.changing = false,
  });

  final Map<String, dynamic> job;
  final VoidCallback onOpen;
  final VoidCallback onApplicants;
  final VoidCallback onToggle;
  final bool changing;

  int? get id => int.tryParse('${job['posId']}');
  int? get status => int.tryParse('${job['status']}');
  String text(Object? value, String fallback) =>
      value?.toString().trim().isNotEmpty == true
      ? value.toString().trim()
      : fallback;
  int? _count(Iterable<String> keys) {
    for (final key in keys) {
      if (!job.containsKey(key) || job[key] == null) continue;
      final value = int.tryParse('${job[key]}');
      if (value != null && value >= 0) return value;
    }
    return null;
  }

  int? get applicants => _count(['applicantCount']);
  int? get views => _count(['viewCount', 'views', 'browseCount']);
  int? get interests =>
      _count(['favoriteCount', 'collectCount', 'interestCount']);

  String _displayCount(int? value) => value == null ? '—' : '$value';

  String get _statusLabel => switch (status) {
    1 => '在招',
    0 => '停招',
    2 => '暂停',
    _ => '状态未知',
  };

  String get salary {
    num? amount(Object? raw) {
      final value = num.tryParse('$raw');
      return value != null && value.isFinite && value > 0 ? value : null;
    }

    String k(num value) =>
        (value / 1000).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
    final low = amount(job['salaryMin']);
    final high = amount(job['salaryMax']);
    if (low == null && high == null) return '面议';
    if (high == null) return '${k(low!)}K起·月薪';
    if (low == null) return '${k(high)}K以内·月薪';
    return '${k(low)}-${k(high)}K·月薪';
  }

  List<String> get tags {
    const education = {1: '中专', 2: '大专', 3: '本科', 4: '硕士', 5: '博士'};
    Object? jd = job['jdJson'];
    if (jd is String) {
      try {
        jd = jsonDecode(jd);
      } on FormatException {
        jd = null;
      }
    }
    final skills = <String>{};
    if (jd is Map && jd['skills'] is List) {
      for (final item in jd['skills'] as List) {
        if (item is String && item.trim().isNotEmpty) {
          skills.add(item.trim());
        }
      }
    }
    return [
      ?education[int.tryParse('${job['education']}')],
      if (text(job['experience'], '').isNotEmpty) text(job['experience'], ''),
      ...skills.take(2),
    ];
  }

  Widget _stat(
    String label,
    int? value,
    String name, {
    bool clickable = false,
  }) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _displayCount(value),
          key: ValueKey('job-stat-$name-$id'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
    final description = value == null ? '$label统计暂未提供' : '$label $value 人';
    return Expanded(
      child: Semantics(
        label: clickable ? '$description，查看求职者' : description,
        button: clickable,
        excludeSemantics: true,
        child: Tooltip(
          message: description,
          child: clickable
              ? InkWell(
                  key: ValueKey('job-applicants-$id'),
                  onTap: id == null || value == null ? null : onApplicants,
                  borderRadius: BorderRadius.circular(4),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 46),
                    child: Center(child: content),
                  ),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 46),
                  child: Center(child: content),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('job-list-card-$id'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('job-open-$id'),
        onTap: id == null ? null : onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      text(job['title'], '未命名岗位'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Row(
                      key: ValueKey('job-statistics-$id'),
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _stat('看过', views, 'views'),
                        _stat('投递过', applicants, 'applicants', clickable: true),
                        _stat('感兴趣', interests, 'interests'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          salary,
                          style: const TextStyle(
                            color: AppColors.accentOrange,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${text(job['dept'], '部门未填写')} · ${text(job['city'], '城市未填写')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in tags)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.interactiveSoft,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.interactive,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    key: ValueKey('job-status-$id'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(68, 46),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      backgroundColor: status == 1
                          ? AppColors.success
                          : AppColors.hairline,
                      foregroundColor: status == 1
                          ? AppColors.canvas
                          : AppColors.textSecondary,
                      disabledBackgroundColor: status == 1
                          ? AppColors.success.withValues(alpha: .55)
                          : AppColors.hairline,
                      disabledForegroundColor: status == 1
                          ? AppColors.canvas
                          : AppColors.textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed:
                        changing ||
                            id == null ||
                            !const [0, 1, 2].contains(status)
                        ? null
                        : onToggle,
                    child: Text(changing ? '处理中…' : _statusLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
