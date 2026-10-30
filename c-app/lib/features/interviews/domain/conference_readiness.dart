/// Participant rows are authoritative when present. `peerReady` in older
/// responses may refer to the last other participant (including an observer).
class ConferenceReadiness {
  const ConferenceReadiness({
    required this.selfReady,
    required this.peerReady,
    required this.peerPresent,
    required this.confirmed,
  });
  final bool selfReady, peerReady, peerPresent, confirmed;

  static bool ready(Object? value) =>
      value == true || value == 1 || value == '1' || value == 'true';

  factory ConferenceReadiness.fromJson(
    Map<String, dynamic> waiting,
    Map<String, dynamic> context,
    int userId,
  ) {
    if (waiting.isEmpty) {
      return const ConferenceReadiness(
        selfReady: false,
        peerReady: false,
        peerPresent: false,
        confirmed: false,
      );
    }
    final raw = waiting['participants'];
    if (raw is List) {
      final rows = raw.whereType<Map>().toList();
      final assigned = (context['interviewers'] as List? ?? const [])
          .whereType<Map>()
          .map((r) => '${r['userId']}')
          .toSet();
      final self = rows.where((r) => '${r['userId']}' == '$userId');
      final peers = rows
          .where(
            (r) =>
                '${r['userId']}' != '$userId' &&
                (r['role'] == 1 || r['role'] == '1' || r['role'] == 'HR') &&
                (assigned.isEmpty || assigned.contains('${r['userId']}')),
          )
          .toList();
      return ConferenceReadiness(
        selfReady: self.isNotEmpty
            ? ready(self.first['ready'])
            : ready(waiting['selfReady']),
        peerReady: peers.any((r) => ready(r['ready'])),
        peerPresent: peers.isNotEmpty,
        confirmed: true,
      );
    }
    return ConferenceReadiness(
      selfReady: ready(waiting['selfReady']),
      peerReady: ready(waiting['peerReady']),
      peerPresent:
          ready(waiting['peerReady']) ||
          (waiting['peer'] is Map && (waiting['peer'] as Map).isNotEmpty),
      confirmed: true,
    );
  }

  String get selfLabel => !confirmed
      ? '正在确认状态'
      : selfReady
      ? '已就绪'
      : '尚未就绪';
  String get peerLabel => !confirmed
      ? '正在确认状态'
      : peerReady
      ? '已就绪'
      : peerPresent
      ? '已进入，等待就绪'
      : '尚未进入本场等候室';
  String get hint => !confirmed
      ? '正在同步双方状态…'
      : selfReady && peerReady
      ? '双方已就绪，等待面试官开始面试。开始后将自动进入会议。'
      : selfReady
      ? '你已就绪，正在等待面试官进入并开始面试。请保持 App 在前台。'
      : '你的就绪状态尚未同步，请返回准备页重新进入。';
}
