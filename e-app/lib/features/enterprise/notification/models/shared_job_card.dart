import 'dart:convert';

class SharedJobCard {
  SharedJobCard._(this.data, this.positionId, this.title);
  final Map<String, dynamic> data;
  final int positionId;
  final String title;
  static SharedJobCard? parse(int type, String content) {
    if (type != 6) return null;
    try {
      final raw = jsonDecode(content);
      if (raw is! Map || raw['kind'] != 'job_card' || raw['version'] != 1) {
        return null;
      }
      final id = int.tryParse('${raw['positionId']}');
      final title = raw['title'];
      if (id == null || id <= 0 || title is! String || title.trim().isEmpty) {
        return null;
      }
      return SharedJobCard._(
        Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(raw)),
        id,
        title,
      );
    } catch (_) {
      return null;
    }
  }

  String text(String field, [String fallback = '']) =>
      data[field]?.toString().trim().isNotEmpty == true
      ? data[field].toString()
      : fallback;
  String get salary {
    final min = num.tryParse(text('salaryMin')),
        max = num.tryParse(text('salaryMax'));
    if (min == null && max == null) return '薪资面议';
    String value(num n) => n % 1 == 0 ? n.toInt().toString() : n.toString();
    if (min != null && max != null) return '${value(min)}–${value(max)} 元/月';
    return min != null ? '${value(min)} 元/月起' : '最高 ${value(max!)} 元/月';
  }

  String get education => switch (int.tryParse(text('education'))) {
    1 => '中专',
    2 => '大专',
    3 => '本科',
    4 => '硕士',
    5 => '博士',
    _ => '学历不限',
  };
}
