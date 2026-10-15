import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/support_models.dart';

class SupportApi {
  const SupportApi(this._client);

  final ApiClient _client;

  Future<List<HelpArticle>> fetchHelpArticles(
    String token, {
    String? keyword,
  }) async {
    final query = <String, String>{'limit': '50'};
    final normalized = keyword?.trim() ?? '';
    if (normalized.isNotEmpty) query['keyword'] = normalized;
    final suffix = Uri(queryParameters: query).query;
    final json = await _client.get(
      '/app/support/help-articles?$suffix',
      token: token,
    );
    final data = json['data'];
    if (data is! List) throw const ApiException('帮助中心数据格式不正确');
    return data
        .whereType<Map>()
        .map((item) => HelpArticle.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<FeedbackRecord>> fetchFeedback(String token) async {
    final json = await _client.get(
      '/app/support/feedback?limit=20',
      token: token,
    );
    final data = json['data'];
    if (data is! List) throw const ApiException('反馈记录格式不正确');
    return data
        .whereType<Map>()
        .map((item) => FeedbackRecord.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> submitFeedback(
    String token, {
    required int type,
    required String subject,
    required String description,
  }) async {
    await _client.post(
      '/app/support/feedback',
      token: token,
      body: {
        'type': type,
        'subject': subject.trim(),
        'description': description.trim(),
      },
    );
  }
}
