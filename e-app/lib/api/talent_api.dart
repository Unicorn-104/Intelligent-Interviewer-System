/// 企业 APP - 模块一（岗位管理与人才库）：人才库接口。
///
/// 依据《业务功能分析》UC-03（人才库简历检索与管理）、UC-02（简历投递与智能解析）。
///
/// P7 联调状态：已对接真实后端接口（TalentPoolController）
/// 请求统一走 lib/core/network/enterprise_api_client.dart（dio 封装，
/// Token 自动注入 + 统一错误处理，页面 catch ApiException 展示友好提示）。

library;

import 'dart:typed_data';

import '../../core/network/enterprise_api_client.dart';

/// UC-03：人才库检索（关键词/标签/筛选条件 + 分页）。
/// 已对接：GET /enterprise/talent/list（TableDataInfo 解包 rows）
Future<List<Map<String, dynamic>>> searchTalentPool({
  String? keyword,
  String? tag,
  int pageNum = 1,
  int pageSize = 20,
}) async {
  final response = await EnterpriseApiClient().get(
    '/enterprise/talent/list',
    query: {
      'keyword': keyword,
      'tag': tag,
      'pageNum': pageNum,
      'pageSize': pageSize,
    },
  );
  return (response['rows'] as List?)
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList() ??
      const <Map<String, dynamic>>[];
}

/// Reuses the existing server-side filters; never scans only one page locally.
Future<List<Map<String, dynamic>>> searchAdvancedTalentPool({
  String? keyword,
  String? tag,
  String? direction,
  int? archiveSource,
  int? status,
  int? minimumEducation,
  String? experienceRange,
  String? city,
  String? cityType,
  int? loginWithinDays,
  required int pageNum,
  required int pageSize,
  EnterpriseApiClient? client,
}) async {
  final response = await (client ?? EnterpriseApiClient()).get(
    '/enterprise/talent/list',
    query: {
      'keyword': keyword,
      'tag': tag,
      'direction': direction,
      'archiveSource': archiveSource,
      'status': status,
      'minimumEducation': ?minimumEducation,
      'experienceRange': ?experienceRange,
      'city': ?city,
      if (city != null) 'cityType': cityType ?? 'target',
      'loginWithinDays': ?loginWithinDays,
      'pageNum': pageNum,
      'pageSize': pageSize,
    },
  );
  final rows = response['rows'];
  if (rows is! List || rows.any((row) => row is! Map)) {
    throw const FormatException('人才库列表响应不完整，请重新读取');
  }
  return [for (final row in rows) Map<String, dynamic>.from(row as Map)];
}

Future<Map<String, dynamic>> loadTalentPoolOptions({
  EnterpriseApiClient? client,
}) async {
  final response = await (client ?? EnterpriseApiClient()).get(
    '/enterprise/talent/options',
  );
  final data = response['data'];
  if (data is! Map) throw const FormatException('人才筛选选项响应不完整');
  return Map<String, dynamic>.from(data);
}

/// UC-03：人才库候选人详情。
/// 已对接：GET /enterprise/talent/{talId}
Future<Map<String, dynamic>> getTalentDetail(int talentId) async {
  final response = await EnterpriseApiClient().get(
    '/enterprise/talent/$talentId',
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}

/// UC-02/UC-03：候选人简历智能解析结果（结构化字段 + 完整度标记）。
/// 已对接：GET /enterprise/talent/{talId}/resume
/// 容错：integrity 无数据时为 0；missingFields 无数据时为空列表。
/// 响应新增 fileName：候选人已保存原始 PDF 时为原始文件名，否则为 null。
Future<Map<String, dynamic>> getTalentParsedResume(int talentId) async {
  final response = await EnterpriseApiClient().get(
    '/enterprise/talent/$talentId/resume',
  );
  final data = Map<String, dynamic>.from(response['data'] as Map? ?? const {});
  data['integrity'] = data['integrity'] ?? 0;
  data['missingFields'] = (data['missingFields'] as List?) ?? const <String>[];
  return data;
}

/// 候选人原始简历 PDF 字节（Bearer 鉴权，服务端校验候选人归属本企业）。
/// 已对接：GET /enterprise/talent/{talId}/resume/pdf
Future<Uint8List> getTalentResumePdf(
  int talentId, {
  EnterpriseApiClient? client,
}) =>
    (client ?? EnterpriseApiClient()).getBytes(
      '/enterprise/talent/$talentId/resume/pdf',
    );
