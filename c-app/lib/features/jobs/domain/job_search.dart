import 'dart:convert';

import '../../../core/network/api_exception.dart';
import '../../../models/job.dart';

/// Only fields confirmed against AgentJobQuery and the PC jobs page.
class JobSearchQuery {
  const JobSearchQuery({
    this.keyword = '',
    this.sort = 'match',
    this.city = '',
    this.category = '',
    this.experienceMin = '',
    this.industry = '',
    this.companySize = '',
    this.positionLabel = '',
  });

  final String keyword,
      sort,
      city,
      category,
      experienceMin,
      industry,
      companySize;
  // PC-only selection label; it is never sent as an API parameter.
  final String positionLabel;

  JobSearchQuery copyWith({
    String? keyword,
    String? sort,
    String? city,
    String? category,
    String? experienceMin,
    String? industry,
    String? companySize,
    String? positionLabel,
  }) => JobSearchQuery(
    keyword: keyword ?? this.keyword,
    sort: sort ?? this.sort,
    city: city ?? this.city,
    category: category ?? this.category,
    experienceMin: experienceMin ?? this.experienceMin,
    industry: industry ?? this.industry,
    companySize: companySize ?? this.companySize,
    positionLabel: positionLabel ?? this.positionLabel,
  );

  Map<String, String> get conditions => {
    if (city.isNotEmpty) 'city': city,
    if (category.isNotEmpty) 'category': category,
    if (experienceMin.isNotEmpty) 'experienceMin': experienceMin,
    if (industry.isNotEmpty) 'industry': industry,
    if (companySize.isNotEmpty) 'companySize': companySize,
  };

  Map<String, String> get selectedConditions => {
    if (city.isNotEmpty) 'city': city,
    if (positionLabel.isNotEmpty || category.isNotEmpty)
      'position': positionLabel.isNotEmpty ? positionLabel : category,
    if (experienceMin.isNotEmpty) 'experienceMin': experienceMin,
    if (industry.isNotEmpty) 'industry': industry,
    if (companySize.isNotEmpty) 'companySize': companySize,
  };

  Map<String, String> parameters(int page, int size) => {
    if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
    ...conditions,
    'sort': sort,
    'page': '$page',
    'size': '$size',
  };

  JobSearchQuery without(String key) => switch (key) {
    'city' => copyWith(city: ''),
    'category' => copyWith(category: '', positionLabel: ''),
    'position' => copyWith(category: '', positionLabel: ''),
    'experienceMin' => copyWith(experienceMin: ''),
    'industry' => copyWith(industry: ''),
    'companySize' => copyWith(companySize: ''),
    _ => this,
  };
}

class JobFilterOptions {
  const JobFilterOptions({
    required this.cities,
    required this.categories,
    required this.experiences,
    required this.industries,
    required this.companySizes,
  });

  final List<String> cities, categories, experiences, industries, companySizes;

  factory JobFilterOptions.fromJson(Map<String, dynamic> json) {
    List<String> values(String key) {
      final value = json[key];
      if (value is! List || value.any((item) => item is! String)) {
        throw const ApiException('筛选选项格式不正确，请重试');
      }
      return List.unmodifiable(
        value.cast<String>().where((s) => s.isNotEmpty).toSet(),
      );
    }

    return JobFilterOptions(
      cities: values('cities'),
      categories: values('categories'),
      experiences: values('experiences'),
      industries: values('industries'),
      companySizes: values('companySizes'),
    );
  }
}

/// Adapter for AgentJob; the /app/jobs model has different field names.
class SearchJobDto {
  SearchJobDto.fromJson(Map<String, dynamic> json) : _json = json {
    if (json['id'] is! num || (json['id'] as num) <= 0) {
      throw const ApiException('职位数据格式不正确，请重试');
    }
  }

  final Map<String, dynamic> _json;

  Job toJob() {
    String? description;
    try {
      final raw = _json['jdJson'];
      final jd = raw is String ? jsonDecode(raw) : raw;
      if (jd is Map && jd['description'] is String) {
        description = jd['description'] as String;
      }
    } on FormatException {
      // The backend also tolerates malformed optional JD JSON.
    }
    final responsibilities = _json['responsibilities'];
    if ((description == null || description.isEmpty) &&
        responsibilities is List) {
      description = responsibilities.whereType<String>().join('\n');
    }
    final score = _json['matchScore'];
    return Job.fromJson({
      'positionId': _json['id'],
      'companyId': _json['companyId'],
      'title': _json['title'],
      'company': _json['companyName'],
      'city': _json['workCity'],
      'salaryMin': _json['salaryMin'],
      'salaryMax': _json['salaryMax'],
      'experience': _json['experienceRequired'],
      'education': _json['educationRequired'],
      'educationText': _json['educationText'],
      'matchScore': score is num ? score.round() : score,
      'tags': _json['skills'],
      'description': description,
      'applied': _json['appliedFlag'],
    });
  }
}

class JobSearchPage {
  const JobSearchPage({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
    required this.hasNext,
  });
  final List<Job> items;
  final int page, size, total;
  final bool hasNext;

  factory JobSearchPage.fromJson(Map<String, dynamic> json) {
    if (json['items'] is! List ||
        json['page'] is! int ||
        json['size'] is! int ||
        json['total'] is! int ||
        json['hasNext'] is! bool ||
        (json['page'] as int) < 1 ||
        (json['size'] as int) < 1 ||
        (json['total'] as int) < 0) {
      throw const ApiException('职位列表格式不正确，请重试');
    }
    final items = (json['items'] as List).map((item) {
      if (item is! Map) throw const ApiException('职位数据格式不正确，请重试');
      return SearchJobDto.fromJson(Map<String, dynamic>.from(item)).toJob();
    }).toList();
    return JobSearchPage(
      items: items,
      page: json['page'] as int,
      size: json['size'] as int,
      total: json['total'] as int,
      hasNext: json['hasNext'] as bool,
    );
  }
}
