import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/app_message.dart';
import 'chat_attachment_picker.dart';
import 'chat_resource_url.dart';

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
      '/system/im/sessions/$sessionId/messages',
      token: token,
    );
    final data = json['data'];
    if (data is! List) throw const ApiException('聊天记录格式不正确');
    final rows = data
        .whereType<Map>()
        .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    // 通用 IM 按正序返回；保留页面既有的倒序接口约定。
    rows.sort((a, b) {
      final time = b.createdAt.compareTo(a.createdAt);
      return time == 0 ? b.messageId.compareTo(a.messageId) : time;
    });
    return rows;
  }

  Future<bool> acknowledgeRead(
    String token,
    int sessionId,
    int lastMessageId,
  ) async {
    final json = await _client.put(
      '/system/im/sessions/$sessionId/receipts',
      token: token,
      body: {'lastMessageId': lastMessageId},
    );
    return json['data'] is Map && json['data']['supported'] == true;
  }

  Future<void> sendHrChat(String token, int sessionId, String content) async {
    await _client.post(
      '/app/messages/hr/$sessionId/chat',
      token: token,
      body: {'content': content},
    );
  }

  Future<ChatPickedAttachment?> pickAttachment({required bool image}) =>
      ChatAttachmentPicker().pick(image: image);

  Future<ChatPickedAttachment?> pickCameraAttachment() =>
      ChatAttachmentPicker().camera();

  String? attachmentUrl(String? path) => chatResourceUrl(path, _client.baseUrl);

  Future<ChatUploadedAttachment> uploadAttachment(
    String token,
    ChatPickedAttachment file,
  ) async {
    final response = await _client.uploadBytes(
      '/common/upload',
      token: token,
      filename: file.name,
      bytes: file.bytes,
      mimeType: file.mimeType,
    );
    final path = (response['fileName'] ?? response['url'])?.toString();
    final url = attachmentUrl(path);
    if (url == null) throw const ApiException('上传未返回有效的附件地址，消息未发送');
    final basePath = Uri.parse(
      _client.baseUrl,
    ).path.replaceAll(RegExp(r'/+$'), '');
    return ChatUploadedAttachment(
      name: file.name,
      url: Uri.parse(url).path.substring(basePath.length),
      isImage: file.isImage,
    );
  }

  Future<void> sendAttachment(
    String token,
    int sessionId,
    ChatUploadedAttachment file,
  ) async {
    if (attachmentUrl(file.url) == null) throw const ApiException('附件地址无效');
    ChatPickedAttachment.validateName(file.name, file.isImage);
    await _client.post(
      '/system/im/messages',
      token: token,
      body: {
        'sessionId': sessionId,
        'type': file.isImage ? 2 : 3,
        'content': file.name,
        'attachmentUrl': file.url,
      },
    );
  }

  Future<Uint8List> downloadAttachment(String? path) {
    final url = attachmentUrl(path);
    if (url == null) throw const ApiException('附件地址无效');
    return _client.downloadPublicAttachment(url);
  }
}
