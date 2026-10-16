import 'dart:convert';

class TalentJobContext {
  const TalentJobContext({
    required this.positionId,
    required this.title,
    this.currentStage,
  });
  final int positionId;
  final String title;
  final String? currentStage;
}

class TalentSectionState<T> {
  TalentSectionState({this.data, this.error, this.loading = true});
  T? data;
  String? error;
  bool loading;
  int request = 0;
}

int? talentId(Object? value) {
  final id = int.tryParse('$value');
  return id != null && id > 0 ? id : null;
}

String talentText(Object? value, [String fallback = '未提供']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

num? talentNumber(Object? value) {
  final number = num.tryParse('$value');
  return number != null && number.isFinite ? number : null;
}

List<Map<String, dynamic>> talentRows(Object? value, String field) {
  if (value is! List || value.any((item) => item is! Map)) {
    throw FormatException('$field格式不正确');
  }
  return List.unmodifiable(
    value.map(
      (item) => Map<String, dynamic>.unmodifiable(
        Map<String, dynamic>.from(item as Map),
      ),
    ),
  );
}

String talentStatus(Object? value) => switch (int.tryParse('$value')) {
  0 => '新入库',
  1 => '初筛通过',
  2 => '面试中',
  3 => '已淘汰',
  4 => '已录用',
  5 => '已入职',
  6 => '已放弃',
  7 => '人才库',
  8 => '黑名单',
  9 => '流程挂起',
  _ => '状态未提供',
};

String talentDegree(Object? value) => switch (int.tryParse('$value')) {
  1 => '中专',
  2 => '大专',
  3 => '本科',
  4 => '硕士',
  5 => '博士',
  _ => '学历未填写',
};

class TalentMatchData {
  const TalentMatchData({
    required this.requiredSkills,
    this.result,
    this.currentStage,
  });
  final List<String> requiredSkills;
  final Map<String, dynamic>? result;
  final String? currentStage;

  factory TalentMatchData.fromResponses(
    int id,
    Map<String, dynamic> detail,
    Map<String, dynamic> profile,
    List<Map<String, dynamic>> results,
  ) {
    final candidates = talentRows(detail['candidates'] ?? <Object>[], '岗位求职者');
    Map<String, dynamic>? candidate;
    for (final row in candidates) {
      if (talentId(row['talId']) == id) {
        candidate = row;
        break;
      }
    }
    final skills = talentRows(profile['skills'] ?? <Object>[], '岗位技能');
    final requiredSkills = skills
        .where((skill) => int.tryParse('${skill['required']}') == 1)
        .map((skill) => talentText(skill['name'], ''))
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    Map<String, dynamic>? result;
    for (final row in results) {
      if (talentId(row['resultId']) == id && candidate != null) {
        result = row;
        break;
      }
    }
    return TalentMatchData(
      requiredSkills: List.unmodifiable(requiredSkills),
      result: result,
      currentStage: candidate?['currentStage']?.toString(),
    );
  }
}

/// All picker values represent UTC+8 wall time, independent of device timezone.
class TalentUtc8 {
  static DateTime wallTime(DateTime instant) =>
      instant.toUtc().add(const Duration(hours: 8));
  static DateTime fromSelection(DateTime date, int hour, int minute) =>
      DateTime.utc(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      ).subtract(const Duration(hours: 8));
  static String dateLabel(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static String serverTime(DateTime instant) {
    final wall = wallTime(instant);
    return '${dateLabel(wall)} ${wall.hour.toString().padLeft(2, '0')}:${wall.minute.toString().padLeft(2, '0')}:${wall.second.toString().padLeft(2, '0')}';
  }

  static DateTime? parseServer(Object? raw) {
    final text = raw?.toString().trim().replaceFirst(' ', 'T') ?? '';
    if (text.isEmpty) {
      return null;
    }
    final hasOffset = RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(text);
    return DateTime.tryParse(hasOffset ? text : '$text+08:00')?.toUtc();
  }

  static bool overlaps(
    DateTime start,
    DateTime end,
    DateTime busyStart,
    DateTime busyEnd,
  ) => start.isBefore(busyEnd) && end.isAfter(busyStart);
  static bool isBusy(
    List<Map<String, dynamic>> slots,
    DateTime start,
    DateTime end,
  ) {
    for (final slot in slots) {
      final status = int.tryParse('${slot['status']}');
      final slotStart = parseServer(slot['startTime']);
      final slotEnd = parseServer(slot['endTime']);
      if ((status != 0 && status != 1) ||
          slotStart == null ||
          slotEnd == null ||
          !slotEnd.isAfter(slotStart)) {
        throw const FormatException('面试官忙闲数据不完整，请刷新后再试');
      }
      if (status == 0 && overlaps(start, end, slotStart, slotEnd)) {
        return true;
      }
    }
    return false;
  }
}

String talentReportValue(Object? value) {
  if (value == null) {
    return '未提供';
  }
  if (value is Map || value is List) {
    return const JsonEncoder.withIndent('  ').convert(value);
  }
  return talentText(value);
}

String talentGreetingTemplate({required String name, TalentJobContext? job}) {
  final subject = job == null ? '与您沟通合适的职业机会' : '与您沟通「${job.title}」岗位';
  return '您好，$name！我们希望$subject。方便时欢迎介绍您的求职意向和可沟通时间，期待您的回复。';
}
