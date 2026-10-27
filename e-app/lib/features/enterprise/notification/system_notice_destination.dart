import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../jobs/job_interviews_page.dart';
import '../jobs/data/job_detail_data_source.dart';
import '../talent/talent_detail_page.dart';
import '../talent/models/talent_detail_view_data.dart';
import 'data/message_data_source.dart';
import 'models/message_view_data.dart';

/// 客户端只接受服务端按通知与当前企业重新校验后的业务标识。
class SystemNoticeDestination {
  SystemNoticeDestination(Map<String, dynamic> data)
    : data = Map.unmodifiable(data) {
    id('messageId');
    id('candidateId');
    id('positionId');
    if (!['candidate', 'interview', 'report'].contains(kind)) {
      throw const FormatException('通知详情类型无效');
    }
    if (kind == 'candidate') id('applicationId');
    if (kind == 'interview') {
      id('appointmentId');
      if (messageTime(data['startTime']) == null) {
        throw const FormatException('面试时间不完整');
      }
    }
    if (kind == 'report') {
      id('evaluationId');
      id('sessionId');
    }
  }
  final Map<String, dynamic> data;
  String get kind => data['kind'].toString();
  int id(String key) {
    final value = messageId(data[key]);
    if (value == null) throw const FormatException('通知关联标识不完整');
    return value;
  }

  String get position => messageText(data['positionTitle'], '岗位详情');

  Widget page(MessageDataSource source) => switch (kind) {
    'candidate' => TalentDetailPage(
      talent: {'talentId': id('candidateId'), 'name': data['candidateName']},
      jobContext: TalentJobContext(
        positionId: id('positionId'),
        title: position,
      ),
      source: source.candidateDetailsSource,
    ),
    'interview' => JobInterviewsPage(
      positionId: id('positionId'),
      positionTitle: position,
      source: _NoticeInterviewSource(
        source,
        id('messageId'),
        id('appointmentId'),
      ),
    ),
    _ => _NoticeReportPage(data: data),
  };
}

class _NoticeInterviewSource extends JobDetailDataSource {
  const _NoticeInterviewSource(this.source, this.noticeId, this.appointmentId);
  final MessageDataSource source;
  final int noticeId, appointmentId;
  @override
  Future<List<Map<String, dynamic>>> loadInterviews({
    required int pageNum,
    int pageSize = 50,
    String? from,
    String? to,
  }) async {
    if (pageNum != 1) return [];
    final target = SystemNoticeDestination(
      await source.loadNotificationDestination(noticeId),
    );
    if (target.kind != 'interview' ||
        target.id('appointmentId') != appointmentId) {
      throw const FormatException('通知面试关联已变化，请刷新');
    }
    final start = messageTime(target.data['startTime']);
    final lower = messageTime(from), upper = messageTime(to);
    if (start == null ||
        lower != null && start.isBefore(lower) ||
        upper != null && start.isAfter(upper)) {
      return [];
    }
    return [target.data];
  }
}

class _NoticeReportPage extends StatelessWidget {
  const _NoticeReportPage({required this.data});
  final Map<String, dynamic> data;
  String value(Object? raw) {
    if (raw == null) return '';
    if (raw is Map) {
      return raw.entries
          .map((entry) => '${entry.key}：${value(entry.value)}')
          .join('\n');
    }
    if (raw is List) {
      return raw.map(value).where((s) => s.isNotEmpty).join('\n');
    }
    return raw.toString();
  }

  @override
  Widget build(BuildContext context) {
    Object? dimensions = data['dimensionScores'];
    if (dimensions is String) {
      try {
        dimensions = jsonDecode(dimensions);
      } catch (_) {
        dimensions = null;
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('面试报告')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            messageText(data['candidateName'], '候选人'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(messageText(data['positionTitle'], '岗位详情')),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'AI结果仅供参考',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          for (final entry in <String, Object?>{
            '综合评分': data['overallScore'],
            '维度评分': dimensions,
            '面试总结': data['summary'],
            '表现亮点': data['advantages'],
            '风险提示': data['risks'],
            '待提升项': data['gaps'],
          }.entries)
            if (value(entry.value).isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(value(entry.value)),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
