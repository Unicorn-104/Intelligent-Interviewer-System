import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/ai_models.dart';

class AiApi {
  const AiApi(this.client);
  final ApiClient client;

  Future<Map<String, dynamic>> sessions(
    String token, {
    String? before,
  }) async => _data(
    await client.get(
      '/app/ai/sessions${before == null ? '' : '?before=${Uri.encodeQueryComponent(before)}'}',
      token: token,
    ),
  );

  Future<AiSession> createSession(String token) async => AiSession.fromJson(
    _data(await client.post('/app/ai/sessions', token: token)),
  );

  Future<Map<String, dynamic>> renameSession(
    String token,
    String id,
    String title,
  ) async => _data(
    await client.post(
      '/app/ai/sessions/$id/rename',
      token: token,
      body: {'title': title},
    ),
  );

  Future<Map<String, dynamic>> pinSession(
    String token,
    String id,
    bool pinned,
  ) async => _data(
    await client.post(
      '/app/ai/sessions/$id/pin',
      token: token,
      body: {'pinned': pinned},
    ),
  );

  Future<void> deleteSession(String token, String id) async {
    await client.delete('/app/ai/sessions/$id', token: token);
  }

  Future<void> deleteSessions(String token, List<String> ids) async {
    await client.post(
      '/app/ai/sessions/batch-delete',
      token: token,
      body: {'ids': ids},
    );
  }

  Future<Map<String, dynamic>> messages(
    String token,
    String id, {
    int? before,
  }) async => _data(
    await client.get(
      '/app/ai/sessions/$id/messages${before == null ? '' : '?before=$before'}',
      token: token,
    ),
  );

  Future<Map<String, dynamic>> start(
    String token,
    String id, {
    required String content,
    required String requestId,
    int? resumeId,
    int? applicationId,
    String action = 'chat',
  }) async => _data(
    await client.post(
      '/app/ai/sessions/$id/runs',
      token: token,
      body: {
        'content': content,
        'requestId': requestId,
        'resumeId': resumeId,
        'applicationId': applicationId,
        'action': action,
      },
      timeout: const Duration(seconds: 40),
    ),
  );

  Stream<AiEvent> events(String token, String runId, int after) =>
      decodeAiEvents(
        client.eventLines(
          '/app/ai/runs/$runId/events?after=$after',
          token: token,
        ),
      );

  Future<Map<String, dynamic>> run(String token, String runId) async =>
      _data(await client.get('/app/ai/runs/$runId', token: token));

  Future<void> cancel(String token, String runId) async {
    await client.post('/app/ai/runs/$runId/cancel', token: token);
  }

  Map<String, dynamic> _data(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map<String, dynamic>) throw const ApiException('AI 服务响应格式不正确');
    return data;
  }
}
