import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/application_api.dart';
import '../domain/job_application.dart';

class ApplicationController extends ChangeNotifier {
  ApplicationController(this.api, this.token);
  final ApplicationApi api;
  final String token;

  List<JobApplication> items = [];
  String? status;
  String? error;
  bool loading = false;
  bool loadingMore = false;
  bool hasNext = false;
  bool initialized = false;
  int total = 0;
  int _page = 0;
  int _generation = 0;
  bool _disposed = false;
  bool _failedLoadMore = false;

  Future<void> retry() => _failedLoadMore ? loadMore() : refresh();

  Future<void> refresh({String? filter, bool changeFilter = false}) async {
    if (changeFilter) status = filter;
    final generation = ++_generation;
    loading = true;
    loadingMore = false;
    error = null;
    _failedLoadMore = false;
    if (changeFilter) {
      items = [];
      initialized = false;
      total = 0;
    }
    notifyListeners();
    try {
      final result = await api.list(token, status: status);
      if (_disposed || generation != _generation) return;
      items = result.items;
      _page = result.page;
      total = result.total;
      hasNext = result.hasNext;
      initialized = true;
    } catch (exception) {
      if (_disposed || generation != _generation) return;
      error = exception is ApiException ? exception.message : '投递记录加载失败，请重试';
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasNext) return;
    final generation = _generation;
    loadingMore = true;
    error = null;
    notifyListeners();
    try {
      final result = await api.list(token, page: _page + 1, status: status);
      if (_disposed || generation != _generation) return;
      final known = items.map((item) => item.id).toSet();
      items = [...items, ...result.items.where((item) => known.add(item.id))];
      _page = result.page;
      total = result.total;
      hasNext = result.hasNext;
    } catch (exception) {
      if (_disposed || generation != _generation) return;
      error = exception is ApiException ? exception.message : '更多投递记录加载失败，请重试';
      _failedLoadMore = true;
    } finally {
      if (!_disposed && generation == _generation) {
        loadingMore = false;
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
