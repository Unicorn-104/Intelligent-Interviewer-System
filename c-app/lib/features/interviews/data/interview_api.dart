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

  Future<Map<String, dynamic>> submitReschedule(
    String token,
    int appointmentId,
    DateTime newStart,
    String reason,
  ) async {
    if (appointmentId <= 0 ||
        reason.trim().isEmpty ||
        reason.trim().runes.length > 500) {
      throw const ApiException('请填写改期时间和原因');
    }
    final start =
        '${newStart.year.toString().padLeft(4, '0')}-${newStart.month.toString().padLeft(2, '0')}-${newStart.day.toString().padLeft(2, '0')} ${newStart.hour.toString().padLeft(2, '0')}:${newStart.minute.toString().padLeft(2, '0')}';
    final response = await client.post(
      '/candidate/interview/reschedule-requests/$appointmentId',
      token: token,
      body: {'newStartTime': start, 'reason': reason.trim()},
    );
    final data = response['data'];
    if (data is! Map ||
        '${data['status']}' != 'pending' ||
        int.tryParse('${data['appointmentId']}') != appointmentId ||
        (int.tryParse('${data['requestId']}') ?? 0) <= 0) {
      throw const ApiException('申请结果待核对，请刷新申请记录', code: 0);
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>?> findOwnReschedule(
    String token,
    int appointmentId,
  ) async {
    if (appointmentId <= 0) throw const ApiException('面试标识无效');
    for (var page = 1; page <= 1000; page++) {
      final response = await client.get(
        '/candidate/interview/reschedule-requests?pageNum=$page&pageSize=100',
        token: token,
      );
      final rows = response['rows'];
      final total = int.tryParse('${response['total']}');
      if (rows is! List || total == null || total < 0 || total < rows.length) {
        throw const ApiException('申请记录格式不正确，请重试');
      }
      for (final row in rows) {
        if (row is! Map ||
            (int.tryParse('${row['requestId']}') ?? 0) <= 0 ||
            (int.tryParse('${row['appointmentId']}') ?? 0) <= 0 ||
            !['pending', 'approved', 'rejected'].contains(row['status'])) {
          throw const ApiException('申请记录格式不正确，请重试');
        }
        if (int.tryParse('${row['appointmentId']}') == appointmentId) {
          return Map<String, dynamic>.from(row);
        }
      }
      if (page * 100 >= total) return null;
      if (rows.isEmpty) throw const ApiException('申请分页未更新，请重试');
    }
    throw const ApiException('申请记录较多，暂时无法完成核对，请稍后重试');
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
