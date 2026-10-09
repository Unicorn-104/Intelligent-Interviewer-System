import '../../core/network/api_client.dart';

class EnterpriseRepository {
  EnterpriseRepository(this._client, this.tokenProvider);

  final ApiClient _client;
  final String? Function() tokenProvider;

  String get _token => tokenProvider() ?? '';

  Future<Map<String, dynamic>> dashboard() async {
    final response = await _client.get('/system/dashboard/overview', token: _token);
    return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
  }

  Future<List<Map<String, dynamic>>> jobs({String? keyword, int? status}) async {
    final response = await _client.get(
      '/system/enterprise/jobs/list',
      token: _token,
      query: {'pageNum': 1, 'pageSize': 100, 'keyword': keyword, 'status': status},
    );
    return _maps(response['rows']);
  }

  Future<void> changeJobStatus(Object id, int status) async {
    await _client.put('/system/enterprise/jobs/$id/status/$status', token: _token);
  }

  Future<void> createJob(Map<String, Object?> body) async {
    await _client.post('/system/enterprise/jobs', token: _token, body: body);
  }

  Future<List<Map<String, dynamic>>> candidates() async {
    final positionRows = await jobs();
    final details = await Future.wait(
      positionRows.map((job) async {
        final id = job['posId'] ?? job['positionId'];
        if (id == null) return const <Map<String, dynamic>>[];
        final response = await _client.get('/system/enterprise/jobs/$id', token: _token);
        final data = Map<String, dynamic>.from(response['data'] as Map? ?? const {});
        return _maps(data['candidates']).map((candidate) {
          candidate.putIfAbsent('positionTitle', () => job['title'] ?? job['posTitle'] ?? '未命名岗位');
          return candidate;
        }).toList();
      }),
    );
    final byId = <String, Map<String, dynamic>>{};
    for (final row in details.expand((items) => items)) {
      final id = '${row['candidateId'] ?? row['talId'] ?? row['userId'] ?? row.hashCode}';
      byId[id] = row;
    }
    return byId.values.toList();
  }

  Future<List<Map<String, dynamic>>> conversations() async {
    final response = await _client.get('/system/im/sessions', token: _token);
    return _maps(response['data'] ?? response['rows']);
  }

  Future<List<Map<String, dynamic>>> messages(Object sessionId) async {
    final response = await _client.get('/system/im/sessions/$sessionId/messages', token: _token);
    return _maps(response['data'] ?? response['rows']);
  }

  Future<void> markConversationRead(Object sessionId) async {
    await _client.put('/system/im/sessions/$sessionId/read', token: _token);
  }

  Future<void> sendMessage({required Object sessionId, required String content}) async {
    await _client.post('/system/im/messages', token: _token, body: {
      'sessionId': sessionId,
      'type': 1,
      'content': content,
    });
  }

  Future<Map<String, dynamic>?> currentInterview() async {
    final response = await _client.get('/system/conference/session/current', token: _token);
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<Map<String, dynamic>> profile() async {
    final response = await _client.get('/system/user/profile', token: _token);
    return Map<String, dynamic>.from(response['data'] as Map? ?? response);
  }

  Future<Map<String, List<Map<String, dynamic>>>> enterpriseSettings() async {
    Future<List<Map<String, dynamic>>> load(String path) async {
      final response = await _client.get(path, token: _token);
      return _maps(response['data'] ?? response['rows']);
    }

    final results = await Future.wait([
      load('/system/enterprise/settings/depts'),
      load('/system/enterprise/settings/members'),
      load('/system/enterprise/settings/templates'),
      load('/system/enterprise/settings/integrations'),
    ]);
    return {
      'departments': results[0],
      'members': results[1],
      'templates': results[2],
      'integrations': results[3],
    };
  }

  List<Map<String, dynamic>> _maps(Object? value) => value is List
      ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
      : const [];
}
