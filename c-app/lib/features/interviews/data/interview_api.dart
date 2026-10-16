import '../../../core/formatters/backend_date.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/interview_schedule.dart';

class InterviewApi {
  const InterviewApi(this.client);
  final ApiClient client;

  Future<List<InterviewSchedule>> schedule(String token, DateTime month) async {
    final query = Uri(
      queryParameters: {
        'from': dateKey(DateTime(month.year, month.month, 1)),
        'to': dateKey(DateTime(month.year, month.month + 1, 1)),
      },
    ).query;
    final response = await client.get(
      '/system/conference/schedule?$query',
      token: token,
    );
    final data = response['data'];
    if (data is! List) throw const ApiException('面试日程格式不正确，请重试');
    return data.map((item) {
      if (item is! Map) throw const ApiException('面试日程格式不正确，请重试');
      return InterviewSchedule.fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }

  Future<InterviewDetail> detail(String token, int sessionId) async {
    final response = await client.get(
      '/system/conference/session/$sessionId',
      token: token,
    );
    final data = response['data'];
    if (data is! Map) throw const ApiException('面试详情格式不正确，请重试');
    return InterviewDetail.fromJson(Map<String, dynamic>.from(data));
  }
}
