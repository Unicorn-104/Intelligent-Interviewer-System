/// 企业 APP - 模块一（岗位管理与人才库）：岗位管理接口。
///
/// 依据《业务功能分析》UC-01（发布岗位并生成 JD 画像）。
///
/// P7 联调状态：已对接真实后端接口（EnterpriseJobController）
/// 请求统一走 lib/core/network/enterprise_api_client.dart（dio 封装，
/// Token 自动注入 + 统一错误处理，页面 catch ApiException 展示友好提示）。

library;

import '../../core/network/enterprise_api_client.dart';

/// UC-01：岗位列表（关键词/部门/状态筛选 + 分页）。
/// 已对接：GET /system/enterprise/jobs/list（TableDataInfo 解包 rows）
Future<List<Map<String, dynamic>>> listJobs({
  String? keyword,
  String? dept,
  int? status,
  int pageNum = 1,
  int pageSize = 20,
}) async {
  final response = await EnterpriseApiClient().get(
    '/system/enterprise/jobs/list',
    query: {
      'keyword': keyword,
      'dept': dept,
      'status': status,
      'pageNum': pageNum,
      'pageSize': pageSize,
    },
  );
  return (response['rows'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}

/// UC-01：岗位详情。
/// 已对接：GET /system/enterprise/jobs/{posId}
Future<Map<String, dynamic>> getJobDetail(int positionId) async {
  final response = await EnterpriseApiClient().get(
    '/system/enterprise/jobs/$positionId',
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-01：发布完整岗位，返回新岗位 ID 和发布状态。
/// 已对接：POST /system/enterprise/jobs
Future<Map<String, dynamic>> createJob(Map<String, Object?> body) async {
  final response = await EnterpriseApiClient().post(
    '/system/enterprise/jobs',
    body: body,
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// 更新当前企业的已有岗位，保留岗位状态与招聘流程。
Future<Map<String, dynamic>> updateJob(
  int positionId,
  Map<String, Object?> body,
) async {
  final response = await EnterpriseApiClient().put(
    '/system/enterprise/jobs/$positionId',
    body: body,
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// 发布前读取当前账号所属企业及已有部门。
Future<Map<String, dynamic>> getJobPublishingOptions() async {
  final response = await EnterpriseApiClient().get(
    '/system/enterprise/jobs/publishing-options',
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-01：岗位上线/下线。
/// 已对接：PUT /system/enterprise/jobs/{posId}/status/{status}
Future<void> changeJobStatus(int positionId, int status) async {
  await EnterpriseApiClient().put(
    '/system/enterprise/jobs/$positionId/status/$status',
  );
}

/// UC-01：部门列表。
/// 已对接：GET /system/enterprise/jobs/departments
Future<List<Map<String, dynamic>>> listDepartments() async {
  final response = await EnterpriseApiClient().get(
    '/system/enterprise/jobs/departments',
  );
  return (response['data'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}

/// UC-01：多阶段面试招聘流程查看。
/// 已对接：GET /system/enterprise/jobs/{posId}/workflow
Future<Map<String, dynamic>> getJobWorkflow(int positionId) async {
  final response = await EnterpriseApiClient().get(
    '/system/enterprise/jobs/$positionId/workflow',
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-01：多阶段面试招聘流程保存。
/// 已对接：PUT /system/enterprise/jobs/{posId}/workflow
Future<void> saveJobWorkflow(int positionId, Map<String, Object?> body) async {
  await EnterpriseApiClient().put(
    '/system/enterprise/jobs/$positionId/workflow',
    body: body,
  );
}
