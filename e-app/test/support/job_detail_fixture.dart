import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/data/job_detail_data_source.dart';

import 'talent_detail_fixture.dart';

Map<String, dynamic> jobDetailJson({List<Map<String, dynamic>>? candidates}) =>
    {
      'job': {
        'posId': 1,
        'title': 'Java工程师',
        'dept': '研发部',
        'city': '杭州',
        'salaryMin': 18000,
        'salaryMax': 28000,
        'experience': '3-5年',
        'education': 3,
        'jobType': 1,
        'status': 1,
        'date': '2026-10-16',
        'jdJson': '{"responsibilities":["开发接口"],"requirements":["熟悉Java"]}',
      },
      'funnel': {'total': 2, 'passed': 1},
      'candidates':
          candidates ??
          [
            {
              'talId': 11,
              'name': '候选人甲',
              'currentStage': '初筛',
              'statusLabel': '待处理',
              'matchScore': 72,
            },
            {
              'talId': 12,
              'name': '候选人乙',
              'currentStage': '面试',
              'statusLabel': '进行中',
              'matchScore': 65,
            },
          ],
      'stages': [
        {'name': '初筛', 'type': 3, 'sortOrder': 1},
      ],
    };

Map<String, dynamic> profileJson() => {
  'positionId': 1,
  'jdProfile': {
    'summary': '画像摘要',
    'education': '本科',
    'years': '3年',
    'skills': ['Java'],
    'softRequirements': ['协作'],
  },
  'skills': [
    {'name': 'Java', 'required': 1},
    {'name': 'Git', 'required': null},
  ],
};

final class DetailFakeSource extends JobDetailDataSource {
  final actions = TalentFakeSource();
  @override
  TalentFakeSource get candidateActionsSource => actions;
  DetailFakeSource({this.scoreResult = const [], this.scoreFailure = false});
  final List<Map<String, dynamic>> scoreResult;
  final bool scoreFailure;
  int detailCalls = 0;
  int profileCalls = 0;
  int workflowCalls = 0;
  int scoreCalls = 0;
  int screenCalls = 0;
  int scoreCallsAtStart = 0;
  int fullScreenCalls = 0;
  int statusCalls = 0;
  bool asyncScreening = false;
  List<Map<String, dynamic>> screeningStatuses = [];
  int interviewCalls = 0;
  final List<Map<String, Object?>> savedWorkflows = [];

  @override
  Future<Map<String, dynamic>> loadCandidateResume(int id) async => {
    'educationList': [],
  };

  @override
  Future<Map<String, dynamic>> loadDetail(int id) async {
    detailCalls++;
    return jobDetailJson();
  }

  @override
  Future<Map<String, dynamic>> loadProfile(int id) async {
    profileCalls++;
    return profileJson();
  }

  @override
  Future<Map<String, dynamic>> loadWorkflow(int id) async {
    workflowCalls++;
    return {
      'template': {'name': '默认流程'},
      'stages': [
        {
          'name': '初筛',
          'type': 3,
          'required': 1,
          'threshold': 70,
          'configJson': '{"duration":45}',
        },
      ],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> loadScores(int id) async {
    scoreCalls++;
    if (scoreFailure) throw StateError('score failed');
    return scoreResult;
  }

  @override
  Future<Map<String, dynamic>> startScreening(int id) async {
    screenCalls++;
    scoreCallsAtStart = scoreCalls;
    return {
      'taskId': id,
      'candidateCount': 2,
      'passedCount': 1,
      'processing': asyncScreening,
    };
  }

  @override
  Future<Map<String, dynamic>> startFullScreening(int id) async {
    fullScreenCalls++;
    return {'taskId': id, 'candidateCount': 2, 'processing': asyncScreening};
  }

  @override
  Future<Map<String, dynamic>> loadScreeningStatus(int id) async {
    statusCalls++;
    return screeningStatuses.isEmpty
        ? {'taskId': id, 'processing': false, 'state': 'completed'}
        : screeningStatuses.removeAt(0);
  }

  @override
  Future<void> saveWorkflow(int id, Map<String, Object?> body) async {
    savedWorkflows.add(body);
  }

  @override
  Future<List<Map<String, dynamic>>> loadInterviews({
    required int pageNum,
    int pageSize = 50,
    String? from,
    String? to,
  }) async {
    interviewCalls++;
    return [
      {
        'positionId': 1,
        'candidateName': '候选人甲',
        'startTime': '2026-10-20 10:00:00',
      },
    ];
  }

  int previewCalls = 0;
  bool deleteFailure = false;
  final List<int> deletedJobs = [];

  @override
  Future<Map<String, dynamic>> loadCandidatePreview(int id) async {
    previewCalls++;
    return {
      'id': id,
      'title': 'Java工程师',
      'salaryText': '18K-28K·月薪',
      'workCity': '杭州',
      'experienceRequired': '3-5年',
      'educationText': '本科',
      'jobTypeText': '全职',
      'statusText': '在招',
      'responsibilities': ['开发接口', '维护服务'],
      'requirements': ['熟悉Java'],
      'skills': ['Spring'],
      'companyName': '测试企业',
      'companyLogoUrl': '',
      'companyIndustry': '互联网',
      'companySize': '100-499人',
      'companyCity': '杭州',
      'companyAddress': '西湖区',
      'companyIntro': '专注招聘的企业',
    };
  }

  @override
  Future<void> deleteJob(int id) async {
    if (deleteFailure) {
      throw const ApiException('该岗位已有投递、面试等业务数据，无法删除；可将岗位改为停招或下线');
    }
    deletedJobs.add(id);
  }
}
