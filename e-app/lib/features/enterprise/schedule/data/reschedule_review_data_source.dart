import '../../../../core/network/api_exception.dart';
import '../../../../core/network/enterprise_api_client.dart';

class RescheduleRequest {
  const RescheduleRequest({
    required this.id,
    required this.appointmentId,
    required this.status,
    required this.candidateName,
    required this.positionName,
    required this.originalStart,
    required this.originalEnd,
    required this.newStart,
    required this.newEnd,
    required this.reason,
    required this.requestedAt,
    required this.interviewerName,
    this.reviewNote,
    this.reviewerName,
    this.reviewedAt,
  });

  factory RescheduleRequest.fromJson(Map<String, dynamic> row) {
    int id(String field) {
      final value = int.tryParse('${row[field]}');
      if (value == null || value <= 0) throw const FormatException('改期申请标识无效');
      return value;
    }

    String requiredText(String field) {
      final value = row[field];
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('改期申请数据不完整');
      }
      return value;
    }

    String time(String field) {
      final value = requiredText(field);
      if (!RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?$')
              .hasMatch(value) ||
          DateTime.tryParse(value) == null) {
        throw const FormatException('改期申请时间格式不正确');
      }
      return value.substring(0, 16);
    }

    final status = requiredText('status');
    if (!['pending', 'approved', 'rejected'].contains(status)) {
      throw const FormatException('改期审批状态不正确');
    }
    return RescheduleRequest(
      id: id('requestId'),
      appointmentId: id('appointmentId'),
      status: status,
      candidateName: row['candidateName']?.toString().trim().isNotEmpty == true
          ? row['candidateName'].toString()
          : '未填写姓名',
      positionName: row['positionName']?.toString() ?? '岗位信息缺失',
      originalStart: time('originalStartTime'),
      originalEnd: time('originalEndTime'),
      newStart: time('newStartTime'),
      newEnd: time('newEndTime'),
      reason: requiredText('reason'),
      requestedAt: time('requestedAt'),
      interviewerName: row['interviewerName']?.toString() ?? '未填写姓名',
      reviewNote: row['reviewNote']?.toString(),
      reviewerName: row['reviewerName']?.toString(),
      reviewedAt: row['reviewedAt'] == null ? null : time('reviewedAt'),
    );
  }

  final int id, appointmentId;
  final String status,
      candidateName,
      positionName,
      originalStart,
      originalEnd,
      newStart,
      newEnd,
      reason,
      requestedAt,
      interviewerName;
  final String? reviewNote, reviewerName, reviewedAt;
}

class RescheduleReviewResult {
  const RescheduleReviewResult({required this.rows, required this.total});
  final List<RescheduleRequest> rows;
  final int total;
}

class RescheduleReviewDataSource {
  RescheduleReviewDataSource({EnterpriseApiClient? client})
    : _client = client ?? EnterpriseApiClient();
  final EnterpriseApiClient _client;

  Future<RescheduleReviewResult> load({String? status, int page = 1}) async {
    if (page < 1 ||
        (status != null &&
            !['pending', 'approved', 'rejected'].contains(status))) {
      throw const FormatException('审批筛选参数不正确');
    }
    final response = await _client.get(
      '/enterprise/interview/reschedule-requests',
      query: {'status': status, 'pageNum': page, 'pageSize': 20},
    );
    final rows = response['rows'];
    final total = int.tryParse('${response['total']}');
    if (rows is! List || total == null || total < 0 || total < rows.length) {
      throw const FormatException('审批列表响应格式不正确');
    }
    final parsed = rows.map((row) {
      if (row is! Map) throw const FormatException('审批记录响应格式不正确');
      return RescheduleRequest.fromJson(Map<String, dynamic>.from(row));
    }).toList();
    if (status != null && parsed.any((row) => row.status != status)) {
      throw const FormatException('服务器未应用审批筛选条件');
    }
    return RescheduleReviewResult(rows: parsed, total: total);
  }

  Future<RescheduleRequest> review(
    int id,
    String decision, {
    String? note,
  }) async {
    if (id <= 0 ||
        !['approved', 'rejected'].contains(decision) ||
        (decision == 'rejected' && (note == null || note.trim().isEmpty)) ||
        (note?.runes.length ?? 0) > 500) {
      throw const FormatException('请核对审批决定和说明');
    }
    final response = await _client.put(
      '/enterprise/interview/reschedule-requests/$id/review',
      body: {'decision': decision, 'note': note?.trim()},
    );
    final data = response['data'];
    if (data is! Map) throw const FormatException('审批结果不完整，请刷新核对');
    final result = RescheduleRequest.fromJson(Map<String, dynamic>.from(data));
    if (result.id != id || result.status != decision) {
      throw const FormatException('审批结果不匹配，请刷新核对');
    }
    return result;
  }

  static String errorMessage(Object error) => switch (error) {
    ApiException() when error.isUnauthorized => '登录已失效，请重新登录后查看',
    ApiException() when error.statusCode == 403 || error.code == 403 =>
      '暂无审批权限，请联系企业管理员',
    ApiException() when error.statusCode == 404 || error.code == 404 =>
      '服务器尚未部署改期审批接口',
    ApiException() => error.message,
    FormatException() => error.message,
    _ => '网络异常，请稍后重试',
  };
}
