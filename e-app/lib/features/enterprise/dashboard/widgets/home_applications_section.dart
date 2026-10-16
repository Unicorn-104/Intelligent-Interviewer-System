import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../home_models.dart';

class HomeApplicationRow extends StatelessWidget {
  const HomeApplicationRow({
    super.key,
    required this.application,
    required this.onOpen,
    this.companyName,
  });

  final HomeApplication application;
  final VoidCallback onOpen;
  final String? companyName;

  String get _salary {
    num? amount(Object? raw) {
      final value = num.tryParse('$raw');
      return value != null && value.isFinite && value > 0 ? value : null;
    }

    final minimum = amount(application.raw['salaryMin']);
    final maximum = amount(application.raw['salaryMax']);
    String thousands(num value) =>
        (value / 1000).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
    if (minimum == null && maximum == null) return '面议';
    if (maximum == null) return '${thousands(minimum!)}K起·月薪';
    if (minimum == null) return '${thousands(maximum)}K以内·月薪';
    return '${thousands(minimum)}-${thousands(maximum)}K·月薪';
  }

  List<String> get _tags {
    const educationLabels = {1: '中专', 2: '大专', 3: '本科', 4: '硕士', 5: '博士'};
    final education =
        educationLabels[int.tryParse('${application.raw['education']}')];
    final experience = homeText(application.raw['experience'], '');
    final skills = <String>{};
    final rawJd = application.raw['jdJson'];
    Object? jd = rawJd;
    if (rawJd is String && rawJd.trim().isNotEmpty) {
      try {
        jd = jsonDecode(rawJd);
      } on FormatException {
        jd = null;
      }
    }
    if (jd is Map && jd['skills'] is List) {
      for (final value in jd['skills'] as List) {
        if (value is String && value.trim().isNotEmpty) {
          skills.add(value.trim());
        }
      }
    }
    return [
      ?education,
      if (experience.isNotEmpty) experience,
      ...skills.take(2),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final company = companyName?.trim() ?? '';
    final tags = _tags;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('home-job-${application.positionId}'),
        onTap: application.positionId == null ? null : onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        application.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * .55,
                      ),
                      child: Text(
                        _salary,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentOrange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                company.isEmpty
                    ? application.department
                    : '$company · ${application.department}',
                maxLines: 1,
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
                          vertical: 2,
                          horizontal: 8,
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
              const Divider(height: 1, thickness: 1, color: AppColors.hairline),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final count = Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: '累计投递 '),
                        TextSpan(
                          text: '${application.applicants ?? '—'}',
                          style: const TextStyle(
                            color: AppColors.interactive,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(text: ' 人'),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  );
                  final detail = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '查看详情',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ],
                  );
                  if (constraints.maxWidth <
                      220 * MediaQuery.textScalerOf(context).scale(1)) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        count,
                        const SizedBox(height: 8),
                        Align(alignment: Alignment.centerRight, child: detail),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: count),
                      const SizedBox(width: 12),
                      detail,
                    ],
                  );
                },
              ),
              if (application.positionId == null) ...[
                const SizedBox(height: 8),
                const Text(
                  '岗位编号暂不可用',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
