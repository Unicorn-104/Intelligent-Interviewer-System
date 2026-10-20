import 'talent_detail_view_data.dart';

class TalentWorkflowStage {
  const TalentWorkflowStage({
    required this.id,
    required this.name,
    required this.order,
    this.attended = false,
    this.current = false,
  });
  final int id, order;
  final String name;
  final bool attended, current;
}

/// 只关联当前岗位、当前候选人的有据记录，不用阶段顺序、时间经过或录用状态推断参加。
List<TalentWorkflowStage> talentWorkflowStages({
  required Map<String, dynamic> workflow,
  required List<Map<String, dynamic>> appointments,
  required int candidateId,
  required int positionId,
  required Map<int, Map<String, dynamic>> sessions,
  String? currentStage,
}) {
  final raw = workflow['stages'];
  if (raw is! List) throw const FormatException('招聘流程格式不正确');
  final rows = <({int id, String name, int order, int index})>[];
  final ids = <int>{};
  for (var index = 0; index < raw.length; index++) {
    final row = raw[index];
    if (row is! Map) throw const FormatException('招聘阶段格式不正确');
    final id = talentId(row['stageId']);
    final name = row['name']?.toString().trim() ?? '';
    if (id == null || name.isEmpty || !ids.add(id)) {
      throw const FormatException('招聘阶段标识或名称无效');
    }
    rows.add((
      id: id,
      name: name,
      order: int.tryParse('${row['sortOrder']}') ?? index + 1,
      index: index,
    ));
  }
  rows.sort((a, b) {
    final result = a.order.compareTo(b.order);
    return result == 0 ? a.index.compareTo(b.index) : result;
  });
  final attended = <int>{};
  for (final item in appointments) {
    if (talentId(item['candidateId']) != candidateId ||
        talentId(item['positionId']) != positionId) {
      continue;
    }
    final id = talentId(item['stageId']);
    final status = int.tryParse('${item['status']}');
    if (id == null || !ids.contains(id) || status == 2) continue;
    if (status == 3) {
      attended.add(id);
      continue;
    }
    final sessionId = talentId(item['sessionId']);
    final session = sessions[sessionId];
    if (session == null || sessionId == null) continue;
    final sessionStatus = int.tryParse('${session['status']}');
    if (talentId(session['sessionId']) == sessionId &&
        talentId(session['appointmentId']) == talentId(item['appointmentId']) &&
        talentId(item['appointmentId']) != null &&
        talentId(session['candidateId']) == candidateId &&
        talentId(session['positionId']) == positionId &&
        (sessionStatus == 1 || sessionStatus == 2) &&
        TalentUtc8.parseServer(session['startAt']) != null) {
      attended.add(id);
    }
  }
  final currentName = currentStage?.trim();
  final uniqueCurrent =
      rows.where((row) => row.name == currentName).length == 1;
  return List.unmodifiable(
    rows.map(
      (row) => TalentWorkflowStage(
        id: row.id,
        name: row.name,
        order: row.order,
        attended: attended.contains(row.id),
        current: uniqueCurrent && row.name == currentName,
      ),
    ),
  );
}
