class MessageSession {
  MessageSession._(
    this.raw,
    this.id,
    this.peerId,
    this.name,
    this.avatar,
    this.preview,
    this.time,
    this.unread,
  );
  factory MessageSession.fromJson(Map<String, dynamic> row) {
    final id = messageId(row['sessionId']);
    final peer = messageId(row['peerId']);
    if (id == null || peer == null) throw const FormatException('会话标识无效，请刷新');
    return MessageSession._(
      Map.unmodifiable(row),
      id,
      peer,
      messageText(row['peerName'], '用户'),
      messageText(row['peerAvatar'], ''),
      messageText(row['lastMessage'], '暂无消息'),
      messageTime(
        row['lastMessageAt'] ?? row['updateTime'] ?? row['createTime'],
      ),
      messageCount(row['unread']),
    );
  }
  final Map<String, dynamic> raw;
  final int id, peerId, unread;
  final String name, avatar, preview;
  final DateTime? time;
  MessageSession get read => MessageSession.fromJson({...raw, 'unread': 0});
}

class ConversationMessage {
  ConversationMessage._(
    this.id,
    this.mine,
    this.type,
    this.content,
    this.attachment,
    this.time,
  );
  factory ConversationMessage.fromJson(Map<String, dynamic> row) {
    final id = messageId(row['messageId']);
    final mine = row['isMine'];
    if (id == null || mine is! bool) {
      throw const FormatException('聊天记录格式不完整，请刷新');
    }
    return ConversationMessage._(
      id,
      mine,
      int.tryParse('${row['type']}') ?? 1,
      messageText(row['content'], ''),
      messageText(row['attachmentUrl'], ''),
      messageTime(row['sendTime']),
    );
  }
  final int id, type;
  final bool mine;
  final String content, attachment;
  final DateTime? time;
  String get display => switch (type) {
    2 => '[图片]${content.isEmpty ? '' : ' $content'}',
    3 => '[文件]${content.isEmpty ? '' : ' $content'}',
    _ => content.isEmpty ? '消息内容为空' : content,
  };
}

class SystemMessage {
  SystemMessage._(
    this.raw,
    this.id,
    this.title,
    this.content,
    this.isRead,
    this.time,
  );
  factory SystemMessage.fromJson(Map<String, dynamic> row) {
    final id = messageId(row['messageId']);
    if (id == null) throw const FormatException('通知标识无效');
    return SystemMessage._(
      Map.unmodifiable(row),
      id,
      messageText(row['title'], '系统通知'),
      messageText(row['content'], '暂无通知内容'),
      row['isRead'] == true || '${row['isRead']}' == '1',
      messageTime(row['createdAt']),
    );
  }
  final Map<String, dynamic> raw;
  final int id;
  final String title, content;
  final bool isRead;
  final DateTime? time;
  SystemMessage get read => SystemMessage.fromJson({...raw, 'isRead': 1});
}

class NotificationSlice {
  const NotificationSlice(this.items, this.unreadCount, this.hasMore);
  final List<SystemMessage> items;
  final int unreadCount;
  final bool hasMore;
}

int? messageId(Object? value) {
  final id = int.tryParse('$value');
  return id != null && id > 0 ? id : null;
}

int messageCount(Object? value) {
  final number = int.tryParse('$value');
  if (number == null || number < 0) throw const FormatException('未读数量格式不正确');
  return number;
}

String messageText(Object? value, [String fallback = '—']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

DateTime? messageTime(Object? value) {
  final raw = value?.toString().trim().replaceFirst(' ', 'T') ?? '';
  if (raw.isEmpty) return null;
  final offset = RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(raw);
  return DateTime.tryParse(offset ? raw : '$raw+08:00')?.toUtc();
}

String messageClock(DateTime? value) {
  if (value == null) return '时间未提供';
  final wall = value.toUtc().add(const Duration(hours: 8));
  return '${wall.hour.toString().padLeft(2, '0')}:${wall.minute.toString().padLeft(2, '0')}';
}

String messageDate(DateTime? value, {DateTime? now}) {
  if (value == null) return '—';
  final wall = value.toUtc().add(const Duration(hours: 8));
  final current = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 8));
  final gap = DateTime.utc(
    current.year,
    current.month,
    current.day,
  ).difference(DateTime.utc(wall.year, wall.month, wall.day)).inDays;
  if (gap == 0) return messageClock(value);
  if (gap == 1) return '昨天';
  if (gap > 1 && gap < 7) {
    return '周${['一', '二', '三', '四', '五', '六', '日'][wall.weekday - 1]}';
  }
  return wall.year == current.year
      ? '${wall.month}月${wall.day}日'
      : '${wall.year}/${wall.month}/${wall.day}';
}

List<Map<String, dynamic>> messageRows(Object? raw) {
  if (raw is! List || raw.any((row) => row is! Map)) {
    throw const FormatException('消息数据格式不正确');
  }
  return raw.map((row) => Map<String, dynamic>.from(row as Map)).toList();
}
