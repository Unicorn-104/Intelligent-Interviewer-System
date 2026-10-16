import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../jobs/domain/job_search.dart';
import '../domain/company.dart';

class CompanyApi {
  const CompanyApi(this.client);
  final ApiClient client;

  Future<Map<String, dynamic>> _data(
    Future<Map<String, dynamic>> request,
  ) async {
    try {
      final json = await request;
      final data = json['data'];
      if (data is! Map) throw const ApiException('企业数据格式不正确，请重试');
      return Map<String, dynamic>.from(data);
    } on ApiException catch (error) {
      if (error.code == 500 || (error.statusCode ?? 0) >= 500) {
        throw ApiException(
          '服务暂时不可用，请稍后重试',
          code: error.code,
          statusCode: error.statusCode,
        );
      }
      rethrow;
    }
  }

  Future<Company> detail(String token, int id) async => Company.fromJson(
    await _data(client.get('/app/companies/$id', token: token)),
  );

  Future<JobSearchPage> jobs(String token, int id, {int page = 1}) async =>
      JobSearchPage.fromJson(
        await _data(
          client.get(
            '/app/companies/$id/jobs?page=$page&size=10',
            token: token,
          ),
        ),
      );

  Future<bool> setFollowed(String token, int id, bool followed) async {
    final data = await _data(
      client.put(
        '/app/companies/$id/follow',
        token: token,
        body: {'followed': followed},
      ),
    );
    if (data['followed'] is! bool) throw const ApiException('收藏状态确认失败，请刷新后重试');
    return data['followed'] as bool;
  }

  Future<CompanyPage> favorites(String token, {int page = 1}) async =>
      CompanyPage.fromJson(
        await _data(
          client.get(
            '/app/companies/favorites?page=$page&size=20',
            token: token,
          ),
        ),
      );
}
