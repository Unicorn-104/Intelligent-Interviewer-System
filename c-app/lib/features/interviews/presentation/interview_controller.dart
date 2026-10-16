import 'package:flutter/foundation.dart';

import '../../../core/formatters/backend_date.dart';
import '../../../core/network/api_exception.dart';
import '../data/interview_api.dart';
import '../domain/interview_schedule.dart';

class InterviewController extends ChangeNotifier {
  InterviewController(this.api, this.token, {DateTime Function()? now})
    : now = now ?? DateTime.now {
    final today = this.now();
    month = DateTime(today.year, today.month);
    selectedDate = dateKey(today);
  }
  final InterviewApi api;
  final String token;
  final DateTime Function() now;
  late DateTime month;
  late String selectedDate;
  List<InterviewSchedule> items = [];
  String? error;
  bool loading = false;
  bool initialized = false;
  bool _disposed = false;
  int _generation = 0;

  List<InterviewSchedule> get selectedItems =>
      items.where((item) => item.dayKey == selectedDate).toList();
  Set<String> get markedDates =>
      items.map((item) => item.dayKey).whereType<String>().toSet();
  List<InterviewSchedule> get upcoming {
    // The SQL returns unzoned wall-clock time. Preserve PC semantics rather
    // than treating it as UTC. Do not derive business status from this clock.
    final clock = now();
    return items.where((item) {
      final start = DateTime.tryParse(item.startAt ?? '');
      return item.statusText == '进行中' ||
          (item.statusText != '已结束' && start != null && !start.isBefore(clock));
    }).toList();
  }

  Future<void> load() async {
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await api.schedule(token, month);
      if (_disposed || generation != _generation) return;
      result.sort((a, b) {
        final order = (a.startAt ?? '').compareTo(b.startAt ?? '');
        return order != 0 ? order : a.appointmentId.compareTo(b.appointmentId);
      });
      items = result;
      initialized = true;
    } catch (exception) {
      if (_disposed || generation != _generation) return;
      error = exception is ApiException ? exception.message : '面试日程加载失败，请重试';
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> changeMonth(int offset) {
    month = DateTime(month.year, month.month + offset);
    selectedDate = dateKey(month);
    items = [];
    initialized = false;
    return load();
  }

  Future<void> today() {
    final clock = now();
    final nextMonth = DateTime(clock.year, clock.month);
    if (nextMonth != month) {
      items = [];
      initialized = false;
    }
    month = nextMonth;
    selectedDate = dateKey(clock);
    return load();
  }

  void select(DateTime date) {
    selectedDate = dateKey(date);
    notifyListeners();
  }

  void tick() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
