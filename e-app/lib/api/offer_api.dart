/// 企业 APP - 模块五（面试执行与级联评估）：Offer 管理接口。
///
/// 依据《业务功能分析》UC-12（多模式 AI 面试执行与级联评估）步骤 9 终面分支
/// （自动触发录用意向书 Offer 发送）。
///
/// P7 联调状态：已对接真实后端接口（OfferController）
/// 请求统一走 lib/core/network/enterprise_api_client.dart。
library;

import '../../core/network/enterprise_api_client.dart';

/// UC-12 步骤9：触发 Offer 发送（终面审核通过后，生成录用意向书并发送）。
/// 已对接：POST /enterprise/offer/{sessionId}/trigger
/// body 可选：{salaryOffer, onboardDate, deadline}
Future<Map<String, dynamic>> triggerOffer(
  int sessionId, {
  String? salaryOffer,
  String? onboardDate,
  String? deadline,
}) async {
  final response = await EnterpriseApiClient().post(
    '/enterprise/offer/$sessionId/trigger',
    body: {
      'salaryOffer': salaryOffer,
      'onboardDate': onboardDate,
      'deadline': deadline,
    },
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-12 步骤9：Offer 列表（岗位/薪资区间/入职时间/状态）。
/// 已对接：GET /enterprise/offer/list（TableDataInfo 解包 rows）
/// status：0-已发送，1-已接受，2-已拒绝，3-已过期，4-草稿，5-审批中，6-已撤回
Future<List<Map<String, dynamic>>> listOffers({
  int? status,
  int pageNum = 1,
  int pageSize = 20,
}) async {
  final response = await EnterpriseApiClient().get(
    '/enterprise/offer/list',
    query: {'status': status, 'pageNum': pageNum, 'pageSize': pageSize},
  );
  return (response['rows'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}

/// UC-12 步骤9：Offer 详情（含审批节点）。
/// 已对接：GET /enterprise/offer/{offerId}
/// 容错：approvals 无数据时为空列表。
Future<Map<String, dynamic>> getOfferDetail(int offerId) async {
  final response = await EnterpriseApiClient().get('/enterprise/offer/$offerId');
  final data = Map<String, dynamic>.from(response['data'] as Map? ?? const {});
  data['approvals'] = data['approvals'] ?? const <Map<String, dynamic>>[];
  return data;
}
