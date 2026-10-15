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
  int? get applicants {
    final value = int.tryParse('${job['applicantCount']}');
    return value != null && value >= 0 ? value : null;
  }

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

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      1 => ('在招', AppColors.success, AppColors.interactiveSoft),
      0 => ('已下线', AppColors.textMuted, AppColors.background),
      2 => ('暂停', AppColors.warning, AppColors.warningSoft),
      _ => ('状态未知', AppColors.textMuted, AppColors.background),
    };
    final count = applicants;
    final showBadge = count != null && count > 0;
    final badgeSize = count == null || count < 10
        ? 18.0
        : count < 100
        ? 20.0
        : 24.0;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Card(
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
                      children: [
                        Expanded(
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
                        if (count != null && count > 0)
                          const SizedBox(width: 28),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            salary,
                            style: const TextStyle(
                              color: AppColors.accentOrange,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: background,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(color: color, fontSize: 12),
                          ),
                        ),
                      ],
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
                      const SizedBox(height: 12),
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
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton(
                        key: ValueKey('job-status-$id'),
                        onPressed:
                            changing ||
                                id == null ||
                                !const [0, 1, 2].contains(status)
                            ? null
                            : onToggle,
                        child: Text(
                          changing
                              ? '处理中…'
                              : status == 1
                              ? '下线'
                              : '上线',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.hairline,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showBadge)
          Positioned(
            top: 0,
            right: 0,
            child: Semantics(
              container: true,
              label: '累计投递 $count 人，查看求职者',
              button: true,
              onTap: id == null ? null : onApplicants,
              excludeSemantics: true,
              child: InkWell(
                key: ValueKey('job-applicants-$id'),
                onTap: id == null ? null : onApplicants,
                excludeFromSemantics: true,
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        key: ValueKey('job-applicants-circle-$id'),
                        width: badgeSize,
                        height: badgeSize,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.error,
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                            color: AppColors.canvas,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
