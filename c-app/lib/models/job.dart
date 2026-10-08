import 'package:flutter/material.dart';

class Job {
  const Job({
    required this.positionId,
    required this.title,
    required this.company,
    required this.city,
    required this.salaryMin,
    required this.salaryMax,
    required this.experience,
    required this.education,
    required this.match,
    required this.tags,
    this.companyVerified = false,
    this.description,
    this.applied = false,
  });

  final int positionId;
  final String title;
  final String company;
  final String city;
  final double? salaryMin;
  final double? salaryMax;
  final String experience;
  final int? education;
  final int match;
  final List<String> tags;
  final bool companyVerified;
  final String? description;
  final bool applied;

  factory Job.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    return Job(
      positionId: _asInt(json['positionId']),
      title: json['title']?.toString() ?? '未命名岗位',
      company: json['company']?.toString() ?? '企业信息待完善',
      city: json['city']?.toString() ?? '城市不限',
      salaryMin: _asDouble(json['salaryMin']),
      salaryMax: _asDouble(json['salaryMax']),
      experience: json['experience']?.toString() ?? '经验不限',
      education: _asNullableInt(json['education']),
      match: _asInt(json['matchScore']).clamp(0, 100),
      tags: rawTags is List
          ? rawTags.map((value) => value.toString()).toList()
          : const [],
      companyVerified: _asInt(json['companyVerified']) == 1,
      description: _nullableText(json['description']),
      applied: json['applied'] == true || _asInt(json['applied']) == 1,
    );
  }

  Job copyWith({bool? applied}) => Job(
    positionId: positionId,
    title: title,
    company: company,
    city: city,
    salaryMin: salaryMin,
    salaryMax: salaryMax,
    experience: experience,
    education: education,
    match: match,
    tags: tags,
    companyVerified: companyVerified,
    description: description,
    applied: applied ?? this.applied,
  );

  String get salary {
    if (salaryMin == null && salaryMax == null) return '薪资面议';
    final min = salaryMin == null ? null : (salaryMin! / 1000).round();
    final max = salaryMax == null ? null : (salaryMax! / 1000).round();
    if (min != null && max != null) return '$min–${max}K';
    if (min != null) return '${min}K 起';
    return '最高 ${max}K';
  }

  String get educationLabel => switch (education) {
    1 => '中专',
    2 => '大专',
    3 => '本科',
    4 => '硕士',
    5 => '博士',
    _ => '学历不限',
  };

  Color get accent {
    if (match >= 90) return const Color(0xFF7A3DFF);
    if (match >= 80) return const Color(0xFF3B89FF);
    return const Color(0xFFFF6B00);
  }
}

class ApplicationSummary {
  const ApplicationSummary({
    required this.applicationId,
    required this.title,
    required this.company,
    required this.statusLabel,
    required this.progress,
  });

  final int applicationId;
  final String title;
  final String company;
  final String statusLabel;
  final double progress;

  factory ApplicationSummary.fromJson(Map<String, dynamic> json) {
    return ApplicationSummary(
      applicationId: _asInt(json['applicationId']),
      title: json['title']?.toString() ?? '岗位',
      company: json['company']?.toString() ?? '企业',
      statusLabel: json['statusLabel']?.toString() ?? '处理中',
      progress: _asInt(json['progress']).clamp(0, 100) / 100,
    );
  }
}

class HomeFeed {
  const HomeFeed({
    required this.newOpportunityCount,
    required this.highMatchCount,
    required this.jobs,
    required this.applications,
  });

  final int newOpportunityCount;
  final int highMatchCount;
  final List<Job> jobs;
  final List<ApplicationSummary> applications;

  factory HomeFeed.fromJson(Map<String, dynamic> json) {
    return HomeFeed(
      newOpportunityCount: _asInt(json['newOpportunityCount']),
      highMatchCount: _asInt(json['highMatchCount']),
      jobs: _readList(json['recommendations'], Job.fromJson),
      applications: _readList(
        json['applications'],
        ApplicationSummary.fromJson,
      ),
    );
  }
}

List<T> _readList<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) return [];
  return value
      .whereType<Map>()
      .map((item) => parse(Map<String, dynamic>.from(item)))
      .toList();
}

int _asInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asNullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

double? _asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String? _nullableText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
