/// 企业 APP - 模块六（反馈与通知）：满意度调研接口。
///
/// 依据《业务功能分析》UC-17（候选人体验调研与数据分析）。
///
/// P7 联调状态：已对接真实后端接口（SurveyController）
/// 请求统一走 lib/core/network/enterprise_api_client.dart。
///
/// 注意：结果接口后端无分页参数（一次性返回全部回收记录），
/// 分页由调用方在客户端处理。
library;

import '../../core/network/enterprise_api_client.dart';

/// UC-17：满意度调研结果汇总（均分/评分分布/回收明细含文字反馈）。
/// 已对接：GET /enterprise/survey/results
/// 容错：avgScore 可能为 null（无回收数据）；distribution/responses 默认空列表。
Future<Map<String, dynamic>> getSurveyResults({
  int? templateId,
  String? from,
  String? to,
}) async {
  final response = await EnterpriseApiClient().get(
    '/enterprise/survey/results',
    query: {'templateId': templateId, 'from': from, 'to': to},
  );
  final data = Map<String, dynamic>.from(response['data'] as Map? ?? const {});
  data['distribution'] = (data['distribution'] as List?) ?? const <Map<String, dynamic>>[];
  data['responses'] = (data['responses'] as List?) ?? const <Map<String, dynamic>>[];
  return data;
}

/// UC-17：调研问卷模板查看。
/// 已对接：GET /enterprise/survey/templates
/// 容错：questions 由后端解析为 JSON，可能为 null。
Future<List<Map<String, dynamic>>> getSurveyTemplates() async {
  final response = await EnterpriseApiClient().get('/enterprise/survey/templates');
  return (response['data'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}
