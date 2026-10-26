import 'dart:convert';

enum AppMessageCategory { hr, system, company }

class ChatMessage {
  const ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.content,
    required this.mine,
    required this.createdAt,
    this.type = 1,
  });
  final int messageId, senderId, type;
  final String content;
  final bool mine;
  final DateTime createdAt;
  Map<String, dynamic>? get reschedule {
    if (type != 5) return null;
    try {
      final raw = jsonDecode(content);
      if (raw is! Map ||
          raw['kind'] != 'interview_reschedule' ||
          raw['version'] != 1) {
        return null;
      }
      return Map<String, dynamic>.from(raw);
    } catch (_) {
      return null;
    }
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    messageId: AppMessage._asInt(json['messageId']),
    senderId: AppMessage._asInt(json['senderId']),
    content: json['content']?.toString() ?? '',
    mine: json['mine'] == true || json['mine']?.toString() == '1',
    type: int.tryParse('${json['type']}') ?? 1,
    createdAt:
        DateTime.tryParse(
          (json['createdAt']?.toString() ?? '').replaceFirst(' ', 'T'),
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class AppMessage {
  const AppMessage({
    required this.sourceId,
    required this.category,
    required this.title,
    required this.content,
    required this.occurredAt,
    required this.unreadCount,
    this.avatarUrl,
    this.targetUrl,
    this.badge,
  });

  final int sourceId;
  final AppMessageCategory category;
  final String title;
  final String content;
  final DateTime occurredAt;
  final int unreadCount;
  final String? avatarUrl;
  final String? targetUrl;
  final String? badge;

  int? get companyId {
    if (category != AppMessageCategory.company || targetUrl == null) {
      return null;
    }
    final uri = Uri.tryParse(targetUrl!);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'companies') {
      return null;
    }
    final id = int.tryParse(uri.pathSegments[1]);
    return id != null && id > 0 ? id : null;
  }

  factory AppMessage.fromJson(Map<String, dynamic> json) {
    return AppMessage(
      sourceId: _asInt(json['sourceId']),
      category: switch (json['category']?.toString().toUpperCase()) {
        'HR' => AppMessageCategory.hr,
        'COMPANY' => AppMessageCategory.company,
        _ => AppMessageCategory.system,
      },
      title: json['title']?.toString() ?? '消息',
      content: json['content']?.toString() ?? '',
      occurredAt:
          DateTime.tryParse(
            (json['occurredAt']?.toString() ?? '').replaceFirst(' ', 'T'),
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      unreadCount: _asInt(json['unreadCount']),
      avatarUrl: _asNullableString(json['avatarUrl']),
      targetUrl: _asNullableString(json['targetUrl']),
      badge: _asNullableString(json['badge']),
    );
  }

  AppMessage copyWith({int? unreadCount}) {
    return AppMessage(
      sourceId: sourceId,
      category: category,
      title: title,
      content: content,
      occurredAt: occurredAt,
      unreadCount: unreadCount ?? this.unreadCount,
      avatarUrl: avatarUrl,
      targetUrl: targetUrl,
      badge: badge,
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _asNullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
