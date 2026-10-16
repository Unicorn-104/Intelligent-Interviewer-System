import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../models/job.dart';
import '../data/company_api.dart';
import '../domain/company.dart';

class CompanyController extends ChangeNotifier {
  CompanyController(this.api, this.token, this.companyId);
  final CompanyApi api;
  final String token;
  final int companyId;
  Company? company;
  List<Job> jobs = [];
  String? error, jobsError;
  bool loading = false, loadingMore = false, saving = false, hasNext = false;
  bool failedLoadMore = false;
  int total = 0, _page = 0, _generation = 0;
  bool _disposed = false;
  final _appliedIds = <int>{};

  Future<void> refresh() async {
    if (_disposed || saving) return;
    final generation = ++_generation;
    loading = true;
    loadingMore = false;
    error = jobsError = null;
    failedLoadMore = false;
    notifyListeners();
    try {
      final result = await api.detail(token, companyId);
      if (_disposed || generation != _generation) return;
      company = result;
    } catch (exception) {
      if (!_disposed && generation == _generation) {
        error = _message(exception);
        company = null;
      }
    }
    if (_disposed || generation != _generation) return;
    if (company != null) {
      try {
        final result = await api.jobs(token, companyId);
        if (_disposed || generation != _generation) return;
        jobs = result.items.map(_withApplied).toList();
        _page = result.page;
        total = result.total;
        hasNext = result.hasNext;
      } catch (exception) {
        if (_disposed || generation != _generation) return;
        jobsError = _message(exception);
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_disposed || loading || loadingMore || !hasNext) return;
    final generation = _generation;
    loadingMore = true;
    jobsError = null;
    notifyListeners();
    try {
      final result = await api.jobs(token, companyId, page: _page + 1);
      if (_disposed || generation != _generation) return;
      final ids = jobs.map((job) => job.positionId).toSet();
      jobs = [
        ...jobs,
        ...result.items
            .where((job) => ids.add(job.positionId))
            .map(_withApplied),
      ];
      _page = result.page;
      total = result.total;
      hasNext = result.hasNext;
    } catch (exception) {
      if (!_disposed && generation == _generation) {
        jobsError = _message(exception);
        failedLoadMore = true;
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<String?> toggleFollow() async {
    if (_disposed || loading || saving || company == null) return null;
    saving = true;
    notifyListeners();
    try {
      final followed = await api.setFollowed(
        token,
        companyId,
        !company!.followed,
      );
      if (_disposed) return null;
      company = company!.withFollowed(followed);
      return followed ? '已收藏企业，新岗位将在消息中提醒' : '已取消收藏';
    } catch (exception) {
      return _message(exception);
    } finally {
      if (!_disposed) {
        saving = false;
        notifyListeners();
      }
    }
  }

  void markApplied(int id) {
    if (_disposed) return;
    _appliedIds.add(id);
    jobs = jobs.map(_withApplied).toList();
    notifyListeners();
  }

  Job _withApplied(Job job) =>
      _appliedIds.contains(job.positionId) ? job.copyWith(applied: true) : job;
  String _message(Object error) =>
      error is ApiException ? error.message : '加载失败，请重试';

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
