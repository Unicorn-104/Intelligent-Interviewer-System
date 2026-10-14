import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/user_profile.dart';

class ProfileApi {
  const ProfileApi(this._client);

  final ApiClient _client;

  Future<UserProfile> fetchProfile(String token) async {
    final json = await _client.get('/app/profile', token: token);
    return _readProfile(json);
  }

  Future<UserProfile> updateProfile(String token, UserProfile profile) async {
    final json = await _client.put(
      '/app/profile',
      token: token,
      body: profile.toUpdateJson(),
    );
    return _readProfile(json);
  }

  Future<String> uploadAvatar(String token, String filePath) async {
    final json = await _client.postFile(
      '/system/user/profile/avatar',
      token: token,
      filePath: filePath,
      fieldName: 'avatarfile',
    );
    final imageUrl = json['imgUrl']?.toString().trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      throw const ApiException('头像上传响应格式不正确');
    }
    return imageUrl;
  }

  UserProfile _readProfile(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('个人资料响应格式不正确');
    }
    return UserProfile.fromJson(data);
  }
}
