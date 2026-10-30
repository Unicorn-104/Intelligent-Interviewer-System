import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

/// Same contract as user-PC/src/api/system/conference.js.
class ConferenceApi {
  const ConferenceApi(this.client, this.token);
  final ApiClient client;
  final String token;
  String path(int id, [String suffix = '']) =>
      '/system/conference/session/$id$suffix';
  Map<String, dynamic> data(Map<String, dynamic> response) {
    final value = response['data'];
    if (value is! Map) throw const ApiException('面试信息暂不可用，请重试');
    return Map<String, dynamic>.from(value);
  }

  Future<Map<String, dynamic>> verify(String roomToken) async => data(
    await client.get(
      '/system/conference/link/verify?${Uri(queryParameters: {'token': roomToken}).query}',
      token: token,
    ),
  );
  Future<Map<String, dynamic>> join(String roomToken) async => data(
    await client.post(
      '/system/conference/link/join',
      token: token,
      body: {'token': roomToken},
    ),
  );
  Future<Map<String, dynamic>> context(int id) async =>
      data(await client.get(path(id), token: token));
  Future<Map<String, dynamic>> waiting(int id) async =>
      data(await client.get(path(id, '/waiting-room'), token: token));
  Future<Map<String, dynamic>> progress(int id) async =>
      data(await client.get(path(id, '/progress'), token: token));
  Future<Map<String, dynamic>> result(int id) async =>
      data(await client.get(path(id, '/result'), token: token));
  Future<Map<String, dynamic>> livekit(int id) async => data(
    await client.get('/system/conference/livekit-token/$id', token: token),
  );
  Future<Map<String, dynamic>> asrStatus(int id) async =>
      data(await client.get(path(id, '/asr/status'), token: token));
  Future<Map<String, dynamic>> asrTicket(int id) async =>
      data(await client.post(path(id, '/asr/ticket'), token: token));
  Future<void> consent(int id, bool accepted) async {
    await client.post(
      path(id, '/consent'),
      token: token,
      body: {'consent': accepted ? 1 : 2},
    );
  }

  Future<void> participant(int id, Map<String, dynamic> state) async {
    await client.put(path(id, '/participant-state'), token: token, body: state);
  }

  Future<Map<String, dynamic>> start(int id) async =>
      data(await client.post(path(id, '/start'), token: token));
  Future<void> media(
    int id, {
    required bool camera,
    required bool microphone,
  }) async {
    await client.put(
      path(id, '/media'),
      token: token,
      body: {'cameraEnabled': camera, 'microphoneEnabled': microphone},
    );
  }

  Future<void> heartbeat(int id) async {
    await client.post(path(id, '/heartbeat'), token: token);
  }

  Future<Map<String, dynamic>> answer(int id, String content) async => data(
    await client.post(
      path(id, '/answers'),
      token: token,
      body: {'content': content, 'answerType': 1},
    ),
  );
  Future<Map<String, dynamic>> finish(int id) async => data(
    await client.post(
      path(id, '/finish'),
      token: token,
      body: {'endReason': 'normal'},
    ),
  );
  Future<List<Map<String, dynamic>>> captions(int id, int after) async {
    final response = await client.get(
      path(id, '/captions?afterSequence=$after&limit=50'),
      token: token,
    );
    if (response['data'] is! List) throw const ApiException('字幕暂不可用');
    return (response['data'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
