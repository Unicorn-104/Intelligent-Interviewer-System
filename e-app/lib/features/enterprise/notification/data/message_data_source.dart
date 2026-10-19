import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../api/message_api.dart' as im;
import '../../../../config/app_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/enterprise_api_client.dart';
import '../models/message_view_data.dart';

class MessageDataSource {
  const MessageDataSource({
    this.client,
    this.storage = const FlutterSecureStorage(),
  });
  final EnterpriseApiClient? client;
  final FlutterSecureStorage storage;
  Future<void> _requireSession() async {
    final token = await storage.read(key: 'enterprise_access_token');
    if (token == null || token.isEmpty) {
      throw const ApiException('登录已失效，请重新登录', code: 401);
    }
  }

  Future<List<MessageSession>> loadSessions() async {
    await _requireSession();
    final rows = client == null
        ? await im.listImSessions()
        : messageRows((await client!.get('/system/im/sessions'))['data']);
    return rows.map(MessageSession.fromJson).toList();
  }

  Future<List<ConversationMessage>> loadMessages(int sessionId) async {
    await _requireSession();
    final rows = client == null
        ? await im.listImMessages(sessionId)
        : messageRows(
            (await client!.get(
              '/system/im/sessions/$sessionId/messages',
            ))['data'],
          );
    final messages = rows.map(ConversationMessage.fromJson).toList();
    messages.sort((a, b) {
      final time = (a.time ?? DateTime.utc(1970)).compareTo(
        b.time ?? DateTime.utc(1970),
      );
      return time == 0 ? a.id.compareTo(b.id) : time;
    });
    return messages;
  }

  Future<void> send(int sessionId, String content) async {
    await _requireSession();
    final body = {'sessionId': sessionId, 'type': 1, 'content': content};
    if (client == null) {
      await im.sendImMessage(body);
    } else {
      await client!.post('/system/im/messages', body: body);
    }
  }

  Future<void> readSession(int sessionId) async {
    await _requireSession();
    if (client == null) {
      await im.markImSessionRead(sessionId);
    } else {
      await client!.put('/system/im/sessions/$sessionId/read');
    }
  }

  Future<void> readAllSessions() async {
    await _requireSession();
    if (client == null) {
      await im.markAllImRead();
    } else {
      await client!.put('/system/im/read-all');
    }
  }

  Future<List<String>> loadQuickReplies() async {
    await _requireSession();
    final rows = client == null
        ? await im.listQuickReplies()
        : messageRows((await client!.get('/system/im/quick-replies'))['data']);
    return rows
        .map((row) => messageText(row['content'], ''))
        .where((text) => text.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<NotificationSlice> loadNotifications({int? beforeId}) async {
    await _requireSession();
    final response = await (client ?? EnterpriseApiClient()).get(
      '/system/im/notifications',
      query: {
        'limit': 50,
        ...?beforeId == null ? null : {'beforeId': beforeId},
      },
    );
    final rows = messageRows(response['data']);
    return NotificationSlice(
      rows.map(SystemMessage.fromJson).toList(),
      messageCount(response['unreadCount']),
      rows.length == 50,
    );
  }

  Future<void> readNotification(int id) async {
    await _requireSession();
    await (client ?? EnterpriseApiClient()).put(
      '/system/im/notifications/$id/read',
    );
  }

  Future<void> readAllNotifications() async {
    await _requireSession();
    await (client ?? EnterpriseApiClient()).put(
      '/system/im/notifications/read-all',
    );
  }

  String? avatarUrl(String path) {
    if (path.isEmpty) return null;
    final parsed = Uri.tryParse(path);
    if (parsed == null) return null;
    final url = Uri.parse(AppConfig.apiBaseUrl).resolveUri(parsed);
    return ['http', 'https'].contains(url.scheme) ? url.toString() : null;
  }
}

String messageError(Object error) => switch (error) {
  ApiException() => error.isUnauthorized ? '登录已失效，请重新登录' : error.message,
  FormatException() => error.message.toString(),
  _ => '消息加载失败，请稍后重试',
};
