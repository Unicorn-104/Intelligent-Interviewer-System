/// 企业 APP - 模块六（反馈与通知）：通知模板与发送日志接口。
///
/// 依据《业务功能分析》UC-16（全流程状态通知与模板化管理）。
///
/// P7 联调状态：已对接真实后端接口（EnterpriseSettingsController 模板 CRUD
/// + NotificationLogController 日志/统计）
/// 请求统一走 lib/core/network/enterprise_api_client.dart。
///
/// 已知占位（P6 报告标注）：
/// - 日志接口无渠道（channel）存储列，channel 参数后端忽略；
/// - 统计接口 deliveryRate/clickRate 为 null（渠道回执未接入），已默认值处理为 0.0。
library;

import '../../core/network/enterprise_api_client.dart';

/// UC-16 E1：通知模板列表。
/// 已对接：GET /system/enterprise/settings/templates
Future<List<Map<String, dynamic>>> listNotificationTemplates() async {
  final response = await EnterpriseApiClient().get('/system/enterprise/settings/templates');
  return (response['data'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}

/// UC-16 E1：新增通知模板（富文本 + 占位符 + 多语言版本）。
/// 已对接：POST /system/enterprise/settings/templates
/// 字段以实际接口为准：{title, content, channel}
Future<void> addNotificationTemplate({
  required String title,
  required String content,
  int? channel,
}) async {
  await EnterpriseApiClient().post(
    '/system/enterprise/settings/templates',
    body: {'title': title, 'content': content, 'channel': channel},
  );
}

/// UC-16 E1：编辑通知模板（修改后实时生效）。
/// 已对接：PUT /system/enterprise/settings/templates/{id}
/// 字段以实际接口为准：{title, content, channel, status}
Future<void> editNotificationTemplate(
  int id, {
  String? title,
  String? content,
  int? channel,
  int? status,
}) async {
  await EnterpriseApiClient().put(
    '/system/enterprise/settings/templates/$id',
    body: {'title': title, 'content': content, 'channel': channel, 'status': status},
  );
}

/// UC-16 E1：删除通知模板。
/// 已对接：DELETE /system/enterprise/settings/templates/{id}
Future<void> removeNotificationTemplate(int id) async {
  await EnterpriseApiClient().delete('/system/enterprise/settings/templates/$id');
}

/// UC-16 E2：发送日志检索（按候选人/场景/时间范围）。
/// 已对接：GET /enterprise/notification/logs（TableDataInfo 解包 rows）
/// 注意：channel 参数后端暂无对应存储列（P6 占位），传参保留但当前无效果。
Future<List<Map<String, dynamic>>> listNotificationLogs({
  String? candidate,
  String? scene,
  String? channel,
  String? from,
  String? to,
  int pageNum = 1,
  int pageSize = 20,
}) async {
  final response = await EnterpriseApiClient().get(
    '/enterprise/notification/logs',
    query: {
      'candidate': candidate,
      'scene': scene,
      'channel': channel,
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

/// UC-16 E2：送达率/打开率/点击率统计。
/// 已对接：GET /enterprise/notification/stats
/// 容错：deliveryRate/clickRate 后端暂无数据（P6 占位），默认值处理为 0.0，
/// 保证调用方拿到稳定的数值结构。
Future<Map<String, dynamic>> getNotificationStats() async {
  final response = await EnterpriseApiClient().get('/enterprise/notification/stats');
  final data = Map<String, dynamic>.from(response['data'] as Map? ?? const {});
  data['totalSent'] = data['totalSent'] ?? 0;
  data['openCount'] = data['openCount'] ?? 0;
  data['openRate'] = data['openRate'] ?? 0.0;
  data['deliveryRate'] = data['deliveryRate'] ?? 0.0;
  data['clickRate'] = data['clickRate'] ?? 0.0;
  return data;
}
