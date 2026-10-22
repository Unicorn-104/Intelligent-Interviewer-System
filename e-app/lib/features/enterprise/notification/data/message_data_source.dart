import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../api/message_api.dart' as im;
import '../../../../config/app_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/enterprise_api_client.dart';
import '../../jobs/data/job_detail_data_source.dart';
import '../../profile/data/profile_data_source.dart';
import '../../profile/models/profile_view_data.dart';
import '../../talent/data/talent_detail_data_source.dart';
import '../models/chat_context.dart';
import '../models/message_view_data.dart';
import 'chat_context_data_source.dart';
import 'chat_attachment_picker.dart';

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

  JobDetailDataSource get jobDetailsSource => const JobDetailDataSource();

  TalentDetailDataSource get candidateDetailsSource =>
      const TalentDetailDataSource();

  Future<ChatContext> loadChatContext(Map<String, dynamic> session) async {
    await _requireSession();
    return ChatContextDataSource(client: client ?? EnterpriseApiClient())
        .load(session);
  }

  Future<EnterpriseProfile> loadRecruiterProfile() =>
      ProfileDataSource(client: client, storage: storage).loadProfile();

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

  Future<List<ChatQuickReply>> loadQuickReplies() async {
    await _requireSession();
    final rows = client == null
        ? await im.listQuickReplies()
        : messageRows((await client!.get('/system/im/quick-replies'))['data']);
    final seen = <int>{};
    return rows
        .where((row) => messageText(row['content'], '').isNotEmpty)
        .map(ChatQuickReply.fromJson)
        .where((reply) => seen.add(reply.id))
        .toList();
  }

  Future<void> saveQuickReply({
    ChatQuickReply? reply,
    required String content,
  }) async {
    await _requireSession();
    final text = content.trim();
    if (text.isEmpty || text.length > 1000) {
      throw const FormatException('常用语须为1至1000个字符');
    }
    final body = <String, Object?>{
      if (reply != null) 'id': reply.id,
      'category': reply?.category ?? '常用语',
      'content': text,
    };
    if (client == null) {
      await im.saveQuickReply(body);
    } else {
      await client!.post('/system/im/quick-replies', body: body);
    }
  }

  Future<ChatPickedAttachment?> pickAttachment({required bool image}) =>
      ChatAttachmentPicker().pick(image: image);

  Future<ChatUploadedAttachment> uploadAttachment(
    ChatPickedAttachment file,
  ) async {
    await _requireSession();
    final Map<String, dynamic> response;
    try {
      response = await (client ?? EnterpriseApiClient()).uploadFile(
        '/common/upload',
        filename: file.name,
        bytes: file.bytes,
        mimeType: file.mimeType,
      );
    } on ApiException catch (error) {
      if (error.isUnauthorized) rethrow;
      throw ApiException('附件上传失败，请检查文件或网络后重试', code: error.code);
    }
    final path = messageText(
      response['fileName'],
      messageText(response['url'], ''),
    );
    if (attachmentUrl(path) == null) {
      throw const FormatException('上传服务未返回有效的附件地址，消息未发送');
    }
    return ChatUploadedAttachment(
      name: file.name,
      url: path,
      isImage: file.isImage,
    );
  }

  Future<void> sendAttachment(
    int sessionId,
    ChatUploadedAttachment file,
  ) async {
    await _requireSession();
    if (attachmentUrl(file.url) == null) {
      throw const FormatException('附件地址无效，请重新选择');
    }
    ChatPickedAttachment.validateName(file.name, file.isImage);
    final body = {
      'sessionId': sessionId,
      'type': file.isImage ? 2 : 3,
      'content': file.name,
      'attachmentUrl': file.url,
    };
    if (client == null) {
      await im.sendImMessage(body);
    } else {
      await client!.post('/system/im/messages', body: body);
    }
  }

  String? attachmentUrl(String path) {
    if (path.isEmpty || RegExp(r'[\x00-\x20\x7f]').hasMatch(path)) return null;
    final parsed = Uri.tryParse(path);
    if (parsed == null || parsed.userInfo.isNotEmpty || parsed.hasFragment) {
      return null;
    }
    final base = Uri.parse(AppConfig.apiBaseUrl);
    final url = base.resolveUri(parsed);
    if (!['http', 'https'].contains(url.scheme) ||
        url.origin != base.origin ||
        url.query.isNotEmpty ||
        !url.path.startsWith('/profile/') ||
        RegExp(r'%2f|%5c|%2e', caseSensitive: false).hasMatch(url.path) ||
        parsed.pathSegments.contains('..')) {
      return null;
    }
    return url.toString();
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
