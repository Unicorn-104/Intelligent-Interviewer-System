import '../../../../api/jobs_api.dart' as jobs;
import '../../../../api/interview_room_api.dart' as rooms;
import '../../../../api/review_api.dart' as review;
import '../../../../api/jd_api.dart' as jd;
import '../../../../api/schedule_api.dart' as schedule;
import '../../../../api/screening_api.dart' as screening;
import '../../../../api/talent_api.dart' as talent;
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/enterprise_api_client.dart';
import '../models/talent_detail_view_data.dart';

class TalentDetailDataSource {
  const TalentDetailDataSource({this.client});
  final EnterpriseApiClient? client;
  Future<Map<String, dynamic>> loadDetail(int id) => talent.getTalentDetail(id);
  Future<Map<String, dynamic>> loadResume(int id) async {
    final data = await talent.getTalentParsedResume(id);
    for (final field in [
      'educationList',
      'workList',
      'projectList',
      'skills',
    ]) {
      if (data[field] != null) {
        talentRows(data[field], field);
      }
    }
    if (data['missingFields'] != null && data['missingFields'] is! List) {
      throw const FormatException('简历缺失字段格式不正确');
    }
    return data;
  }

  Future<TalentMatchData> loadMatch(int id, TalentJobContext context) async {
    final responses = await Future.wait<Object>([
      jobs.getJobDetail(context.positionId),
      jd.getJdProfile(context.positionId),
      screening.getScreeningResults(context.positionId),
    ]);
    return TalentMatchData.fromResponses(
      id,
      responses[0] as Map<String, dynamic>,
      responses[1] as Map<String, dynamic>,
      responses[2] as List<Map<String, dynamic>>,
    );
  }

  Future<Map<String, dynamic>?> loadReport(int id) async {
    try {
      return await screening.getRecommendationReport(id);
    } on ApiException catch (error) {
      if (error.message.startsWith('该候选人暂无 AI 推荐报告')) {
        return null;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> loadGreeting(int id) async {
    try {
      return await screening.getGreetingMessage(id);
    } on ApiException catch (error) {
      if (error.message.startsWith('该候选人暂无个性化招呼语')) {
        return null;
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> loadInterviewers() async {
    final response = await (client ?? EnterpriseApiClient()).get(
      '/system/conference/interviewers',
    );
    final rows = talentRows(response['data'], '面试官列表');
    if (rows.any((row) => talentId(row['userId']) == null) ||
        rows.map((row) => talentId(row['userId'])).toSet().length !=
            rows.length) {
      throw const FormatException('面试官标识无效');
    }
    return rows;
  }

  Future<List<Map<String, dynamic>>> loadJobs({int pageNum = 1}) =>
      jobs.listJobs(status: 1, pageNum: pageNum, pageSize: 20);
  Future<Map<String, dynamic>> loadInterviewReport(int sessionId) =>
      review.getReviewDetail(sessionId);
  Future<Map<String, dynamic>> loadWorkflowSession(int sessionId) =>
      rooms.getSessionContext(sessionId);
  Future<Map<String, dynamic>> loadWorkflow(int positionId) =>
      jobs.getJobWorkflow(positionId);
  Future<List<Map<String, dynamic>>> loadAvailability(int id, {String? to}) =>
      schedule.getInterviewerAvailability(id, to: to);
  Future<Map<String, dynamic>> reschedule(
    int appointmentId, {
    required String newStartTime,
    int? durationMin,
    int? interviewerId,
  }) => schedule.rescheduleInterview(
    appointmentId,
    newStartTime: newStartTime,
    durationMin: durationMin,
    interviewerId: interviewerId,
  );
  Future<List<Map<String, dynamic>>> loadCandidatePlan(
    int candidateId,
    int positionId,
  ) => schedule.getCandidateInterviewPlan(
    candidateId: candidateId,
    positionId: positionId,
  );
  Future<List<Map<String, dynamic>>> inviteStages({
    required int candidateId,
    required int positionId,
    required List<Map<String, Object?>> stages,
  }) => schedule.sendStageInterviewInvites(
    candidateId: candidateId,
    positionId: positionId,
    stages: stages,
  );
  Future<Map<String, dynamic>> invite({
    required int candidateId,
    required int positionId,
    int? stageId,
    required int interviewerId,
    required String startTime,
    required int durationMin,
  }) => schedule.sendInterviewInvite(
    candidateId: candidateId,
    positionId: positionId,
    stageId: stageId,
    interviewerId: interviewerId,
    startTime: startTime,
    durationMin: durationMin,
  );
  Future<List<Map<String, dynamic>>> loadInterviews({
    required int pageNum,
    int pageSize = 50,
    String? from,
    String? to,
  }) => schedule.listInterviews(
    pageNum: pageNum,
    pageSize: pageSize,
    from: from,
    to: to,
  );
}

String talentError(Object error) => switch (error) {
  ApiException() => error.message,
  FormatException() => error.message.toString(),
  _ => '请求失败，请稍后重试',
};
