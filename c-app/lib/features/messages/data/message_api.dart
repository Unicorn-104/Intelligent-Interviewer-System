import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/app_message.dart';

class MessageApi {
  const MessageApi(this._client);

  final ApiClient _client;

  Future<List<AppMessage>> fetchMessages(String token) async {
    final json = await _client.get('/app/messages?limit=50', token: token);
    final data = json['data'];
    if (data is! List) throw const ApiException('消息数据格式不正确');
    return data
        .whereType<Map>()
        .map((item) => AppMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> markRead(String token, AppMessage message) async {
    final category = switch (message.category) {
      AppMessageCategory.hr => 'HR',
      AppMessageCategory.system => 'SYSTEM',
      AppMessageCategory.company => 'COMPANY',
    };
    await _client.put(
      '/app/messages/$category/${message.sourceId}/read',
      token: token,
    );
  }

  Future<void> markAllRead(String token) async {
    await _client.put('/app/messages/read-all', token: token);
  }

  Future<List<ChatMessage>> fetchHrChat(String token, int sessionId) async {
    final json = await _client.get(
      '/app/messages/hr/$sessionId/chat?limit=100',
      token: token,
    );
    final data = json['data'];
    if (data is! List) throw const ApiException('聊天记录格式不正确');
    return data
        .whereType<Map>()
        .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> sendHrChat(String token, int sessionId, String content) async {
    await _client.post(
      '/app/messages/hr/$sessionId/chat',
      token: token,
      body: {'content': content},
    );
  }
}
