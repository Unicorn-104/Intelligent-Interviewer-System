/// 企业 APP - 模块五（面试执行与级联评估）：HR 终审接口。
///
/// 依据《业务功能分析》UC-12（多模式 AI 面试执行与级联评估）步骤 7-10、
/// UC-15（级联面试自动流转）。
///
/// P7 联调状态：已对接真实后端接口（InterviewReviewController）
/// 请求统一走 lib/core/network/enterprise_api_client.dart。
library;

import '../../core/network/enterprise_api_client.dart';

/// UC-12 步骤7：HR 待终审列表。
/// 已对接：GET /enterprise/review/list（TableDataInfo 解包 rows）
/// status：0-未审核，1-已确认，2-已修改（HR 审核状态枚举）
Future<List<Map<String, dynamic>>> listPendingReviews({
  int? status,
  int pageNum = 1,
  int pageSize = 20,
}) async {
  final response = await EnterpriseApiClient().get(
    '/enterprise/review/list',
    query: {'status': status, 'pageNum': pageNum, 'pageSize': pageSize},
  );
  return (response['rows'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}

/// UC-12 步骤7：评估报告详情（评分卡 + 评语 + 回放链接）。
/// 已对接：GET /enterprise/review/{sessionId}
/// 容错：dimensionScores 为后端解析后的五维评分 Map，可能为 null。
Future<Map<String, dynamic>> getReviewDetail(int sessionId) async {
  final response = await EnterpriseApiClient().get('/enterprise/review/$sessionId');
  final data = Map<String, dynamic>.from(response['data'] as Map? ?? const {});
  data['dimensionScores'] = data['dimensionScores'] ?? const <String, dynamic>{};
  return data;
}

/// UC-12 步骤8-9：终审确认通过（终面 → Offer 流程；非终面 → 级联下一轮）。
/// 已对接：PUT /enterprise/review/{sessionId}/confirm（body {isFinal} 可选）
Future<Map<String, dynamic>> confirmReview(int sessionId, {bool? isFinal}) async {
  final response = await EnterpriseApiClient().put(
    '/enterprise/review/$sessionId/confirm',
    body: {'isFinal': isFinal},
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-12 步骤8：终审调整后通过（HR 修改五维评分后确认）。
/// 已对接：PUT /enterprise/review/{sessionId}/adjust
/// body 直接为五维评分 Map（如 {'技术理论': 93.0, ...}），后端重算综合分。
Future<Map<String, dynamic>> adjustReview(
  int sessionId,
  Map<String, double> dimensionScores,
) async {
  final response = await EnterpriseApiClient().put(
    '/enterprise/review/$sessionId/adjust',
    body: dimensionScores,
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-12 步骤10：终审驳回淘汰（归档人才库 + 感谢信）。
/// 已对接：PUT /enterprise/review/{sessionId}/reject（body {reason} 可选）
Future<Map<String, dynamic>> rejectReview(int sessionId, {String? reason}) async {
  final response = await EnterpriseApiClient().put(
    '/enterprise/review/$sessionId/reject',
    body: {'reason': reason},
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-15：级联流转——非终面通过后触发下一轮面试邀约
/// （后端按级联规则评分阈值判断，达标创建下一轮预约任务）。
/// 已对接：POST /enterprise/review/{sessionId}/cascade
Future<Map<String, dynamic>> triggerCascadeNextRound(int sessionId) async {
  final response = await EnterpriseApiClient().post('/enterprise/review/$sessionId/cascade');
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}
