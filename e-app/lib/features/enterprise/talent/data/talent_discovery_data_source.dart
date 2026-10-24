import '../../../../core/network/enterprise_api_client.dart';
import '../../../../core/network/api_exception.dart';
import 'talent_pool_data_source.dart';

/// 平台人才发现只使用用户ID与公开资料，不读取企业人才/岗位分析接口。
class TalentDiscoveryDataSource extends TalentPoolDataSource {
  const TalentDiscoveryDataSource({this.client});
  final EnterpriseApiClient? client;
  EnterpriseApiClient get _api => client ?? EnterpriseApiClient();
  static const fields = {
    'userId',
    'name',
    'avatar',
    'currentCity',
    'targetCity',
    'currentStatus',
    'jobDirection',
    'highestEducation',
    'workMonths',
    'directoryVersion',
    'schoolName',
    'major',
    'graduationYear',
    'salaryMin',
    'salaryMax',
    'salaryNegotiable',
  };

  static Map<String, dynamic> publicProfile(Map<String, dynamic> row) {
    final id = int.tryParse('${row['userId']}');
    if (id == null || id <= 0 || row['directoryVersion'] != 1) {
      throw const FormatException('平台人才资料不完整，请确认服务器已更新');
    }
    return Map.unmodifiable({
      'userId': id,
      for (final key in fields)
        if (key != 'userId' && row.containsKey(key)) key: row[key],
    });
  }

  @override
  Future<TalentPoolOptions> loadOptions() async {
    final response = await _api.get('/enterprise/talent-discovery/options');
    final data = response['data'];
    if (data is! Map || data['directoryVersion'] != 1) {
      throw const FormatException('服务器尚未支持平台人才发现筛选');
    }
    return TalentPoolOptions.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<TalentPoolResult> load({
    String? keyword,
    String? tag,
    int? status,
    String? direction,
    int? archiveSource,
    TalentPoolFilters extended = const TalentPoolFilters(),
    int pageNum = 1,
  }) async {
    if (pageNum < 1 ||
        tag != null ||
        archiveSource != null ||
        (status != null &&
            !TalentPoolFilters.seekingStatusLabels.containsKey(status))) {
      throw const FormatException('人才发现筛选不支持招聘流程或企业标签条件');
    }
    final response = await _api.get(
      '/enterprise/talent-discovery',
      query: {
        'keyword': keyword?.trim(),
        'direction': direction?.trim(),
        'currentStatus': status,
        'minimumEducation': extended.minimumEducation,
        'experienceRange': extended.experienceRange,
        'city': extended.city,
        'cityType': extended.cityType,
        'loginWithinDays': extended.loginWithinDays,
        'pageNum': pageNum,
        'pageSize': TalentPoolDataSource.pageSize,
      },
    );
    final raw = response['rows'];
    final total = int.tryParse('${response['total']}');
    if (raw is! List || total == null || total < 0 || total < raw.length) {
      throw const FormatException('平台人才列表响应格式不正确');
    }
    final rows = raw.map((row) {
      if (row is! Map) throw const FormatException('平台人才资料格式不正确');
      return publicProfile(Map<String, dynamic>.from(row));
    }).toList();
    if (rows.isEmpty && total > (pageNum - 1) * TalentPoolDataSource.pageSize) {
      throw const FormatException('平台人才列表已变化，请刷新重试');
    }
    return TalentPoolResult(
      rows: mergeDiscoveryRows(const [], rows),
      tags: const [],
      nextPage: pageNum + 1,
      hasMore: pageNum * TalentPoolDataSource.pageSize < total,
      limited: false,
      scannedPages: 1,
    );
  }

  static String errorMessage(Object error) => switch (error) {
    ApiException() when error.isUnauthorized => '登录已失效，请重新登录',
    ApiException() when error.statusCode == 404 || error.code == 404 =>
      '服务器尚未部署平台人才发现接口',
    ApiException() => error.message,
    FormatException() => error.message,
    _ => '人才资料加载失败，请稍后重试',
  };
  Future<Map<String, dynamic>> detail(int userId) async {
    if (userId <= 0) throw const FormatException('用户编号无效');
    final response = await _api.get('/enterprise/talent-discovery/$userId');
    final data = response['data'];
    if (data is! Map || int.tryParse('${data['userId']}') != userId) {
      throw const FormatException('用户资料关联不一致');
    }
    return publicProfile(Map<String, dynamic>.from(data));
  }
}

List<Map<String, dynamic>> mergeDiscoveryRows(
  Iterable<Map<String, dynamic>> existing,
  Iterable<Map<String, dynamic>> incoming,
) {
  final seen = <int>{};
  final result = <Map<String, dynamic>>[];
  for (final row in [...existing, ...incoming]) {
    final id = int.tryParse('${row['userId']}');
    if (id == null || id <= 0) throw const FormatException('平台人才用户编号无效');
    if (seen.add(id)) result.add(Map.unmodifiable(row));
  }
  return List.unmodifiable(result);
}

String discoveryStatus(Object? value) =>
    TalentPoolFilters.seekingStatusLabels[int.tryParse('$value')] ?? '求职状态待完善';
String discoveryEducation(Object? value) =>
    const {1: '中专', 2: '大专', 3: '本科', 4: '硕士', 5: '博士'}[int.tryParse(
      '$value',
    )] ??
    '学历未填写';
String discoveryExperience(Object? value) {
  final months = int.tryParse('$value');
  if (months == null || months < 0) return '工作经验未填写';
  return months < 12
      ? '1年以内工作经验'
      : '${months ~/ 12}年${months % 12 == 0 ? '' : '${months % 12}个月'}工作经验';
}

String discoverySalary(Map<String, dynamic> profile) {
  final mode = int.tryParse('${profile['salaryNegotiable']}');
  final minimum = int.tryParse('${profile['salaryMin']}');
  final maximum = int.tryParse('${profile['salaryMax']}');
  if (mode == 1 && minimum == null && maximum == null) return '薪资面议';
  if (mode != 0 ||
      minimum == null ||
      maximum == null ||
      minimum < 0 ||
      maximum < minimum ||
      maximum > 10000000) {
    return '期望薪资未填写';
  }
  String amount(int value) =>
      value >= 1000 && value % 1000 == 0 ? '${value ~/ 1000}K' : '$value元';
  return minimum == maximum
      ? '${amount(minimum)}/月'
      : '${amount(minimum)}–${amount(maximum)}/月';
}

String discoverySchool(Map<String, dynamic> profile) {
  final school = profile['schoolName']?.toString().trim() ?? '';
  if (school.isEmpty) return '毕业院校未填写';
  final major = profile['major']?.toString().trim() ?? '';
  final year = int.tryParse('${profile['graduationYear']}');
  return [
    school,
    if (major.isNotEmpty) major,
    if (year != null) '$year届',
  ].join(' · ');
}
