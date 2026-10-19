import 'dart:convert';

/// Each remote section retains its own data, error and request generation.
class JobSectionState<T> {
  JobSectionState({this.data, this.loading = true, this.error});
  T? data;
  bool loading;
  String? error;
  int request = 0;
}

int? jobPositiveId(Object? raw) {
  final id = int.tryParse('$raw');
  return id != null && id > 0 ? id : null;
}

String jobValue(Object? raw, {String fallback = '未填写'}) {
  final value = raw?.toString().trim() ?? '';
  return value.isEmpty ? fallback : value;
}

num? jobScore(Object? raw) {
  final value = num.tryParse('$raw');
  return value != null && value.isFinite ? value : null;
}

List<Map<String, dynamic>> jobMaps(Object? raw, String field) {
  if (raw is! List || raw.any((row) => row is! Map)) {
    throw FormatException('$field数据格式不正确');
  }
  return List.unmodifiable(
    raw.map(
      (row) => Map<String, dynamic>.unmodifiable(
        Map<String, dynamic>.from(row as Map),
      ),
    ),
  );
}

Map<String, dynamic> jobObject(Object? raw, String field) {
  if (raw is! Map) {
    throw FormatException('$field数据格式不正确');
  }
  return Map<String, dynamic>.from(raw);
}

class JobDetailViewData {
  JobDetailViewData._(this.job, this.candidates, this.funnel, this.stages);

  factory JobDetailViewData.fromJson(Map<String, dynamic> data) {
    final job = jobObject(data['job'], '岗位');
    if (jobPositiveId(job['posId']) == null) {
      throw const FormatException('岗位数据缺少有效ID');
    }
    return JobDetailViewData._(
      Map.unmodifiable(job),
      jobMaps(data['candidates'], '求职者'),
      Map.unmodifiable(
        jobObject(data['funnel'] ?? <String, dynamic>{}, '投递概览'),
      ),
      jobMaps(data['stages'] ?? <Object>[], '阶段'),
    );
  }

  final Map<String, dynamic> job;
  final List<Map<String, dynamic>> candidates;
  final Map<String, dynamic> funnel;
  final List<Map<String, dynamic>> stages;
  bool get tooManyCandidates => candidates.length > 100;

  Map<String, dynamic> get description {
    final raw = job['jdJson'];
    if (raw == null || raw == '') {
      return const {};
    }
    return jobObject(raw is String ? jsonDecode(raw) : raw, '岗位描述');
  }
}

List<String> jobLines(Object? raw) {
  if (raw == null) {
    return const [];
  }
  if (raw is! List || raw.any((item) => item is! String)) {
    throw const FormatException('岗位正文格式不正确');
  }
  return List.unmodifiable(
    raw
        .cast<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty),
  );
}

String jobSalary(Map<String, dynamic> job) {
  final min = jobScore(job['salaryMin']);
  final max = jobScore(job['salaryMax']);
  if (min == null && max == null) {
    return '薪资面议';
  }
  return '¥${min ?? '未填写'} – ${max ?? '未填写'} / 月';
}

List<Map<String, dynamic>> jobProfileSkills(Map<String, dynamic> data) {
  final profile = data['jdProfile'];
  if (profile != null && profile is! Map) {
    throw const FormatException('JD画像格式不正确');
  }
  final raw = data['skills'];
  if (raw is List && raw.isNotEmpty) {
    final skills = jobMaps(raw, '技能');
    if (skills.any(
      (skill) =>
          skill['name'] is! String || (skill['name'] as String).trim().isEmpty,
    )) {
      throw const FormatException('技能名称格式不正确');
    }
    return skills;
  }
  if (raw != null && raw is! List) {
    throw const FormatException('技能格式不正确');
  }
  final legacy = profile is Map ? profile['skills'] : null;
  if (legacy is List && legacy.every((item) => item is String)) {
    return List.unmodifiable(
      legacy
          .cast<String>()
          .where((name) => name.trim().isNotEmpty)
          .map((name) => {'name': name, 'required': null}),
    );
  }
  return const [];
}

String jobSkillLabel(Object? value) => switch (int.tryParse('$value')) {
  1 => '必备',
  0 => '加分',
  _ => '未注明',
};

class JobRankedCandidate {
  const JobRankedCandidate(
    this.candidate,
    this.score,
    this.resultScore,
    this.originalIndex,
  );
  final Map<String, dynamic> candidate;
  final num? score;
  final num? resultScore;
  final int originalIndex;
}

/// The detail response is the only source of membership and original order.
List<JobRankedCandidate> rankJobCandidates(
  List<Map<String, dynamic>> candidates,
  List<Map<String, dynamic>> results,
) {
  final byId = <int, Map<String, dynamic>>{};
  for (final result in results) {
    final id = jobPositiveId(result['resultId']);
    if (id != null) {
      byId.putIfAbsent(id, () => result);
    }
  }
  final ranked = <JobRankedCandidate>[];
  for (var index = 0; index < candidates.length; index++) {
    final candidate = candidates[index];
    final score = jobScore(
      byId[jobPositiveId(candidate['talId'])]?['totalScore'],
    );
    ranked.add(
      JobRankedCandidate(
        candidate,
        score ?? jobScore(candidate['matchScore']),
        score,
        index,
      ),
    );
  }
  ranked.sort((a, b) {
    if (a.score == null && b.score != null) {
      return 1;
    }
    if (a.score != null && b.score == null) {
      return -1;
    }
    final comparison = a.score == null ? 0 : b.score!.compareTo(a.score!);
    return comparison == 0
        ? a.originalIndex.compareTo(b.originalIndex)
        : comparison;
  });
  return List.unmodifiable(ranked);
}

/// Reconstructs the existing save API's flat stage fields, preserving config.
Map<String, Object?> jobWorkflowSaveBody(Map<String, dynamic> data) {
  final template = data['template'] == null
      ? <String, dynamic>{}
      : jobObject(data['template'], '流程模板');
  final stages = jobMaps(data['stages'], '招聘流程');
  return {
    'templateName': template['name']?.toString() ?? '岗位招聘流程',
    'stages': stages.map((stage) {
      final raw = stage['configJson'];
      final config = raw == null || raw == ''
          ? <String, dynamic>{}
          : jobObject(raw is String ? jsonDecode(raw) : raw, '阶段配置');
      return <String, Object?>{
        ...config,
        'name': stage['name']?.toString() ?? '',
        'type': int.tryParse('${stage['type']}') ?? 3,
        'required':
            stage['required'] == true ||
            '${stage['required']}' == '1' ||
            '${stage['required']}' == 'true',
        'threshold': int.tryParse('${stage['threshold']}') ?? 70,
      };
    }).toList(),
  };
}
