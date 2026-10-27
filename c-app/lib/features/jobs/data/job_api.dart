import 'dart:convert';

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

  Future<Job> fetchSharedJob(String token, int positionId) async {
    final json = await _client.get('/agent/v1/jobs/$positionId', token: token);
    final raw = json['data'];
    if (raw is! Map || int.tryParse('${raw['id']}') != positionId) {
      throw const ApiException('岗位详情不匹配，请重新打开');
    }
    String lines(Object? value) => value is List
        ? value.map((s) => s.toString()).join('\n')
        : value?.toString() ?? '';
    final responsibilities = lines(raw['responsibilities']),
        requirements = lines(raw['requirements']);
    var description = raw['description']?.toString() ?? '';
    if (description.isEmpty && raw['jdJson'] is String) {
      try {
        final jd = jsonDecode(raw['jdJson'] as String);
        if (jd is Map && jd['description'] is String) {
          description = jd['description'] as String;
        }
      } catch (_) {
        // 已有JD结构化字段仍可展示，损坏的可选描述不阻断岗位查看。
      }
    }
    return Job.fromJson({
      'positionId': positionId,
      'companyId': raw['companyId'],
      'title': raw['title'],
      'company': raw['companyName'],
      'city': raw['workCity'],
      'salaryMin': raw['salaryMin'],
      'salaryMax': raw['salaryMax'],
      'experience': raw['experienceRequired'],
      'education': raw['educationRequired'],
      'educationText': raw['educationText'],
      'tags': raw['skills'],
      'applied': raw['appliedFlag'] == 1 || raw['appliedFlag'] == true,
      'available': raw['statusCode'] == 1,
      'matchScore': raw['matchScore'],
      'description': [
        if (description.isNotEmpty) description,
        if (responsibilities.isNotEmpty) '岗位职责\n$responsibilities',
        if (requirements.isNotEmpty) '任职要求\n$requirements',
      ].join('\n\n'),
    });
  }

  Future<void> apply(String token, int positionId, {int? resumeId}) async {
    await _client.post(
      '/app/jobs/$positionId/apply',
      token: token,
      body: resumeId == null ? null : {'resumeId': resumeId},
    );
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
