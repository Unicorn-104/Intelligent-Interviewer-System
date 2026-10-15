import '../../../api/home_api.dart' as home_api;
import '../../../api/jobs_api.dart' as jobs_api;
import '../../../api/schedule_api.dart' as schedule_api;
import '../../../core/network/api_exception.dart';
import 'home_models.dart';

typedef HomeJobLoader =
    Future<List<Map<String, dynamic>>> Function({
      String? keyword,
      String? dept,
      int? status,
      required int pageNum,
      required int pageSize,
    });
typedef HomeInterviewLoader =
    Future<List<Map<String, dynamic>>> Function({
      int? status,
      String? from,
      String? to,
      required int pageNum,
      required int pageSize,
    });

/// Aggregates existing API functions and maps fields. No HTTP client lives here.
class HomeDataSource {
  HomeDataSource({
    Future<Map<String, dynamic>> Function()? overviewLoader,
    Future<Map<String, dynamic>> Function()? userLoader,
    Future<Map<String, dynamic>> Function()? companyLoader,
    Future<int> Function()? unreadLoader,
    HomeJobLoader? jobsLoader,
    HomeInterviewLoader? interviewsLoader,
    DateTime Function()? clock,
  }) : _overview = overviewLoader ?? home_api.getOverview,
       _user = userLoader ?? home_api.getCurrentUserInfo,
       _company = companyLoader ?? jobs_api.getJobPublishingOptions,
       _unread = unreadLoader ?? home_api.getNoticeUnreadCount,
       _jobs = jobsLoader ?? jobs_api.listJobs,
       _interviews = interviewsLoader ?? schedule_api.listInterviews,
       _clock = clock ?? DateTime.now;

  static const pageSize = 20;
  final Future<Map<String, dynamic>> Function() _overview;
  final Future<Map<String, dynamic>> Function() _user;
  final Future<Map<String, dynamic>> Function() _company;
  final Future<int> Function() _unread;
  final HomeJobLoader _jobs;
  final HomeInterviewLoader _interviews;
  final DateTime Function() _clock;

  Future<HomeIdentity> loadIdentity() async {
    final results = await Future.wait([_user(), _company()]);
    final company = results[1]['company'];
    if (company is! Map || homeText(company['name'], '').isEmpty) {
      throw const ApiException('企业信息暂不可用，请重试');
    }
    return HomeIdentity(
      company: '${company['name']}'.trim(),
      nickname: homeText(results[0]['nickName'], '招聘伙伴'),
    );
  }

  DateTime get now => _clock();

  Future<int> loadUnread() => _unread();

  Future<HomeStats> loadStats() async {
    final response = await _overview();
    final stats = response['stats'];
    if (stats is! Map) throw const ApiException('统计数据暂不可用，请重试');
    return HomeStats.fromMap(Map<String, dynamic>.from(stats));
  }

  Future<HomePageSlice<HomeApplication>> loadApplications({
    int page = 1,
  }) async {
    final rows = await _jobs(pageNum: page, pageSize: pageSize);
    return HomePageSlice(
      rows.map((row) => HomeApplication(Map.unmodifiable(row))).toList(),
      nextPage: rows.length < pageSize ? null : page + 1,
    );
  }

  Future<HomePageSlice<HomeInterview>> loadInterviews({
    int page = 1,
    int minimum = 3,
    DateTime? from,
  }) async {
    final boundary = from ?? _clock();
    final formatted =
        '${boundary.year}-${boundary.month.toString().padLeft(2, '0')}-${boundary.day.toString().padLeft(2, '0')} '
        '${boundary.hour.toString().padLeft(2, '0')}:${boundary.minute.toString().padLeft(2, '0')}:${boundary.second.toString().padLeft(2, '0')}';
    final items = <String, HomeInterview>{};
    var current = page;
    int? next;
    String? previousPage;
    do {
      final rows = await _interviews(
        from: formatted,
        pageNum: current,
        pageSize: pageSize,
      );
      final signature = rows
          .map(
            (row) =>
                '${row['appointmentId']}-${row['startTime']}-${row['status']}',
          )
          .join('|');
      if (rows.isNotEmpty && signature == previousPage) {
        throw const ApiException('面试列表暂时无法继续加载，请重试');
      }
      previousPage = signature;
      for (final row in rows) {
        final item = HomeInterview.upcoming(row, boundary);
        if (item != null) items[item.id] = item;
      }
      next = rows.length < pageSize ? null : current + 1;
      current++;
    } while (items.length < minimum && next != null);
    final sorted = items.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return HomePageSlice(sorted, nextPage: next);
  }
}
