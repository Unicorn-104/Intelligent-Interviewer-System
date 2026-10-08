class AppResume {
  AppResume({
    this.resumeId,
    this.resumeName = '',
    this.jobDirection = '',
    this.isDefault = false,
    this.updatedAt,
    this.completeness = 0,
    List<ResumeEducation>? educations,
    List<ResumeWork>? works,
    List<ResumeProject>? projects,
    List<ResumeSkill>? skills,
  }) : educations = educations ?? [],
       works = works ?? [],
       projects = projects ?? [],
       skills = skills ?? [];

  int? resumeId;
  String resumeName;
  String jobDirection;
  bool isDefault;
  DateTime? updatedAt;
  int completeness;
  List<ResumeEducation> educations;
  List<ResumeWork> works;
  List<ResumeProject> projects;
  List<ResumeSkill> skills;

  factory AppResume.fromJson(Map<String, dynamic> json) => AppResume(
    resumeId: _int(json['resumeId']),
    resumeName: json['resumeName']?.toString() ?? '',
    jobDirection: json['jobDirection']?.toString() ?? '',
    isDefault: _bool(json['isDefault']),
    updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    completeness: _int(json['completeness']) ?? 0,
    educations: _maps(json['educations']).map(ResumeEducation.fromJson).toList(),
    works: _maps(json['works']).map(ResumeWork.fromJson).toList(),
    projects: _maps(json['projects']).map(ResumeProject.fromJson).toList(),
    skills: _maps(json['skills']).map(ResumeSkill.fromJson).toList(),
  );

  Map<String, dynamic> toJson() => {
    'resumeName': resumeName.trim(),
    'jobDirection': _text(jobDirection),
    'isDefault': isDefault,
    'educations': educations.map((item) => item.toJson()).toList(),
    'works': works.map((item) => item.toJson()).toList(),
    'projects': projects.map((item) => item.toJson()).toList(),
    'skills': skills.map((item) => item.toJson()).toList(),
  };
}

class ResumeEducation {
  ResumeEducation({this.school = '', this.major = '', this.degree = 3, this.startDate, this.endDate, this.gpa, this.description = ''});
  String school;
  String major;
  int degree;
  DateTime? startDate;
  DateTime? endDate;
  double? gpa;
  String description;
  factory ResumeEducation.fromJson(Map<String, dynamic> json) => ResumeEducation(
    school: json['school']?.toString() ?? '', major: json['major']?.toString() ?? '',
    degree: _int(json['degree']) ?? 3, startDate: _date(json['startDate']), endDate: _date(json['endDate']),
    gpa: double.tryParse(json['gpa']?.toString() ?? ''), description: json['description']?.toString() ?? '',
  );
  Map<String, dynamic> toJson() => {'school': school.trim(), 'major': _text(major), 'degree': degree, 'startDate': _dateText(startDate), 'endDate': _dateText(endDate), 'gpa': gpa, 'description': _text(description)};
}

class ResumeWork {
  ResumeWork({this.company = '', this.position = '', this.department = '', this.startDate, this.endDate, this.current = false, this.salaryRange = '', this.description = ''});
  String company;
  String position;
  String department;
  DateTime? startDate;
  DateTime? endDate;
  bool current;
  String salaryRange;
  String description;
  factory ResumeWork.fromJson(Map<String, dynamic> json) => ResumeWork(
    company: json['company']?.toString() ?? '', position: json['position']?.toString() ?? '', department: json['department']?.toString() ?? '',
    startDate: _date(json['startDate']), endDate: _date(json['endDate']), current: _bool(json['current']),
    salaryRange: json['salaryRange']?.toString() ?? '', description: json['description']?.toString() ?? '',
  );
  Map<String, dynamic> toJson() => {'company': company.trim(), 'position': position.trim(), 'department': _text(department), 'startDate': _dateText(startDate), 'endDate': current ? null : _dateText(endDate), 'current': current, 'salaryRange': _text(salaryRange), 'description': _text(description)};
}

class ResumeProject {
  ResumeProject({this.name = '', this.role = '', this.startDate, this.endDate, this.description = '', this.techStack = ''});
  String name;
  String role;
  DateTime? startDate;
  DateTime? endDate;
  String description;
  String techStack;
  factory ResumeProject.fromJson(Map<String, dynamic> json) => ResumeProject(
    name: json['name']?.toString() ?? '', role: json['role']?.toString() ?? '', startDate: _date(json['startDate']), endDate: _date(json['endDate']),
    description: json['description']?.toString() ?? '', techStack: json['techStack']?.toString() ?? '',
  );
  Map<String, dynamic> toJson() => {'name': name.trim(), 'role': _text(role), 'startDate': _dateText(startDate), 'endDate': _dateText(endDate), 'description': _text(description), 'techStack': _text(techStack)};
}

class ResumeSkill {
  ResumeSkill({this.name = '', this.level = 2});
  String name;
  int level;
  factory ResumeSkill.fromJson(Map<String, dynamic> json) => ResumeSkill(name: json['name']?.toString() ?? '', level: _int(json['level']) ?? 2);
  Map<String, dynamic> toJson() => {'name': name.trim(), 'level': level};
}

List<Map<String, dynamic>> _maps(Object? value) => value is List ? value.whereType<Map>().map((item) => item.map((key, value) => MapEntry(key.toString(), value))).toList() : [];
int? _int(Object? value) => value is int ? value : int.tryParse(value?.toString() ?? '');
bool _bool(Object? value) => value == true || value == 1 || value?.toString() == '1' || value?.toString() == 'true';
DateTime? _date(Object? value) => DateTime.tryParse(value?.toString() ?? '');
String? _text(String? value) { final text = value?.trim(); return text == null || text.isEmpty ? null : text; }
String? _dateText(DateTime? value) => value == null ? null : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
