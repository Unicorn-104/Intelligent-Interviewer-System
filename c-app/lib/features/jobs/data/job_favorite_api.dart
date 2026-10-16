import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/job_favorites_page.dart';

class JobFavoriteApi {
  const JobFavoriteApi(this.client);
  final ApiClient client;

  Future<Map<String, dynamic>> _data(
    Future<Map<String, dynamic>> request,
  ) async {
    try {
      final json = await request;
      final data = json['data'];
      if (data is! Map) throw const ApiException('收藏数据格式不正确，请重试');
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

  bool _state(Map<String, dynamic> data) {
    if (data['favorited'] is! bool) {
      throw const ApiException('收藏状态确认失败，请重试');
    }
    return data['favorited'] as bool;
  }

  Future<bool> state(String token, int positionId) async => _state(
    await _data(client.get('/app/jobs/$positionId/favorite', token: token)),
  );

  Future<bool> setFavorited(
    String token,
    int positionId,
    bool favorited,
  ) async => _state(
    await _data(
      client.put(
        '/app/jobs/$positionId/favorite',
        token: token,
        body: {'favorited': favorited},
      ),
    ),
  );

  Future<JobFavoritesPage> favorites(String token, {int page = 1}) async =>
      JobFavoritesPage.fromJson(
        await _data(
          client.get('/app/jobs/favorites?page=$page&size=20', token: token),
        ),
      );
}
