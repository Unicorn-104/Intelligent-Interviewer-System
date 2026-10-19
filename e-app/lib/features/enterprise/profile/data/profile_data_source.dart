import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../config/app_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/enterprise_api_client.dart';
import '../models/profile_view_data.dart';

class ProfileAvatar {
  ProfileAvatar({required String name, required Uint8List bytes})
    : name = name.split(RegExp(r'[/\\]')).last,
      bytes = Uint8List.fromList(bytes).asUnmodifiableView() {
    validateSize(bytes.length);
    if (!mimeTypes.containsKey(extension)) {
      throw const FormatException('请选择 JPG、PNG、GIF、BMP 或 WEBP 图片');
    }
    final b = this.bytes;
    final matches = switch (extension) {
      'jpg' ||
      'jpeg' => b.length >= 3 && b[0] == 255 && b[1] == 216 && b[2] == 255,
      'png' => b.length >= 8 && base64Encode(b.sublist(0, 8)) == 'iVBORw0KGgo=',
      'gif' => b.length >= 6 && String.fromCharCodes(b.sublist(0, 3)) == 'GIF',
      'bmp' => b.length >= 2 && b[0] == 66 && b[1] == 77,
      'webp' =>
        b.length >= 12 &&
            String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
            String.fromCharCodes(b.sublist(8, 12)) == 'WEBP',
      _ => false,
    };
    if (!matches) throw const FormatException('图片内容与格式不符，请重新选择');
  }
  static const maxBytes = 5 * 1024 * 1024;
  static const mimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'bmp': 'image/bmp',
    'webp': 'image/webp',
  };
  final String name;
  final Uint8List bytes;
  String get extension => name.split('.').last.toLowerCase();
  String get mimeType => mimeTypes[extension]!;
  static void validateSize(int size) {
    if (size <= 0) throw const FormatException('图片为空，请重新选择');
    if (size >= maxBytes) throw const FormatException('头像图片须小于5MB');
  }
}

class ProfileDataSource {
  const ProfileDataSource({
    this.client,
    this.storage = const FlutterSecureStorage(),
  });
  final EnterpriseApiClient? client;
  final FlutterSecureStorage storage;
  EnterpriseApiClient get _client => client ?? EnterpriseApiClient();
  Future<void> _requireSession() async {
    final token = await storage.read(key: 'enterprise_access_token');
    if (token == null || token.isEmpty) {
      throw const ApiException('登录已失效，请退出后重新登录', code: 401);
    }
  }

  Future<EnterpriseProfile> loadProfile() async {
    await _requireSession();
    return EnterpriseProfile.fromResponse(
      await _client.get('/system/user/profile'),
    );
  }

  Future<void> saveProfile(Map<String, Object?> fields) async {
    await _requireSession();
    await _client.put(
      '/system/user/profile',
      body: {
        for (final key in ['nickName', 'phonenumber', 'email', 'sex', 'remark'])
          key: fields[key],
      },
    );
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    await _requireSession();
    await _client.put(
      '/system/user/profile/updatePwd',
      body: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );
  }

  Future<String> uploadAvatar(ProfileAvatar avatar) async {
    await _requireSession();
    final Map<String, dynamic> response;
    try {
      response = await _client.uploadFile(
        '/system/user/profile/avatar',
        filename: avatar.name,
        bytes: avatar.bytes,
        fieldName: 'avatarfile',
        mimeType: avatar.mimeType,
      );
    } on ApiException catch (error) {
      if (!error.isUnauthorized &&
          (error.message.contains('JD') || error.message.contains('文档'))) {
        throw const ApiException('头像上传失败，请检查图片或稍后重试');
      }
      rethrow;
    }
    final url = response['imgUrl'];
    if (url is! String || url.trim().isEmpty) {
      throw const ApiException('服务未返回头像地址，请刷新资料核对上传结果');
    }
    return url;
  }

  Future<ProfileAvatar?> pickAvatar() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ProfileAvatar.mimeTypes.keys.toList(),
    );
    if (file == null) return null;
    if (!ProfileAvatar.mimeTypes.containsKey(
      file.name.split('.').last.toLowerCase(),
    )) {
      throw const FormatException('请选择 JPG、PNG、GIF、BMP 或 WEBP 图片');
    }
    final reported = file.lengthSync() ?? await file.length();
    if (reported != null) ProfileAvatar.validateSize(reported);
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      ProfileAvatar.validateSize(buffer.length + chunk.length);
      buffer.add(chunk);
    }
    final bytes = buffer.takeBytes();
    if (reported != null && reported != bytes.length) {
      throw const FormatException('图片读取不完整，请重新选择');
    }
    return ProfileAvatar(name: file.name, bytes: bytes);
  }

  Future<ProfilePreferences> loadPreferences(int userId) async =>
      ProfilePreferences.decode(
        await storage.read(key: 'enterprise_profile_preferences_$userId'),
      );
  Future<void> savePreferences(int userId, ProfilePreferences value) =>
      storage.write(
        key: 'enterprise_profile_preferences_$userId',
        value: jsonEncode(value.toJson()),
      );
  String? avatarUrl(String path) {
    if (path.isEmpty) return null;
    final uri = Uri.tryParse(path);
    if (uri == null) return null;
    final resolved = Uri.parse(AppConfig.apiBaseUrl).resolveUri(uri);
    if (!['http', 'https'].contains(resolved.scheme)) return null;
    return resolved.toString();
  }
}

String profileError(Object error) => switch (error) {
  ApiException() => error.isUnauthorized ? '登录已失效，请退出后重新登录' : error.message,
  FormatException() => error.message.toString(),
  _ => '操作失败，请稍后重试',
};
