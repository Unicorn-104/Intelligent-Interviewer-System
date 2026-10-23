import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/job_search.dart';

class JobSearchApi {
  const JobSearchApi(this.client);
  final ApiClient client;

  Future<JobSearchPage> list(
    String token,
    JobSearchQuery query, {
    int page = 1,
    int size = 50,
  }) async {
    final parameters = Uri(queryParameters: query.parameters(page, size)).query;
    final response = await client.get(
      '/agent/v1/jobs?$parameters',
      token: token,
    );
    final data = response['data'];
    if (data is! Map) throw const ApiException('职位列表格式不正确，请重试');
    return JobSearchPage.fromJson(Map<String, dynamic>.from(data));
  }

  Future<JobFilterOptions> filterOptions(String token) async {
    final response = await client.get(
      '/agent/v1/jobs/filter-options',
      token: token,
    );
    final data = response['data'];
    if (data is! Map) throw const ApiException('筛选选项格式不正确，请重试');
    return JobFilterOptions.fromJson(Map<String, dynamic>.from(data));
  }
}
