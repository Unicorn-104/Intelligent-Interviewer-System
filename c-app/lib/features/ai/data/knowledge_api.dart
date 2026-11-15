import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class KnowledgeApi {
  KnowledgeApi(this.client);
  final ApiClient client;
  static const root = '/app/ai/knowledge';
  Future<List<Map<String, dynamic>>> documents(String token) async =>
      _items(await client.get('$root/documents', token: token));
  Future<void> upload(String token, String path) async {
    await client.postFile(
      '$root/documents',
      filePath: path,
      fieldName: 'file',
      token: token,
    );
  }

  Future<void> retry(String token, String id) async {
    await client.post('$root/documents/$id/retry', token: token);
  }

  Future<void> deleteDocument(String token, String id) async {
    await client.delete('$root/documents/$id', token: token);
  }

  Map<String, dynamic> _data(Map<String, dynamic> value) {
    final data = value['data'];
    if (data is! Map<String, dynamic>) throw const ApiException('知识库响应格式不正确');
    return data;
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> value) {
    final items = _data(value)['items'];
    if (items is! List) throw const ApiException('知识库响应格式不正确');
    return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
}
