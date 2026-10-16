import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/job_favorite_api.dart';

class JobFavoriteController extends ChangeNotifier {
  JobFavoriteController(this.api, this.token, this.positionId);
  final JobFavoriteApi api;
  final String token;
  final int positionId;

  bool favorited = false, loaded = false, loading = false, saving = false;
  String? error;
  bool _disposed = false;

  Future<void> load() async {
    if (loading || saving || _disposed) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await api.state(token, positionId);
      if (_disposed) return;
      favorited = result;
      loaded = true;
    } on ApiException catch (failure) {
      if (_disposed) return;
      error = failure.message;
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<String?> toggle() async {
    if (!loaded || loading || saving || _disposed) return null;
    saving = true;
    notifyListeners();
    try {
      final result = await api.setFavorited(token, positionId, !favorited);
      if (_disposed) return null;
      favorited = result;
      return result ? '已收藏职位' : '已取消收藏';
    } on ApiException catch (failure) {
      return _disposed ? null : failure.message;
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
