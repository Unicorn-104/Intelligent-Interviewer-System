import '../models/talent_detail_view_data.dart';
import 'talent_detail_data_source.dart';

class TalentStageReportNotice implements Exception {
  const TalentStageReportNotice(this.message);
  final String message;
}

class TalentStageSession {
  const TalentStageSession({
    required this.id,
    required this.appointmentId,
    required this.startedAt,
  });
  final int id, appointmentId;
  final DateTime startedAt;
}

/// 每次点击重新读取本轮预约与会话；不根据日期经过、阶段顺序或其他轮次推测报告。
Future<List<TalentStageSession>> loadTalentStageSessions({
  required TalentDetailDataSource source,
  required int candidateId,
  required int positionId,
  required int stageId,
}) async {
  final records = await source.loadCandidatePlan(candidateId, positionId);
  final matches = records
      .where(
        (row) =>
            talentId(row['candidateId']) == candidateId &&
            talentId(row['positionId']) == positionId &&
            talentId(row['stageId']) == stageId &&
            int.tryParse('${row['status']}') != 2,
      )
      .toList();
  final sessions = <int, TalentStageSession>{};
  var completedWithoutSession = false;
  for (final appointment in matches) {
    final sessionId = talentId(appointment['sessionId']);
    final appointmentId = talentId(appointment['appointmentId']);
    final status = int.tryParse('${appointment['status']}');
    if (sessionId == null) {
      if (status == 3) completedWithoutSession = true;
      continue;
    }
    // 会话失败不降级为未开始，也不尝试借用同候选人的另一轮报告。
    final session = await source.loadWorkflowSession(sessionId);
    if (appointmentId == null ||
        talentId(session['sessionId']) != sessionId ||
        talentId(session['appointmentId']) != appointmentId ||
        talentId(session['candidateId']) != candidateId ||
        talentId(session['positionId']) != positionId) {
      throw const FormatException('本轮面试记录不一致，请刷新后重试');
    }
    final startedAt = TalentUtc8.parseServer(session['startAt']);
    final sessionStatus = int.tryParse('${session['status']}');
    if (startedAt != null &&
        (sessionStatus == 1 || sessionStatus == 2 || sessionStatus == 3)) {
      sessions[sessionId] = TalentStageSession(
        id: sessionId,
        appointmentId: appointmentId,
        startedAt: startedAt,
      );
    } else if (status == 3) {
      completedWithoutSession = true;
    }
  }
  if (sessions.isEmpty) {
    throw TalentStageReportNotice(
      completedWithoutSession ? '本轮暂无可查看的AI总结报告' : '本轮还未进行面试',
    );
  }
  final sorted = sessions.values.toList()
    ..sort((a, b) {
      final result = b.startedAt.compareTo(a.startedAt);
      return result != 0 ? result : b.id.compareTo(a.id);
    });
  return List.unmodifiable(sorted);
}
