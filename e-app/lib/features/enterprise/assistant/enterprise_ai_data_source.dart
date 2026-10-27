import 'dart:math';

import 'package:dio/dio.dart';

import 'enterprise_ai_events.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/enterprise_api_client.dart';

int aiId(Object? value) {
  final id = int.tryParse('$value');
  if (id == null || id <= 0) throw const FormatException('AI对话标识无效');
  return id;
}

class EnterpriseAiSession {
  const EnterpriseAiSession(
    this.id,
    this.title, {
    this.updatedAt,
    this.activeRunId,
  });
  factory EnterpriseAiSession.fromJson(Map<String, dynamic> row) =>
      EnterpriseAiSession(
        aiId(row['id']),
        row['title']?.toString() ?? '新对话',
        updatedAt: DateTime.tryParse('${row['updatedAt']}'),
        activeRunId: row['activeRunId'] == null
            ? null
            : aiId(row['activeRunId']),
      );
  final int id;
  final String title;
  final DateTime? updatedAt;
  final int? activeRunId;
}

class EnterpriseAiMessage {
  const EnterpriseAiMessage(this.id, this.role, this.content, {this.state});
  factory EnterpriseAiMessage.fromJson(Map<String, dynamic> row) {
    final role = row['role'];
    if (role != 'user' && role != 'assistant') {
      throw const FormatException('AI消息格式不正确');
    }
    return EnterpriseAiMessage(
      aiId(row['id']),
      role as String,
      row['content']?.toString() ?? '',
      state: row['state']?.toString(),
    );
  }
  final int id;
  final String role, content;
  final String? state;
}

class EnterpriseAiRun {
  const EnterpriseAiRun(
    this.id,
    this.sessionId,
    this.state,
    this.content, {
    this.progress = '',
    this.error,
  });
  factory EnterpriseAiRun.fromJson(Map<String, dynamic> row) {
    final state = row['state']?.toString();
    if (!['R', 'C', 'F', 'X'].contains(state)) {
      throw const FormatException('AI回答状态不正确');
    }
    return EnterpriseAiRun(
      aiId(row['id']),
      aiId(row['sessionId']),
      state!,
      row['content']?.toString() ?? '',
      progress: row['progress']?.toString() ?? '',
      error: row['error']?.toString(),
    );
  }
  final int id, sessionId;
  final String state, content, progress;
  final String? error;
  bool get running => state == 'R';
}

class EnterpriseAiSlice<T> {
  const EnterpriseAiSlice(this.items, this.next, {this.activeRunId});
  final List<T> items;
  final int? next, activeRunId;
}

class EnterpriseAiDataSource {
  EnterpriseAiDataSource({EnterpriseApiClient? client})
    : _client = client ?? EnterpriseApiClient();
  final EnterpriseApiClient _client;
  String requestId() => List.generate(
    12,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  Map<String, dynamic> _data(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map) throw const FormatException('AI接口响应不完整');
    return Map<String, dynamic>.from(data);
  }

  List<Map<String, dynamic>> _rows(Object? raw) {
    if (raw is! List || raw.any((row) => row is! Map)) {
      throw const FormatException('AI列表格式不正确');
    }
    return raw.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<EnterpriseAiSlice<EnterpriseAiSession>> sessions({int? before}) async {
    final data = _data(
      await _client.get(
        '/enterprise/assistant/sessions',
        query: {'before': before},
      ),
    );
    return EnterpriseAiSlice(
      _rows(data['items']).map(EnterpriseAiSession.fromJson).toList(),
      data['nextCursor'] == null ? null : aiId(data['nextCursor']),
    );
  }

  Future<EnterpriseAiSession> create() async => EnterpriseAiSession.fromJson(
    _data(await _client.post('/enterprise/assistant/sessions')),
  );
  Future<EnterpriseAiSlice<EnterpriseAiMessage>> messages(
    int session, {
    int? before,
  }) async {
    final data = _data(
      await _client.get(
        '/enterprise/assistant/sessions/$session/messages',
        query: {'before': before},
      ),
    );
    return EnterpriseAiSlice(
      _rows(data['items']).map(EnterpriseAiMessage.fromJson).toList(),
      data['nextCursor'] == null ? null : aiId(data['nextCursor']),
      activeRunId: data['activeRunId'] == null
          ? null
          : aiId(data['activeRunId']),
    );
  }

  Future<EnterpriseAiRun> start(
    int session,
    String requestId,
    String content,
  ) async => EnterpriseAiRun.fromJson(
    _data(
      await _client.post(
        '/enterprise/assistant/sessions/$session/runs',
        body: {'requestId': requestId, 'content': content},
      ),
    ),
  );
  Future<EnterpriseAiRun?> lookup(int session, String requestId) async {
    final data = _data(
      await _client.get(
        '/enterprise/assistant/sessions/$session/requests/$requestId',
      ),
    );
    if (data['found'] == false) return null;
    if (data['run'] is! Map) throw const FormatException('请核对AI请求状态');
    return EnterpriseAiRun.fromJson(
      Map<String, dynamic>.from(data['run'] as Map),
    );
  }

  EnterpriseAiConnection openEvents(int id) {
    final cancel = CancelToken();
    return EnterpriseAiConnection(
      decodeEnterpriseAiEvents(
        _client.eventBytes(
          '/enterprise/assistant/runs/$id/events',
          cancelToken: cancel,
        ),
      ).asBroadcastStream(
        onCancel: (_) {
          // Let the decoder drain the transport's cancellation before it completes.
          if (!cancel.isCancelled) cancel.cancel('流式订阅已取消');
        },
      ),
      () {
        if (!cancel.isCancelled) cancel.cancel('离开或切换助手对话');
      },
    );
  }

  Future<EnterpriseAiRun> run(int id) async => EnterpriseAiRun.fromJson(
    _data(await _client.get('/enterprise/assistant/runs/$id')),
  );
  Future<EnterpriseAiRun> cancel(int id) async => EnterpriseAiRun.fromJson(
    _data(await _client.post('/enterprise/assistant/runs/$id/cancel')),
  );
  Future<void> delete(int id) =>
      _client.delete('/enterprise/assistant/sessions/$id').then((_) {});
  static String errorMessage(Object error) => switch (error) {
    ApiException() when error.isUnauthorized => '登录已失效，请重新登录后使用AI助手',
    ApiException() when error.statusCode == 404 || error.code == 404 =>
      'AI对话不存在，或服务器尚未部署企业助手接口',
    ApiException() when error.statusCode == 403 || error.code == 403 =>
      '请确认当前账号已绑定企业且具有访问权限',
    ApiException() => error.message,
    FormatException() => error.message,
    _ => 'AI服务暂不可用，请检查网络后重试',
  };
}
