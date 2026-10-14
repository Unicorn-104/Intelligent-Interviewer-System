import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/features/resume/domain/app_resume.dart';

void main() {
  test('keeps unknown education and skill levels unset for human review', () {
    final resume = AppResume.fromJson({
      'resumeName': '模拟简历',
      'structureMethod': 'AI',
      'unmappedText': '模拟证书信息',
      'parseWarnings': ['原文未提供学历'],
      'educations': [
        {
          'school': '示例大学',
          'degree': null,
          'startDate': '2020-09-01',
          'gpa': 3.5,
        },
      ],
      'skills': [
        {'name': 'Java', 'level': null},
      ],
    });
    expect(resume.educations.single.degree, isNull);
    expect(resume.skills.single.level, isNull);
    expect(resume.educations.single.startDate, DateTime(2020, 9, 1));
    expect(resume.educations.single.gpa, 3.5);
    expect(resume.parseWarnings, ['原文未提供学历']);
    final body = resume.toJson();
    expect((body['educations'] as List).single['degree'], isNull);
    expect((body['skills'] as List).single['level'], isNull);
    expect(body.containsKey('structureMethod'), isFalse);
    expect(body.containsKey('unmappedText'), isFalse);
    expect(body.containsKey('parseWarnings'), isFalse);
  });
}
