import '../../../../core/network/enterprise_api_client.dart';
import '../../jobs/models/job_detail_view_data.dart';
import '../models/chat_context.dart';
import '../models/message_view_data.dart';

/// Adapts existing enterprise-scoped APIs; never equates peerId with talentId.
/// IM sessions are user-to-user, not job-bound, so multiple applications require
/// an explicit UI selection rather than silently selecting the first job.
class ChatContextDataSource {
  const ChatContextDataSource({required this.client});
  final EnterpriseApiClient client;

  Future<List<Map<String, dynamic>>> _pages(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    final found = <Map<String, dynamic>>[];
    for (var page = 1; page <= 100; page++) {
      final response = await client.get(
        path,
        query: {...query, 'pageNum': page, 'pageSize': 50},
      );
      final rows = messageRows(response['rows']);
      found.addAll(rows);
      final total = int.tryParse('${response['total']}');
      if (rows.isEmpty ||
          (total != null ? found.length >= total : rows.length < 50)) {
        return found;
      }
    }
    throw const FormatException('应聘记录较多，暂无法完整读取，请稍后重试');
  }

  Future<ChatContext> load(Map<String, dynamic> session) async {
    final peerId = messageId(session['peerId']);
    if (peerId == null) throw const FormatException('会话缺少对方账号，请返回刷新');
    final listed = await _pages('/system/enterprise/jobs/list');
    final ids = <int>{};
    for (final row in listed) {
      final id = messageId(row['posId']);
      if (id == null) throw const FormatException('岗位资料缺少有效编号');
      ids.add(id);
    }
    final jobs = <ChatJob>[];
    final talents = <int, Map<String, dynamic>>{};
    final positions = ids.toList();
    // Bound concurrency and fetch only once on entry, never on chat polling.
    for (var start = 0; start < positions.length; start += 4) {
      final responses = await Future.wait(
        positions.skip(start).take(4).map((id) async {
          final response = await client.get('/system/enterprise/jobs/$id');
          final detail = JobDetailViewData.fromJson(
            jobObject(response['data'], '岗位'),
          );
          if (messageId(detail.job['posId']) != id) {
            throw const FormatException('岗位资料编号不一致，请重试');
          }
          return detail;
        }),
      );
      for (final detail in responses) {
        final matches = detail.candidates.where(
          (row) => messageId(row['userId']) == peerId,
        );
        final candidateIds = matches
            .map((row) => messageId(row['talId']))
            .toSet();
        if (candidateIds.isEmpty) continue;
        if (candidateIds.contains(null) || candidateIds.length != 1) {
          throw const FormatException('求职者应聘资料关联异常，请联系管理员核实');
        }
        final talent = <String, dynamic>{
          ...matches.first,
          'talentId': candidateIds.single!,
        };
        talents[candidateIds.single!] = talent;
        jobs.add(ChatJob(job: detail.job, talent: talent));
      }
    }
    if (jobs.isEmpty) {
      // Talent-pool-only contacts may have no active recruitment process.
      // Name is only a search hint; every identity is checked by exact user ID.
      final name = messageText(session['peerName'], '');
      final pool = await _pages(
        '/enterprise/talent/list',
        query: {if (name.isNotEmpty) 'keyword': name},
      );
      final seen = <int>{};
      for (final row in pool) {
        final id = messageId(row['talentId']);
        if (id == null) throw const FormatException('求职者资料缺少有效编号');
        if (!seen.add(id)) continue;
        final response = await client.get('/enterprise/talent/$id');
        final talent = jobObject(response['data'], '求职者');
        if (messageId(talent['talentId']) != id) {
          throw const FormatException('求职者资料编号不一致，请重试');
        }
        if (messageId(talent['userId']) == peerId) talents[id] = talent;
      }
    }
    return ChatContext(
      jobs: jobs,
      talent: talents.length == 1 ? talents.values.single : null,
    );
  }
}
