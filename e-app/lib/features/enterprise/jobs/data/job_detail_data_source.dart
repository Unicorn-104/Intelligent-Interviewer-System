import '../../../../api/jd_api.dart' as jd;
import '../../../../api/jobs_api.dart' as jobs;
import '../../../../api/schedule_api.dart' as schedule;
import '../../../../api/screening_api.dart' as screening;
import '../../../../core/network/api_exception.dart';

/// An injectable adapter over existing APIs. Reading never starts screening.
class JobDetailDataSource {
  const JobDetailDataSource();

  Future<Map<String, dynamic>> loadDetail(int id) => jobs.getJobDetail(id);
  Future<Map<String, dynamic>> loadProfile(int id) => jd.getJdProfile(id);
  Future<Map<String, dynamic>> loadWorkflow(int id) => jobs.getJobWorkflow(id);
  Future<List<Map<String, dynamic>>> loadScores(int id) =>
      screening.getScreeningResults(id);
  Future<Map<String, dynamic>> startScreening(int id) =>
      screening.createScreeningTask(positionId: id);
  Future<void> parseJd(int id, String text) async {
    await jd.parseJdProfile(positionId: id, jdText: text);
  }

  Future<void> saveWorkflow(int id, Map<String, Object?> body) =>
      jobs.saveJobWorkflow(id, body);
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
