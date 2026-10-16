import '../../../config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/job.dart';

class JobApi {
  const JobApi(this._client);

  final ApiClient _client;

  Future<HomeFeed> fetchHome(String token, {String? filter}) async {
    final query = filter == null
        ? ''
        : '?filter=${Uri.encodeQueryComponent(filter)}';
    final json = await _client.get('/app/home$query', token: token);
    final data = json['data'];
    if (data is! Map) throw const ApiException('首页数据格式不正确');
    return HomeFeed.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<Job>> searchJobs(
    String token, {
    String? keyword,
    String? filter,
  }) async {
    final parameters = <String, String>{
      if (keyword?.trim().isNotEmpty == true) 'keyword': keyword!.trim(),
      'limit': '30',
    };
    if (filter != null) parameters['filter'] = filter;
    final query = Uri(queryParameters: parameters).query;
    final json = await _client.get('/app/jobs?$query', token: token);
    final data = json['data'];
    if (data is! List) throw const ApiException('职位列表格式不正确');
    return data
        .whereType<Map>()
        .map((item) => Job.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> apply(String token, int positionId) async {
    await _client.post('/app/jobs/$positionId/apply', token: token);
  }

  Future<List<Job>> recommendJobs(
    String token, {
    required int resumeId,
    String? keyword,
    String? filter,
    int? limit,
  }) async {
    final body = <String, dynamic>{'resumeId': resumeId};
    if (keyword?.trim().isNotEmpty == true) body['keyword'] = keyword!.trim();
    if (filter != null) body['filter'] = filter;
    if (limit != null) body['limit'] = limit;
    final json = await _client.post(
      '/app/recommend',
      body: body,
      token: token,
      timeout: AppConfig.aiRequestTimeout,
    );
    final data = json['data'];
    if (data is! List) throw const ApiException('推荐结果格式不正确');
    return data
        .whereType<Map>()
        .map((item) => Job.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
