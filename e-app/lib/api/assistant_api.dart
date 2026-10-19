/// 企业 APP - 模块六（反馈与通知）：7×24 AI 助手接口（预留）。
///
/// 依据《业务功能分析》UC-18（AI 助手 7×24 小时自动应答）。
/// 该用例主要面向候选人；企业 APP 按计划仅预留入口页与占位函数。
///
/// P7 联调状态：
/// - getAssistantHelpArticles 已对接候选人端现有接口（GET /app/support/help-articles）；
/// - chatWithAssistant 后端无对应接口（接口契约待确认），
///   保持占位（UnimplementedError），不编造接口。
library;

import '../../core/network/enterprise_api_client.dart';

/// UC-18（候选人侧能力，企业端预留）：帮助文档检索。
/// 已对接：GET /app/support/help-articles（候选人端现有接口）
Future<List<Map<String, dynamic>>> getAssistantHelpArticles({
  String? keyword,
  String? category,
}) async {
  final response = await EnterpriseApiClient().get(
    '/app/support/help-articles',
    query: {'keyword': keyword, 'category': category},
  );
  return (response['data'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}

/// UC-18（候选人侧能力，企业端预留）：AI 助手对话。
/// 后端接口待定：候选人端智能服务接口或新增企业侧接口，契约确认后补充。
/// 禁止编造接口 —— 保持占位实现。
Future<Map<String, dynamic>> chatWithAssistant({
  required String message,
  int? sessionId,
}) async {
  throw UnimplementedError(
      'TODO: 后端无对应接口（UC-18 企业端接入方式待定），保持占位，禁止编造');
}
