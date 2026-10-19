import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../models/job.dart';
import '../data/job_favorite_api.dart';

class JobFavoritesController extends ChangeNotifier {
  JobFavoritesController(this.api, this.token);
  final JobFavoriteApi api;
  final String token;

  List<Job> items = [];
  bool loading = false, loaded = false, hasNext = false, failedMore = false;
  int page = 0;
  int? removingId;
  String? error;
  int _generation = 0;
  bool _disposed = false;

  Future<void> load({bool more = false}) => _load(more: more);

  Future<void> _load({bool more = false, bool afterRemoval = false}) async {
    if (_disposed ||
        (removingId != null && !afterRemoval) ||
        (more && (loading || !hasNext))) {
      return;
    }
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await api.favorites(token, page: more ? page + 1 : 1);
      if (_disposed || generation != _generation) return;
      final ids = more ? items.map((job) => job.positionId).toSet() : <int>{};
      items = [
        if (more) ...items,
        ...result.items.where((job) => ids.add(job.positionId)),
      ];
      page = result.page;
      hasNext = result.hasNext;
      loaded = true;
    } on ApiException catch (failure) {
      if (_disposed || generation != _generation) return;
      error = failure.message;
      failedMore = more;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<String?> remove(Job job) async {
    if (_disposed || removingId != null) return null;
    // 取消收藏后重新从第一页分页，避免偏移变化漏掉下一页的职位。
    _generation++;
    loading = false;
    removingId = job.positionId;
    notifyListeners();
    try {
      final favorited = await api.setFavorited(token, job.positionId, false);
      if (_disposed) return null;
      if (favorited) return '暂未取消收藏，请重试';
      items = items.where((item) => item.positionId != job.positionId).toList();
      hasNext = false;
      await _load(afterRemoval: true);
      return _disposed ? null : '已取消收藏';
    } on ApiException catch (failure) {
      return _disposed ? null : failure.message;
    } finally {
      if (!_disposed) {
        removingId = null;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
