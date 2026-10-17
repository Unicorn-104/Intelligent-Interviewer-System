class HomeIdentity {
  const HomeIdentity({required this.company, required this.nickname});
  final String company;
  final String nickname;
}

String homeText(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int? homeCount(Object? value) {
  final number = num.tryParse('$value');
  if (number == null ||
      !number.isFinite ||
      number < 0 ||
      number != number.roundToDouble()) {
    return null;
  }
  return number.toInt();
}

class HomeStats {
  const HomeStats({
    this.activePositions,
    this.pendingInterviews,
    this.pendingReview,
    this.weeklyCompleted,
  });
  factory HomeStats.fromMap(Map<String, dynamic> data) => HomeStats(
    activePositions: homeCount(data['activePositions']),
    pendingInterviews: homeCount(data['pendingInterviews']),
    pendingReview: homeCount(data['pendingFinalReviews']),
    weeklyCompleted: homeCount(data['weeklyCompleted']),
  );
  final int? activePositions;
  final int? pendingInterviews;
  final int? pendingReview;
  final int? weeklyCompleted;
  List<(String, int?)> get values => [
    ('在招岗位', activePositions),
    ('待面试', pendingInterviews),
    ('待终审', pendingReview),
    ('本周完成', weeklyCompleted),
  ];
  bool get isEmpty => values.every((entry) => entry.$2 == null);
}

class HomeInterview {
  const HomeInterview({
    required this.raw,
    required this.startTime,
    required this.status,
  });
  final Map<String, dynamic> raw;
  final DateTime startTime;
  final int status;
  int? get positionId {
    final id = int.tryParse('${raw['positionId']}');
    return id != null && id > 0 ? id : null;
  }

  String get candidate => homeText(raw['candidateName'], '候选人信息未提供');
  String get position => homeText(raw['positionTitle'], '岗位信息未提供');
  String get id =>
      '${raw['appointmentId'] ?? '${startTime.toIso8601String()}-$candidate-$position'}';
  // The current backend exchanges timezone-less UTC+8 database timestamps.
  static DateTime _utc8WallTime(DateTime instant) =>
      instant.toUtc().add(const Duration(hours: 8));

  static String formatServerTime(DateTime instant) {
    final time = _utc8WallTime(instant);
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  String get timeLabel {
    final time = _utc8WallTime(startTime);
    return '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String get statusLabel => status == 0 ? '待面试' : '已确认';

  DateTime? get endTime {
    final text = homeText(raw['endTime'], '').replaceFirst(' ', 'T');
    if (text.isEmpty) return null;
    final offset = RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(text);
    return DateTime.tryParse(offset ? text : '$text+08:00');
  }

  bool isExpiredAt(DateTime now) {
    final end = endTime;
    return (status == 0 || status == 1) && end != null && !now.isBefore(end);
  }

  bool canStartAt(DateTime now) =>
      (status == 0 || status == 1) &&
      !now.isBefore(startTime) &&
      (endTime == null || now.isBefore(endTime!));

  /// Calendar dates are wall-clock days in the server's UTC+8 timezone.
  static HomeInterview? onDay(Map<String, dynamic> row, DateTime day) {
    final text = homeText(row['startTime'], '').replaceFirst(' ', 'T');
    final hasOffset = RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(text);
    final date = DateTime.tryParse(hasOffset ? text : '$text+08:00');
    if (date == null) return null;
    final local = _utc8WallTime(date);
    if (local.year != day.year ||
        local.month != day.month ||
        local.day != day.day) {
      return null;
    }
    return HomeInterview(
      raw: Map.unmodifiable(row),
      startTime: date,
      status: int.tryParse('${row['status']}') ?? -1,
    );
  }

  static HomeInterview? upcoming(Map<String, dynamic> row, DateTime from) {
    final text = homeText(row['startTime'], '').replaceFirst(' ', 'T');
    final hasOffset = RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(text);
    final date = DateTime.tryParse(hasOffset ? text : '$text+08:00');
    final status = int.tryParse('${row['status']}');
    if (date == null || date.isBefore(from) || (status != 0 && status != 1)) {
      return null;
    }
    return HomeInterview(
      raw: Map.unmodifiable(row),
      startTime: date,
      status: status!,
    );
  }
}

class HomeApplication {
  const HomeApplication(this.raw);
  final Map<String, dynamic> raw;
  int? get positionId => int.tryParse('${raw['posId']}');
  String get title => homeText(raw['title'], '岗位名称未提供');
  String get department => homeText(raw['dept'], '部门未提供');
  String get city => homeText(raw['city'], '城市未提供');
  int? get applicants => homeCount(raw['applicantCount']);
  String get salary {
    final low = num.tryParse('${raw['salaryMin']}');
    final high = num.tryParse('${raw['salaryMax']}');
    if (low == null && high == null) return '面议';
    String amount(num? value) => value == null
        ? '—'
        : (value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1);
    return '${amount(low)}-${amount(high)}K';
  }

  Map<String, dynamic> get detail => {
    ...raw,
    'title': title,
    'dept': department,
    'city': city,
    'salary': salary,
    'applicants': applicants ?? '—',
  };
}

class HomePageSlice<T> {
  const HomePageSlice(this.items, {this.nextPage});
  final List<T> items;
  final int? nextPage;
}
