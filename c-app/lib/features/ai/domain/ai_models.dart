import 'dart:convert';

import '../../../core/network/api_exception.dart';
import '../../../models/job.dart';

class AiSession {
  const AiSession(this.id, this.title, {this.createdAt, this.pinned = false});
  final String id;
  final String title;
  final DateTime? createdAt;
  final bool pinned;
  factory AiSession.fromJson(Map<String, dynamic> json) => AiSession(
    json['id'] as String,
    json['title']?.toString() ?? '新会话',
    createdAt: DateTime.tryParse(
      json['createdAt']?.toString() ?? '',
    )?.toLocal(),
    pinned: json['pinned'] == true || json['pinned']?.toString() == '1',
  );
}

class AiMessage {
  AiMessage({
    required this.role,
    required this.content,
    this.runId,
    this.runStatus,
    this.cards = const [],
  });
  final String role;
  final String content;
  final String? runId;
  final String? runStatus;
  final List<Job> cards;

  factory AiMessage.fromJson(Map<String, dynamic> json) {
    final raw = json['cardsJson'];
    return AiMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      runId: json['runId'] as String?,
      runStatus: json['runStatus'] as String?,
      cards: readJobCards(raw is String ? jsonDecode(raw) : raw),
    );
  }
}

List<Job> readJobCards(Object? value) => value is List
    ? value.whereType<Map>().map((item) {
        final json = Map<String, dynamic>.from(item);
        return Job.fromJson({...json, 'matchAvailable': false});
      }).toList()
    : const [];

class AiEvent {
  const AiEvent(this.id, this.type, this.data);
  final int id;
  final String type;
  final Map<String, dynamic> data;
}

/// Handles comments, multiple data lines, and arbitrary HTTP chunk boundaries.
Stream<AiEvent> decodeAiEvents(Stream<String> lines) async* {
  var id = 0;
  var type = 'message';
  var size = 0;
  final data = <String>[];
  await for (final line in lines) {
    if (line.isEmpty) {
      if (data.isNotEmpty) {
        final value = jsonDecode(data.join('\n'));
        if (value is! Map<String, dynamic>) {
          throw const ApiException('AI 响应格式不正确');
        }
        yield AiEvent(id, type, value);
      }
      id = 0;
      type = 'message';
      size = 0;
      data.clear();
      continue;
    }
    if (line.startsWith(':')) continue;
    final split = line.indexOf(':');
    final field = split < 0 ? line : line.substring(0, split);
    var value = split < 0 ? '' : line.substring(split + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'id':
        id = int.tryParse(value) ?? 0;
      case 'event':
        type = value;
      case 'data':
        size += value.length;
        if (size > 100000) throw const ApiException('AI 响应过长');
        data.add(value);
    }
  }
}

String aiRunError(String? code) => switch (code) {
  'OUTPUT_LIMIT' => '回答已达到长度上限，请将问题拆分后重试',
  'CONNECTION_FAILED' => 'AI 服务连接失败，请检查网络后重新生成',
  'TIMEOUT' => '本次处理超时，请缩小问题范围后重试',
  'STEP_LIMIT' => '本次查找已达到上限，请明确岗位方向后重试',
  'BUSY' => 'AI 助手繁忙，请稍后重试',
  _ => '本次回答未完成，请稍后重试',
};
