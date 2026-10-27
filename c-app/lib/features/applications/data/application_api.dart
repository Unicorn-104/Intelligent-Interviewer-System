import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/job_application.dart';

class ApplicationApi {
  const ApplicationApi(this.client);
  final ApiClient client;

  Future<ApplicationPage> list(
    String token, {
    int page = 1,
    int size = 10,
    String? status,
  }) async {
    final query = Uri(
      queryParameters: {'page': '$page', 'size': '$size', 'status': ?status},
    ).query;
    final response = await client.get(
      '/agent/v1/applications?$query',
      token: token,
    );
    final data = response['data'];
    if (data is! Map) throw const ApiException('投递列表格式不正确，请重试');
    return ApplicationPage.fromJson(Map<String, dynamic>.from(data));
  }

  Future<JobApplication> detail(String token, int applicationId) async {
    final response = await client.get(
      '/agent/v1/applications/$applicationId',
      token: token,
    );
    final data = response['data'];
    if (data is! Map) throw const ApiException('投递详情格式不正确，请重试');
    return JobApplication.fromJson(Map<String, dynamic>.from(data));
  }

  Future<JobApplication> withdraw(String token, int applicationId) async {
    final response = await client.post(
      '/agent/v1/applications/$applicationId/withdraw',
      token: token,
    );
    final data = response['data'];
    if (data is! Map) throw const ApiException('撤回结果格式不正确，请刷新后查看');
    return JobApplication.fromJson(Map<String, dynamic>.from(data));
  }
}
