/// 企业 APP - 模块四（面试入口与准备）：在线实操环境预加载接口。
///
/// 依据《业务功能分析》UC-11（在线实操环境预加载）。
///
/// P7 联调状态：已对接真实后端接口（PracticeTaskController）
/// 请求统一走 lib/core/network/enterprise_api_client.dart。
///
/// 已知占位（P6 报告标注）：预加载为同步就绪校验（模拟），
/// 真实异步初始化待沙箱服务接入后替换。
library;

import '../../core/network/enterprise_api_client.dart';

/// UC-11：预加载在线实操考核环境（代码沙箱/云端 IDE，面试前异步准备）。
/// 已对接：POST /enterprise/practice/{sessionId}/preload
Future<Map<String, dynamic>> preloadPracticeEnvironment(int sessionId) async {
  final response =
      await EnterpriseApiClient().post('/enterprise/practice/$sessionId/preload');
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-11：实操环境预加载状态查询（就绪/无实操环节）。
/// 已对接：GET /enterprise/practice/{sessionId}/status
/// 容错：tasks 无数据时为空列表；hasPractice 无数据时为 false。
Future<Map<String, dynamic>> getPracticePreloadStatus(int sessionId) async {
  final response = await EnterpriseApiClient().get('/enterprise/practice/$sessionId/status');
  final data = Map<String, dynamic>.from(response['data'] as Map? ?? const {});
  data['tasks'] = (data['tasks'] as List?) ?? const <Map<String, dynamic>>[];
  data['hasPractice'] = data['hasPractice'] ?? false;
  return data;
}
