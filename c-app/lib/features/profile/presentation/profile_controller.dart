import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/domain/auth_session.dart';
import '../data/profile_api.dart';
import '../domain/user_profile.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(this._api, {required AuthSession session})
    : _token = session.token,
      _profile = UserProfile.fromSession(session);

  final ProfileApi _api;
  final String _token;

  UserProfile _profile;
  bool _loading = false;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _errorMessage;

  UserProfile get profile => _profile;
  bool get loading => _loading;
  bool get saving => _saving;
  bool get uploadingAvatar => _uploadingAvatar;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _profile = await _api.fetchProfile(_token);
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = '个人资料加载失败，请稍后重试';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> update(UserProfile nextProfile) async {
    if (_saving) return false;
    _saving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _profile = await _api.updateProfile(_token, nextProfile);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = '保存失败，请稍后重试';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> uploadAvatar(String filePath) async {
    if (_uploadingAvatar) return false;
    _uploadingAvatar = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final avatar = await _api.uploadAvatar(_token, filePath);
      _profile = _profile.copyWith(avatar: avatar);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = '头像上传失败，请稍后重试';
      return false;
    } finally {
      _uploadingAvatar = false;
      notifyListeners();
    }
  }
}
