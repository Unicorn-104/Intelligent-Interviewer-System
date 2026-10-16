// PC displays these wall-clock values as supplied, without timezone conversion.
String displayBackendDate(String? value) {
  if (value == null || value.isEmpty) return '暂无';
  final text = value.replaceFirst('T', ' ');
  return text.length > 16 ? text.substring(0, 16) : text;
}

String dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String scheduleTime(String? value) {
  if (value == null || value.length < 16) return '时间待定';
  return value.substring(11, 16);
}
