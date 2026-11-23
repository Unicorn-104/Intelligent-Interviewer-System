import '../core/network/enterprise_api_client.dart';

/// 企业知识库文档与检索结果。数据由服务端按当前企业隔离。
class EnterpriseKnowledgeDocument {
  final String id;
  final String name;
  final int contentLength;
  final int chunkCount;
  final DateTime? updatedAt;

  const EnterpriseKnowledgeDocument({
    required this.id,
    required this.name,
    this.contentLength = 0,
    this.chunkCount = 0,
    this.updatedAt,
  });

  factory EnterpriseKnowledgeDocument.fromJson(Map<String, dynamic> json) =>
      EnterpriseKnowledgeDocument(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '未命名文档',
        contentLength: _integer(json['contentLength']),
        chunkCount: _integer(json['chunkCount']),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      );
}

class EnterpriseKnowledgeResult {
  final String citation;
  final String fileName;
  final String content;

  const EnterpriseKnowledgeResult({
    required this.citation,
    required this.fileName,
    required this.content,
  });

  factory EnterpriseKnowledgeResult.fromJson(Map<String, dynamic> json) =>
      EnterpriseKnowledgeResult(
        citation: json['citation']?.toString() ?? '',
        fileName: json['fileName']?.toString() ?? '企业知识库',
        content: json['content']?.toString() ?? '',
      );
}

int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

List<Map<String, dynamic>> _rows(Object? data) {
  if (data == null) return const [];
  if (data is! List) throw const FormatException('知识库响应格式不正确');
  return data
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

Future<List<EnterpriseKnowledgeDocument>>
getEnterpriseKnowledgeDocuments() async {
  final response = await EnterpriseApiClient().get(
    '/enterprise/assistant/knowledge/documents',
  );
  return _rows(response['data'])
      .map(EnterpriseKnowledgeDocument.fromJson)
      .toList();
}

Future<void> createEnterpriseKnowledgeDocument({
  required String name,
  required String content,
}) async {
  await EnterpriseApiClient().post(
    '/enterprise/assistant/knowledge/documents',
    body: {'name': name.trim(), 'content': content.trim()},
  );
}

Future<void> deleteEnterpriseKnowledgeDocument(String id) async {
  await EnterpriseApiClient().delete(
    '/enterprise/assistant/knowledge/documents/$id',
  );
}

Future<List<EnterpriseKnowledgeResult>> searchEnterpriseKnowledge(
  String query,
) async {
  final response = await EnterpriseApiClient().post(
    '/enterprise/assistant/knowledge/search',
    body: {'query': query.trim()},
  );
  return _rows(response['data'])
      .map(EnterpriseKnowledgeResult.fromJson)
      .toList();
}
