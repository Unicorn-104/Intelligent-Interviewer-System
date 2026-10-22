import '../../jobs/models/job_detail_view_data.dart';
import 'message_view_data.dart';

/// Only contains company-scoped applications verified against the IM peer user ID.
class ChatJob {
  ChatJob({
    required Map<String, dynamic> job,
    required Map<String, dynamic> talent,
  }) : job = Map.unmodifiable(job),
       talent = Map.unmodifiable(talent);
  final Map<String, dynamic> job, talent;
  int get id => messageId(job['posId'])!;
  String get title => messageText(job['title'], '岗位名称未填写');
  String get salary => jobSalary(job);
  String get requirements =>
      [
            job['city'],
            job['experience'],
            const {
                  0: '学历不限',
                  1: '中专',
                  2: '大专',
                  3: '本科',
                  4: '硕士',
                  5: '博士',
                }[int.tryParse('${job['education']}')] ??
                job['education'],
          ]
          .map((value) => messageText(value, ''))
          .where((value) => value.isNotEmpty)
          .join(' · ');
}

class ChatContext {
  ChatContext({List<ChatJob> jobs = const [], Map<String, dynamic>? talent})
    : jobs = List.unmodifiable(jobs),
      talent = talent == null ? null : Map.unmodifiable(talent);
  final List<ChatJob> jobs;
  final Map<String, dynamic>? talent;
}
