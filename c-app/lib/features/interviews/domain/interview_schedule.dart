import '../../../core/network/api_exception.dart';

class InterviewSchedule {
  const InterviewSchedule({
    required this.appointmentId,
    required this.positionTitle,
    required this.companyName,
    required this.statusText,
    this.sessionId,
    this.positionId,
    this.startAt,
    this.endAt,
    this.appointmentStatus,
    this.sessionStatus,
    this.mode,
    this.roomToken,
  });

  final int appointmentId;
  final int? sessionId;
  final int? positionId;
  final String positionTitle;
  final String companyName;
  final String statusText;
  final String? startAt;
  final String? endAt;
  final int? appointmentStatus;
  final int? sessionStatus;
  final int? mode;
  // The API provides a token, not an absolute meeting URL. Never log it.
  final String? roomToken;

  String? get dayKey => startAt != null && startAt!.length >= 10
      ? startAt!.substring(0, 10)
      : null;

  factory InterviewSchedule.fromJson(Map<String, dynamic> json) {
    final appointmentId = int.tryParse('${json['appointmentId']}');
    if (appointmentId == null) throw const ApiException('面试日程格式不正确，请重试');
    return InterviewSchedule(
      appointmentId: appointmentId,
      sessionId: int.tryParse('${json['sessionId']}'),
      positionId: int.tryParse('${json['positionId']}'),
      positionTitle: json['positionTitle']?.toString() ?? '面试岗位',
      companyName: json['companyName']?.toString() ?? '企业',
      statusText: json['statusText']?.toString() ?? '待确认',
      startAt: json['startAt']?.toString(),
      endAt: json['endAt']?.toString(),
      appointmentStatus: int.tryParse('${json['appointmentStatus']}'),
      sessionStatus: int.tryParse('${json['sessionStatus']}'),
      mode: int.tryParse('${json['mode']}'),
      roomToken: json['roomToken']?.toString(),
    );
  }
}

class InterviewDetail {
  const InterviewDetail({
    required this.sessionId,
    this.companyName,
    this.positionTitle,
    this.appointmentStartAt,
    this.appointmentEndAt,
    this.interviewerName,
    this.roundNo,
    this.totalRounds,
    this.mode,
  });
  final int sessionId;
  final String? companyName;
  final String? positionTitle;
  final String? appointmentStartAt;
  final String? appointmentEndAt;
  final String? interviewerName;
  final int? roundNo;
  final int? totalRounds;
  final int? mode;

  factory InterviewDetail.fromJson(Map<String, dynamic> json) {
    final sessionId = int.tryParse('${json['sessionId']}');
    if (sessionId == null) throw const ApiException('面试详情格式不正确，请重试');
    return InterviewDetail(
      sessionId: sessionId,
      companyName: json['companyName']?.toString(),
      positionTitle: json['positionTitle']?.toString(),
      appointmentStartAt: json['appointmentStartAt']?.toString(),
      appointmentEndAt: json['appointmentEndAt']?.toString(),
      interviewerName: json['interviewerName']?.toString(),
      roundNo: int.tryParse('${json['roundNo']}'),
      totalRounds: int.tryParse('${json['totalRounds']}'),
      mode: int.tryParse('${json['mode']}'),
    );
  }
}

// Same labels as user-PC conference-prep.vue; mode is not onsite/remote.
String interviewModeLabel(int? mode) => switch (mode) {
  null => '面试模式待确认',
  1 => '纯 AI 面试',
  3 => 'AI + 多面试官',
  4 => '无 AI · 纯人工',
  _ => 'AI + HR 协同面试',
};
