/// 企业 APP - 模块二（AI 初筛与短名单）：筛选与匹配接口。
///
/// 依据《业务功能分析》UC-04（硬性条件自动过滤）、
/// UC-05（AI 多维度匹配与评分排序）、UC-06（短名单 HR 复核）。
///
/// P7 联调状态：已对接真实后端接口（ScreeningController）
/// 请求统一走 lib/core/network/enterprise_api_client.dart。
///
/// 已知占位（P6 报告标注）：
/// - 维度明细 projectMatch/educationMatch/industryMatch 为 null（向量服务未接入）；
/// - 任务列表 status 筛选后端暂未实现（传参保留，当前无过滤效果）。
library;

import '../../core/network/enterprise_api_client.dart';

/// UC-04/UC-05 步骤1：触发 AI 初筛任务（硬性过滤 + 多维度匹配）。
/// 已对接：POST /enterprise/screening/tasks
/// 入参以实际接口为准：{positionId, topN}
Future<Map<String, dynamic>> createScreeningTask({
  required int positionId,
  int? topN,
}) async {
  final response = await EnterpriseApiClient().post(
    '/enterprise/screening/tasks',
    body: {'positionId': positionId, 'topN': topN},
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-05 步骤1：筛选任务列表（按岗位聚合）。
/// 已对接：GET /enterprise/screening/tasks
/// 注意：status 筛选后端暂未实现（P6 占位），传参保留但当前无过滤效果。
Future<List<Map<String, dynamic>>> listScreeningTasks({
  int? status,
  int pageNum = 1,
  int pageSize = 20,
}) async {
  final response = await EnterpriseApiClient().get(
    '/enterprise/screening/tasks',
    query: {'status': status, 'pageNum': pageNum, 'pageSize': pageSize},
  );
  return (response['rows'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}

/// UC-05 步骤3-4：匹配度评分列表 + 维度明细（降序）。
/// 已对接：GET /enterprise/screening/tasks/{taskId}/results
/// 注意：projectMatch/educationMatch/industryMatch 为 null（语义维度未接入，P6 占位）。
Future<List<Map<String, dynamic>>> getScreeningResults(int taskId) async {
  final response =
      await EnterpriseApiClient().get('/enterprise/screening/tasks/$taskId/results');
  return (response['data'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}

/// UC-05 步骤5：推荐短名单（Top N 降序）。
/// 已对接：GET /enterprise/screening/tasks/{taskId}/shortlist?topN=
Future<List<Map<String, dynamic>>> getShortlist(int taskId, {int? topN}) async {
  final response = await EnterpriseApiClient().get(
    '/enterprise/screening/tasks/$taskId/shortlist',
    query: {'topN': topN},
  );
  return (response['data'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}

/// UC-05 步骤6-7：AI 推荐报告（匹配点/风险点/待核实点）。
/// 已对接：GET /enterprise/screening/results/{resultId}/report
/// 容错：matchPoints 可能为 null（未触发深度分析时）。
Future<Map<String, dynamic>> getRecommendationReport(int resultId) async {
  final response =
      await EnterpriseApiClient().get('/enterprise/screening/results/$resultId/report');
  final data = Map<String, dynamic>.from(response['data'] as Map? ?? const {});
  data['matchPoints'] = data['matchPoints'] ?? const <String, dynamic>{};
  return data;
}

/// UC-05 步骤8：Top 3 个性化招呼语。
/// 已对接：GET /enterprise/screening/results/{resultId}/greeting
Future<Map<String, dynamic>> getGreetingMessage(int resultId) async {
  final response =
      await EnterpriseApiClient().get('/enterprise/screening/results/$resultId/greeting');
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-06：HR 短名单复核（确认/调整）。
/// 已对接：PUT /enterprise/screening/results/{resultId}/review
/// 入参以实际接口为准：{approved, adjustScore}
Future<void> reviewScreeningResult(
  int resultId, {
  required bool approved,
  double? adjustScore,
}) async {
  await EnterpriseApiClient().put(
    '/enterprise/screening/results/$resultId/review',
    body: {'approved': approved, 'adjustScore': adjustScore},
  );
}
