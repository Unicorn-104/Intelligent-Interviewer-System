/// 企业 APP - 模块三（面试调度与日程）：预约调度接口。
///
/// 依据《业务功能分析》UC-07（候选人自主预约与智能排期）、
/// UC-08（面试官日历同步与冲突检测）、UC-09（候选人自助改期）。
///
/// P7 联调状态：已对接真实后端接口（InterviewScheduleController）
/// 请求统一走 lib/core/network/enterprise_api_client.dart。
///
/// 已知占位（P6 报告标注）：会议链接为模拟值；提醒内容由后端生成。
library;

import '../../core/network/enterprise_api_client.dart';

/// UC-07：面试日程列表（状态/时间范围筛选 + 分页）。
/// 已对接：GET /enterprise/interview/list（TableDataInfo 解包 rows）
Future<List<Map<String, dynamic>>> listInterviews({
  int? status,
  String? from,
  String? to,
  int pageNum = 1,
  int pageSize = 20,
}) async {
  final response = await EnterpriseApiClient().get(
    '/enterprise/interview/list',
    query: {
      'status': status,
      'from': from,
      'to': to,
      'pageNum': pageNum,
      'pageSize': pageSize,
    },
  );
  return (response['rows'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}

/// UC-07：HR 发起面试邀约（生成专属预约链接并通知候选人）。
/// 已对接：POST /enterprise/interview/invite
/// body：{candidateId, positionId, interviewerId, startTime, durationMin}
Future<Map<String, dynamic>> sendInterviewInvite({
  required int candidateId,
  required int positionId,
  int? stageId,
  required int interviewerId,
  required String startTime,
  int durationMin = 45,
}) async {
  final response = await EnterpriseApiClient().post(
    '/enterprise/interview/invite',
    body: {
      'candidateId': candidateId,
      'positionId': positionId,
      ...?stageId == null ? null : {'stageId': stageId},
      'interviewerId': interviewerId,
      'startTime': startTime,
      'durationMin': durationMin,
    },
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-08：面试官日历忙闲状态（冲突检测依据）。
/// 已对接：GET /enterprise/interview/calendar/{interviewerId}
Future<List<Map<String, dynamic>>> getInterviewerAvailability(
  int interviewerId, {
  String? from,
  String? to,
}) async {
  final response = await EnterpriseApiClient().get(
    '/enterprise/interview/calendar/$interviewerId',
    query: {'from': from, 'to': to},
  );
  return (response['data'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}

/// UC-09：面试改期（原时段自动释放回退可用池，新时段原子占用）。
/// 已对接：PUT /enterprise/interview/{appointmentId}/reschedule
/// 入参以实际接口为准：{newStartTime}
Future<Map<String, dynamic>> rescheduleInterview(
  int appointmentId, {
  required String newStartTime,
  int? durationMin,
  int? interviewerId,
}) async {
  final response = await EnterpriseApiClient().put(
    '/enterprise/interview/$appointmentId/reschedule',
    body: {
      'newStartTime': newStartTime,
      ...?durationMin == null ? null : {'durationMin': durationMin},
      ...?interviewerId == null ? null : {'interviewerId': interviewerId},
    },
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-07 步骤11：面试提醒（面试前 24h/1h 催办入口）。
/// 已对接：POST /enterprise/interview/{appointmentId}/remind
/// 注意：提醒内容由后端生成，hoursBefore 仅作客户端语义、不随请求发送。
Future<void> sendInterviewReminder(
  int appointmentId, {
  int? hoursBefore,
}) async {
  await EnterpriseApiClient().post(
    '/enterprise/interview/$appointmentId/remind',
  );
}

/// 多个阶段在同一事务中保存；任一阶段冲突时整批回滚。
Future<List<Map<String, dynamic>>> sendStageInterviewInvites({
  required int candidateId,
  required int positionId,
  required List<Map<String, Object?>> stages,
}) async {
  final response = await EnterpriseApiClient().post(
    '/enterprise/interview/invite/stages',
    body: {
      'candidateId': candidateId,
      'positionId': positionId,
      'stages': stages,
    },
  );
  return (response['data'] as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();
}

Future<List<Map<String, dynamic>>> getCandidateInterviewPlan({
  required int candidateId,
  required int positionId,
}) async {
  final response = await EnterpriseApiClient().get(
    '/enterprise/interview/candidate-plan',
    query: {'candidateId': candidateId, 'positionId': positionId},
  );
  return (response['data'] as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();
}
