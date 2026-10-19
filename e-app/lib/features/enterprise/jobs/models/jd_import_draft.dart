/// A typed import result, independent of widget state and publishing requests.
class JdImportDraft {
  const JdImportDraft._({
    required this.title,
    required this.dept,
    required this.city,
    required this.salaryMin,
    required this.salaryMax,
    required this.experience,
    required this.education,
    required this.jobType,
    required this.responsibilities,
    required this.requirements,
    required this.skills,
    required this.summary,
    required this.softRequirements,
    required this.warnings,
  });

  factory JdImportDraft.fromJson(Map<String, dynamic> json) {
    const fields = {
      'title',
      'dept',
      'city',
      'salaryMin',
      'salaryMax',
      'experience',
      'education',
      'jobType',
      'responsibilities',
      'requirements',
      'skills',
      'summary',
      'softRequirements',
      'warnings',
    };
    if (!json.keys.toSet().containsAll(fields)) {
      throw const FormatException('缺少约定的草稿字段');
    }
    final min = _money(json['salaryMin'], 'salaryMin');
    final max = _money(json['salaryMax'], 'salaryMax');
    if (min != null && max != null && min > max) {
      throw const FormatException('最低月薪不得高于最高月薪');
    }
    return JdImportDraft._(
      title: _text(json['title'], 'title', 100),
      dept: _text(json['dept'], 'dept', 50),
      city: _text(json['city'], 'city', 50),
      salaryMin: min,
      salaryMax: max,
      experience: _text(json['experience'], 'experience', 20),
      education: _choice(json['education'], 'education', 1, 5),
      jobType: _choice(json['jobType'], 'jobType', 1, 3),
      responsibilities: _lines(json['responsibilities'], 'responsibilities'),
      requirements: _lines(json['requirements'], 'requirements'),
      skills: _skills(json['skills']),
      summary: _text(json['summary'], 'summary', 200),
      softRequirements: _lines(json['softRequirements'], 'softRequirements'),
      warnings: _lines(
        json['warnings'],
        'warnings',
        itemMax: 500,
        totalMax: 15000,
        preserveWhitespace: true,
      ),
    );
  }

  final String? title;
  final String? dept;
  final String? city;
  final num? salaryMin;
  final num? salaryMax;
  final String? experience;
  final int? education;
  final int? jobType;
  final List<String> responsibilities;
  final List<String> requirements;
  final List<JdImportSkill> skills;
  final String? summary;
  final List<String> softRequirements;
  final List<String> warnings;

  bool get hasSalary => salaryMin != null || salaryMax != null;
  bool get hasPartialSalary => (salaryMin == null) != (salaryMax == null);

  /// Call against the latest form snapshot when the user applies the draft.
  /// Null/empty results preserve current values. A partial salary replaces the
  /// pair together, leaving its missing endpoint empty for manual completion.
  JdImportPatch prepareImport(
    Map<String, Object?> current, {
    bool appendSummary = false,
    bool appendSoftRequirements = false,
  }) {
    final proposed = <String, Object?>{
      if (title != null) 'title': title,
      if (dept != null) 'dept': dept,
      if (city != null) 'city': city,
      if (experience != null) 'experience': experience,
      if (education != null) 'education': education,
      if (jobType != null) 'jobType': jobType,
      if (hasSalary) ...{
        'salaryMin': _moneyText(salaryMin),
        'salaryMax': _moneyText(salaryMax),
      },
      if (responsibilities.isNotEmpty) 'responsibilities': responsibilities,
      if (requirements.isNotEmpty) 'requirements': requirements,
      if (skills.isNotEmpty)
        'skills': List<Map<String, Object?>>.unmodifiable(
          skills.map((skill) => skill.toJson()),
        ),
    };
    if (appendSummary && summary != null) {
      proposed['responsibilities'] = _appendLines(
        proposed['responsibilities'] ?? current['responsibilities'],
        [summary!],
        'responsibilities',
      );
    }
    if (appendSoftRequirements && softRequirements.isNotEmpty) {
      proposed['requirements'] = _appendLines(
        proposed['requirements'] ?? current['requirements'],
        softRequirements,
        'requirements',
      );
    }

    final changes = <String, Object?>{};
    final overwritten = <String>[];
    for (final entry in proposed.entries) {
      if (entry.key == 'salaryMin' || entry.key == 'salaryMax') continue;
      final oldValue = current[entry.key];
      if (_sameValue(oldValue, entry.value)) continue;
      changes[entry.key] = entry.value;
      if (!_empty(oldValue)) overwritten.add(entry.key);
    }
    if (hasSalary &&
        (!_sameMoney(current['salaryMin'], proposed['salaryMin']) ||
            !_sameMoney(current['salaryMax'], proposed['salaryMax']) ||
            current['negotiable'] == true)) {
      changes['salaryMin'] = proposed['salaryMin'];
      changes['salaryMax'] = proposed['salaryMax'];
      if (!_empty(current['salaryMin']) ||
          !_empty(current['salaryMax']) ||
          current['negotiable'] == true) {
        overwritten.add('salary');
      }
    }
    return JdImportPatch._(changes, overwritten);
  }
}

class JdImportSkill {
  const JdImportSkill({required this.name, required this.requiredFlag});

  final String name;
  final int? requiredFlag;

  String get requirementLabel => switch (requiredFlag) {
    1 => '必备',
    0 => '加分',
    _ => '未注明',
  };

  Map<String, Object?> toJson() =>
      Map.unmodifiable({'name': name, 'required': requiredFlag});
}

/// Pure mapping result. Applying it or confirming conflicts belongs to the UI.
class JdImportPatch {
  JdImportPatch._(Map<String, Object?> values, List<String> overwrittenFields)
    : values = Map.unmodifiable(values),
      overwrittenFields = List.unmodifiable(overwrittenFields);

  final Map<String, Object?> values;
  final List<String> overwrittenFields;

  bool get needsOverwriteConfirmation => overwrittenFields.isNotEmpty;
  bool get isEmpty => values.isEmpty;

  List<String> get overwrittenLabels =>
      List.unmodifiable(overwrittenFields.map((field) => fieldLabels[field]!));

  static const fieldLabels = {
    'title': '岗位名称',
    'dept': '所属部门',
    'city': '工作城市',
    'salary': '月薪范围',
    'experience': '经验要求',
    'education': '学历要求',
    'jobType': '工作性质',
    'responsibilities': '工作职责',
    'requirements': '任职要求',
    'skills': '技能标签',
  };
}

String? _text(Object? value, String field, int max) {
  if (value == null) return null;
  if (value is! String || value.trim().length > max) {
    throw FormatException('${JdImportPatch.fieldLabels[field] ?? field}格式无效');
  }
  return value.trim().isEmpty ? null : value.trim();
}

int? _choice(Object? value, String field, int min, int max) {
  if (value == null) return null;
  if (value is! int || value < min || value > max) {
    throw FormatException('${JdImportPatch.fieldLabels[field] ?? field}枚举无效');
  }
  return value;
}

num? _money(Object? value, String field) {
  if (value == null) return null;
  if (value is! num ||
      !value.isFinite ||
      value <= 0 ||
      value >= 100000000 ||
      !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value.toString())) {
    throw FormatException('$field须为有效的元/月金额，最多两位小数');
  }
  return value;
}

String _moneyText(num? value) {
  if (value == null) return '';
  final text = value.toString();
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

List<String> _lines(
  Object? value,
  String field, {
  int itemMax = 1000,
  int totalMax = 10000,
  bool preserveWhitespace = false,
}) {
  if (value is! List || value.length > 30) {
    throw FormatException('$field须为最多30项的文本数组');
  }
  final lines = <String>[];
  var length = 0;
  for (final item in value) {
    if (item is! String || item.trim().isEmpty || item.length > itemMax) {
      throw FormatException('$field包含无效或过长的文本');
    }
    final line = preserveWhitespace ? item : item.trim();
    length += line.length;
    if (length > totalMax) throw FormatException('$field文本总长度超限');
    lines.add(line);
  }
  return List.unmodifiable(lines);
}

List<JdImportSkill> _skills(Object? value) {
  if (value is! List || value.length > 30) {
    throw const FormatException('技能须为最多30项的数组');
  }
  return List.unmodifiable(
    value.map((item) {
      if (item is! Map ||
          !item.containsKey('name') ||
          !item.containsKey('required')) {
        throw const FormatException('技能缺少名称或必备标识');
      }
      final name = _text(item['name'], 'skills.name', 50);
      if (name == null) throw const FormatException('技能名称不能为空');
      return JdImportSkill(
        name: name,
        requiredFlag: _choice(item['required'], 'skills.required', 0, 1),
      );
    }),
  );
}

List<String> _appendLines(Object? current, List<String> extra, String field) {
  final values = current is List
      ? current.whereType<String>().toList()
      : current is String
      ? current
            .split(RegExp(r'\r?\n'))
            .where((line) => line.trim().isNotEmpty)
            .toList()
      : <String>[];
  for (final line in extra) {
    if (!values.any((value) => value.trim() == line.trim())) values.add(line);
  }
  return _lines(values, field);
}

bool _empty(Object? value) =>
    value == null ||
    (value is String && value.trim().isEmpty) ||
    (value is List && value.isEmpty);

bool _sameMoney(Object? first, Object? second) {
  if (_empty(first) || _empty(second)) return _empty(first) && _empty(second);
  final left = num.tryParse('$first');
  final right = num.tryParse('$second');
  return left != null && right != null && left == right;
}

bool _sameValue(Object? first, Object? second) {
  if (first is String && second is String) return first.trim() == second.trim();
  if (first is List && second is List) {
    return first.length == second.length &&
        List.generate(
          first.length,
          (index) => index,
        ).every((index) => _sameValue(first[index], second[index]));
  }
  if (first is Map && second is Map) {
    return first.length == second.length &&
        first.keys.every(
          (key) =>
              second.containsKey(key) && _sameValue(first[key], second[key]),
        );
  }
  return first == second;
}
