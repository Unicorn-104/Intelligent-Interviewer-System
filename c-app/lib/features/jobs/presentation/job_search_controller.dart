import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../models/job.dart';
import '../data/job_search_api.dart';
import '../domain/job_search.dart';

class JobSearchController extends ChangeNotifier {
  JobSearchController(
    this.api,
    this.token, {
    this.query = const JobSearchQuery(),
  });
  final JobSearchApi api;
  final String token;
  JobSearchQuery query;
  List<Job> items = [];
  JobFilterOptions? options;
  String? error, optionsError;
  bool loading = false, loadingMore = false, optionsLoading = false;
  bool initialized = false, hasNext = false;
  int? total;
  int _page = 0, _generation = 0;
  bool _disposed = false;
  bool _failedLoadMore = false;
  final Set<int> _appliedIds = {};

  /// Invalidate immediately when text changes, before the debounce fires.
  void prepare(JobSearchQuery next) {
    _generation++;
    query = next;
    items = [];
    total = null;
    initialized = false;
    hasNext = false;
    loading = true;
    loadingMore = false;
    error = null;
    notifyListeners();
  }

  Future<void> refresh({JobSearchQuery? next}) async {
    if (_disposed) return;
    if (next != null) prepare(next);
    final generation = ++_generation;
    loading = true;
    loadingMore = false;
    error = null;
    _failedLoadMore = false;
    notifyListeners();
    try {
      final result = await api.list(token, query);
      if (_disposed || generation != _generation) return;
      items = result.items.map(_withApplied).toList();
      _page = result.page;
      total = result.total;
      hasNext = result.hasNext;
      initialized = true;
    } catch (exception) {
      if (_disposed || generation != _generation) return;
      error = exception is ApiException ? exception.message : '职位加载失败，请重试';
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (_disposed || loading || loadingMore || !hasNext || error != null) {
      return;
    }
    final generation = _generation;
    loadingMore = true;
    notifyListeners();
    try {
      final result = await api.list(token, query, page: _page + 1);
      if (_disposed || generation != _generation) return;
      final known = items.map((item) => item.positionId).toSet();
      items = [
        ...items,
        ...result.items
            .where((item) => known.add(item.positionId))
            .map(_withApplied),
      ];
      _page = result.page;
      total = result.total;
      hasNext = result.hasNext;
    } catch (exception) {
      if (_disposed || generation != _generation) return;
      error = exception is ApiException ? exception.message : '更多职位加载失败，请重试';
      _failedLoadMore = true;
    } finally {
      if (!_disposed && generation == _generation) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> retryMore() async {
    error = null;
    await loadMore();
  }

  Future<void> retry() => _failedLoadMore ? retryMore() : refresh();

  Future<void> loadOptions() async {
    if (_disposed || optionsLoading) return;
    optionsLoading = true;
    optionsError = null;
    notifyListeners();
    try {
      final result = await api.filterOptions(token);
      if (!_disposed) options = result;
    } catch (exception) {
      if (!_disposed) {
        options = null;
        optionsError = exception is ApiException
            ? exception.message
            : '筛选选项加载失败，请重试';
      }
    } finally {
      if (!_disposed) {
        optionsLoading = false;
        notifyListeners();
      }
    }
  }

  Job _withApplied(Job job) =>
      _appliedIds.contains(job.positionId) ? job.copyWith(applied: true) : job;

  void markApplied(int id) {
    _appliedIds.add(id);
    if (_disposed) return;
    items = items.map(_withApplied).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
