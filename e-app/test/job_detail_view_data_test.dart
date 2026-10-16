import 'package:flutter_test/flutter_test.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/models/job_detail_view_data.dart';

import 'support/job_detail_fixture.dart';

void main() {
  test('详情映射保留岗位、职责、技能和 candidates 服务端顺序', () {
    final data = JobDetailViewData.fromJson(
      jobDetailJson(
        candidates: [
          {'talId': 12, 'name': '乙'},
          {'talId': 11, 'name': '甲'},
        ],
      ),
    );
    expect(data.job['title'], 'Java工程师');
    expect(jobLines(data.description['responsibilities']), ['开发接口']);
    expect(data.candidates.map((item) => item['talId']), [12, 11]);
  });

  test('AI 关联只使用同批 candidates，按评分降序且同分保留原序', () {
    final candidates = [
      {'talId': 1, 'name': 'A', 'matchScore': 60},
      {'talId': 2, 'name': 'B', 'matchScore': 60},
      {'talId': 3, 'name': 'C', 'matchScore': 10},
    ];
    final ranked = rankJobCandidates(candidates, [
      {'resultId': 3, 'totalScore': 90},
      {'resultId': 1, 'totalScore': 72},
      {'resultId': 99, 'totalScore': 100},
    ]);
    expect(ranked.map((row) => row.candidate['talId']), [3, 1, 2]);
    expect(ranked.map((row) => row.score), [90, 72, 60]);
  });

  test('流程保存映射保留现有配置字段', () {
    final body = jobWorkflowSaveBody({
      'template': {'name': '流程'},
      'stages': [
        {
          'name': '初筛',
          'type': 3,
          'required': 1,
          'threshold': 70,
          'configJson': '{"duration":45,"mode":"线上"}',
        },
      ],
    });
    final stage = (body['stages'] as List).single as Map;
    expect(stage['duration'], 45);
    expect(stage['mode'], '线上');
    expect(stage['name'], '初筛');
  });

  test('评分为空不被当成错误或候选人为空', () {
    final ranked = rankJobCandidates(
      jobDetailJson()['candidates'] as List<Map<String, dynamic>>,
      const [],
    );
    expect(ranked, hasLength(2));
    expect(ranked.every((row) => row.resultScore == null), isTrue);
  });
}
