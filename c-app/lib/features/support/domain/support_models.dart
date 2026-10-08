class HelpArticle {
  const HelpArticle({
    required this.articleId,
    required this.category,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.keywords,
  });

  final int articleId;
  final String category;
  final String title;
  final String content;
  final String? keywords;
  final DateTime updatedAt;

  factory HelpArticle.fromJson(Map<String, dynamic> json) {
    return HelpArticle(
      articleId: _asInt(json['articleId']),
      category: json['category']?.toString().trim() ?? '',
      title: json['title']?.toString().trim() ?? '',
      content: json['content']?.toString().trim() ?? '',
      keywords: _asNullableString(json['keywords']),
      updatedAt: _asDateTime(json['updatedAt']),
    );
  }
}

class FeedbackRecord {
  const FeedbackRecord({
    required this.feedbackId,
    required this.type,
    required this.typeLabel,
    required this.subject,
    required this.description,
    required this.status,
    required this.statusLabel,
    required this.createdAt,
    this.reply,
  });

  final int feedbackId;
  final int type;
  final String typeLabel;
  final String subject;
  final String description;
  final int status;
  final String statusLabel;
  final String? reply;
  final DateTime createdAt;

  factory FeedbackRecord.fromJson(Map<String, dynamic> json) {
    final type = _asInt(json['type']);
    final status = _asInt(json['status']);
    return FeedbackRecord(
      feedbackId: _asInt(json['feedbackId']),
      type: type,
      typeLabel:
          _asNullableString(json['typeLabel']) ?? _feedbackTypeLabel(type),
      subject: json['subject']?.toString().trim() ?? '',
      description: json['description']?.toString().trim() ?? '',
      status: status,
      statusLabel:
          _asNullableString(json['statusLabel']) ??
          _feedbackStatusLabel(status),
      reply: _asNullableString(json['reply']),
      createdAt: _asDateTime(json['createdAt']),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _asNullableString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

DateTime _asDateTime(Object? value) {
  return DateTime.tryParse((value?.toString() ?? '').replaceFirst(' ', 'T')) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

String _feedbackTypeLabel(int type) {
  return switch (type) {
    1 => '功能建议',
    2 => 'Bug反馈',
    3 => '投诉',
    _ => '其他',
  };
}

String _feedbackStatusLabel(int status) {
  return switch (status) {
    1 => '处理中',
    2 => '已处理',
    _ => '待处理',
  };
}
