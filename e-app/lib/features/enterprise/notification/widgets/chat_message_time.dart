import 'package:flutter/material.dart';

DateTime _wall(DateTime time) => time.toUtc().add(const Duration(hours: 8));

bool showChatTimestamp(DateTime? current, DateTime? previous) {
  if (current == null) return false;
  if (previous == null) return true;
  final currentDay = _wall(current), previousDay = _wall(previous);
  return currentDay.year != previousDay.year ||
      currentDay.month != previousDay.month ||
      currentDay.day != previousDay.day ||
      current.difference(previous).inMinutes >= 5;
}

String chatTimestamp(DateTime instant, {DateTime? now}) {
  final time = _wall(instant);
  final today = DateUtils.dateOnly(_wall(now ?? DateTime.now()));
  final day = DateUtils.dateOnly(time);
  final clock =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  if (day == today) return clock;
  if (day == DateTime(today.year, today.month, today.day - 1)) {
    return '昨天 $clock';
  }
  if (day.year == today.year) return '${time.month}月${time.day}日 $clock';
  return '${time.year}年${time.month}月${time.day}日 $clock';
}

String fullChatTimestamp(DateTime instant) {
  final time = _wall(instant);
  return '${time.year}年${time.month}月${time.day}日 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
}
