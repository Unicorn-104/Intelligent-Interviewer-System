/// 企业 APP - 企业信息管理接口（与求职者企业主页同源字段）。
///
/// 企业招聘者在「我的」页面查看并维护企业对外展示资料；
/// 求职者企业主页（C-APP /app/companies/{id}）读取同一批字段。
///
/// P7 联调状态：已对接真实后端接口（EnterpriseSettingsController）
/// 请求统一走 lib/core/network/enterprise_api_client.dart（dio 封装，
/// Token 自动注入 + 统一错误处理，页面 catch ApiException 展示友好提示）。

library;

import '../../core/network/api_exception.dart';
import '../../core/network/enterprise_api_client.dart';

Map<String, dynamic> _data(Map<String, dynamic> response) {
  final data = response['data'];
  if (data is! Map) {
    throw const ApiException('企业信息响应格式不正确');
  }
  return Map<String, dynamic>.from(data);
}

/// 读取当前绑定企业的对外展示信息。
/// 已对接：GET /system/enterprise/settings/company
Future<Map<String, dynamic>> getCompanyInfo() async => _data(
  await EnterpriseApiClient().get('/system/enterprise/settings/company'),
);

/// 保存当前绑定企业的对外展示信息，返回最新企业信息。
/// 已对接：PUT /system/enterprise/settings/company
Future<Map<String, dynamic>> updateCompanyInfo(
  Map<String, Object?> body,
) async => _data(
  await EnterpriseApiClient().put(
    '/system/enterprise/settings/company',
    body: body,
  ),
);
