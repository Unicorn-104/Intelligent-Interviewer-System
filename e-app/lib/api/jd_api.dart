/// 企业 APP - 模块一（岗位管理与人才库）：JD 画像接口。
///
/// 依据《业务功能分析》UC-01（发布岗位并生成 JD 画像）。
///
/// P7 联调状态：已对接真实后端接口
/// - POST /enterprise/jd/parse（EnterpriseJdController）
/// - GET  /enterprise/jd/{posId}（EnterpriseJdController）
/// 请求统一走 lib/core/network/enterprise_api_client.dart（dio 封装，
/// Token 自动注入 + 统一错误处理，页面 catch ApiException 展示友好提示）。

library;

import '../../core/network/enterprise_api_client.dart';

/// UC-01 步骤：解析 JD 文本，生成结构化岗位画像（JD Profile）。
/// 已对接：POST /enterprise/jd/parse
Future<Map<String, dynamic>> parseJdProfile({
  required int positionId,
  required String jdText,
}) async {
  final response = await EnterpriseApiClient().post(
    '/enterprise/jd/parse',
    body: {'positionId': positionId, 'jdText': jdText},
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-01：查看岗位画像（学历/年限/技能标签等硬性指标与软性要求）。
/// 已对接：GET /enterprise/jd/{posId}
Future<Map<String, dynamic>> getJdProfile(int positionId) async {
  final response = await EnterpriseApiClient().get('/enterprise/jd/$positionId');
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}
