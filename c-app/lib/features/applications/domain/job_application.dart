import '../../../core/network/api_exception.dart';

class JobApplication {
  const JobApplication({
    required this.id,
    required this.jobTitle,
    required this.companyName,
    required this.status,
    required this.statusText,
    this.jobId,
    this.resumeId,
    this.statusCode,
    this.appliedAt,
    this.updatedAt,
    this.locationText,
    this.salaryText,
    this.resumeName,
    this.matchedScore,
    this.timeline = const [],
  });

  final int id;
  final int? jobId;
  final int? resumeId;
  final String jobTitle;
  final String companyName;
  final String status;
  final String statusText;
  final int? statusCode;
  final String? appliedAt;
  final String? updatedAt;
  final String? locationText;
  final String? salaryText;
  final String? resumeName;
  final num? matchedScore;
  final List<ApplicationTimeline> timeline;

  factory JobApplication.fromJson(Map<String, dynamic> json) {
    final id = int.tryParse('${json['id']}');
    if (id == null) throw const ApiException('投递记录格式不正确，请重试');
    return JobApplication(
      id: id,
      jobId: int.tryParse('${json['jobId']}'),
      resumeId: int.tryParse('${json['resumeId']}'),
      jobTitle: json['jobTitle']?.toString() ?? '岗位',
      companyName: json['companyName']?.toString() ?? '企业',
      status: json['status']?.toString() ?? '',
      statusText: json['statusText']?.toString() ?? '待处理',
      statusCode: int.tryParse('${json['statusCode']}'),
      appliedAt: json['appliedAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      locationText: json['locationText']?.toString(),
      salaryText: json['salaryText']?.toString(),
      resumeName: json['resumeName']?.toString(),
      matchedScore: num.tryParse('${json['matchedScore']}'),
      timeline: (json['timeline'] as List? ?? const []).map((node) {
        if (node is! Map) throw const ApiException('投递进度格式不正确，请重试');
        return ApplicationTimeline.fromJson(Map<String, dynamic>.from(node));
      }).toList(),
    );
  }
}

class ApplicationTimeline {
  const ApplicationTimeline({
    required this.stage,
    required this.state,
    required this.title,
    this.description,
    this.occurredAt,
  });

  final String stage;
  final String state;
  final String title;
  final String? description;
  final String? occurredAt;

  factory ApplicationTimeline.fromJson(Map<String, dynamic> json) =>
      ApplicationTimeline(
        stage: json['stage']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        title: json['title']?.toString() ?? '投递进度',
        description: json['description']?.toString(),
        occurredAt: json['occurredAt']?.toString(),
      );

  String get stateText => switch (state) {
    'done' => '已完成',
    'current' || 'processing' => '进行中',
    'closed' => '已结束',
    _ => '待处理',
  };
}

class ApplicationPage {
  const ApplicationPage({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
    required this.hasNext,
  });

  final List<JobApplication> items;
  final int page;
  final int size;
  final int total;
  final bool hasNext;

  factory ApplicationPage.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final page = int.tryParse('${json['page']}');
    final size = int.tryParse('${json['size']}');
    final total = int.tryParse('${json['total']}');
    if (items is! List ||
        page == null ||
        size == null ||
        total == null ||
        json['hasNext'] is! bool) {
      throw const ApiException('投递列表格式不正确，请重试');
    }
    return ApplicationPage(
      items: items.map((item) {
        if (item is! Map) throw const ApiException('投递记录格式不正确，请重试');
        return JobApplication.fromJson(Map<String, dynamic>.from(item));
      }).toList(),
      page: page,
      size: size,
      total: total,
      hasNext: json['hasNext'] as bool,
    );
  }
}
