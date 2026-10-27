import '../../../../api/jd_api.dart' as jd;
import '../../../../api/jobs_api.dart' as jobs;
import '../../../../api/schedule_api.dart' as schedule;
import '../../../../api/screening_api.dart' as screening;
import '../../../../api/talent_api.dart' as talent;
import '../../../../core/network/api_exception.dart';
import '../../talent/data/talent_detail_data_source.dart';

/// An injectable adapter over existing APIs. Reading never starts screening.
class JobDetailDataSource {
  const JobDetailDataSource();

  TalentDetailDataSource get candidateActionsSource =>
      const TalentDetailDataSource();

  Future<Map<String, dynamic>> loadCandidateResume(int candidateId) =>
      talent.getTalentParsedResume(candidateId);
  Future<Map<String, dynamic>> loadDetail(int id) => jobs.getJobDetail(id);
  Future<Map<String, dynamic>> loadEditingOptions(int id) async {
    final results = await Future.wait([
      jobs.getJobPublishingOptions(),
      jobs.getJobDetail(id),
    ]);
    return {
      ...results[0],
      'job': results[1]['job'],
      'skills': results[1]['skills'],
    };
  }

  Future<Map<String, dynamic>> updateJob(int id, Map<String, Object?> body) =>
      jobs.updateJob(id, body);
  Future<Map<String, dynamic>> loadProfile(int id) => jd.getJdProfile(id);
  Future<Map<String, dynamic>> loadWorkflow(int id) => jobs.getJobWorkflow(id);
  Future<List<Map<String, dynamic>>> loadScores(int id) =>
      screening.getScreeningResults(id);
  Future<Map<String, dynamic>> startScreening(int id) =>
      screening.createScreeningTask(positionId: id);
  Future<Map<String, dynamic>> startFullScreening(int id) =>
      screening.createScreeningTask(positionId: id, fullAnalysis: true);
  Future<Map<String, dynamic>> loadScreeningStatus(int id) =>
      screening.getScreeningTaskStatus(id);
  Future<void> parseJd(int id, String text) async {
    await jd.parseJdProfile(positionId: id, jdText: text);
  }

  Future<void> saveWorkflow(int id, Map<String, Object?> body) =>
      jobs.saveJobWorkflow(id, body);
  Future<void> deleteJob(int id) => jobs.deleteJob(id);
  Future<Map<String, dynamic>> loadCandidatePreview(int id) =>
      jobs.getCandidateJobPreview(id);
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

String jobDetailError(Object error) => switch (error) {
  ApiException() => error.message,
  FormatException() => error.message.toString(),
  _ => '请求失败，请稍后重试',
};
