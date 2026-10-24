import '../../../../api/talent_api.dart';
import '../models/talent_detail_view_data.dart';

typedef TalentPoolLoader = Future<List<Map<String, dynamic>>> Function({
  String? keyword,
  String? tag,
  required int pageNum,
  required int pageSize,
});

typedef TalentPoolAdvancedLoader = Future<List<Map<String, dynamic>>> Function({
  String? keyword,
  String? tag,
  String? direction,
  int? archiveSource,
  int? status,
  int? minimumEducation,
  String? experienceRange,
  String? city,
  String? cityType,
  int? loginWithinDays,
  required int pageNum,
  required int pageSize,
});

class TalentPoolFilters {
  const TalentPoolFilters({
    this.status,
    this.tag,
    this.direction,
    this.archiveSource,
    this.minimumEducation,
    this.experienceRange,
    this.city,
    this.cityType = 'target',
    this.loginWithinDays,
  });
  final int? status, archiveSource, minimumEducation, loginWithinDays;
  final String? tag, direction, experienceRange, city;
  final String cityType;
  bool get hasExtendedFilters =>
      minimumEducation != null ||
      experienceRange != null ||
      city != null ||
      loginWithinDays != null;
  static const seekingStatusLabels = {1: '在职，考虑新机会', 2: '离职，随时到岗', 3: '应届生'};
  static const educationLabels = {
    1: '中专及以上',
    2: '大专及以上',
    3: '本科及以上',
    4: '硕士及以上',
    5: '博士',
  };
  static const experienceLabels = {
    'lt1': '1年以内',
    '1to3': '1-3年',
    '3to5': '3-5年',
    '5to10': '5-10年',
    'gte10': '10年以上',
  };
  int get count => [
    status,
    tag,
    direction,
    archiveSource,
    minimumEducation,
    experienceRange,
    city,
    loginWithinDays,
  ].where((value) => value != null).length;
}

class TalentPoolOptions {
  const TalentPoolOptions({
    this.directions = const [],
    this.tags = const [],
    this.currentCities = const [],
    this.targetCities = const [],
    this.searchFilterVersion = 1,
  });
  factory TalentPoolOptions.fromJson(Map<String, dynamic> data) {
    List<String> values(String key, {bool optional = false}) {
      final raw = data[key];
      if (optional && raw == null) return const [];
      if (raw is! List || raw.any((value) => value is! String)) {
        throw const FormatException('人才筛选选项格式不完整');
      }
      return List.unmodifiable(
        raw
            .cast<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet(),
      );
    }

    return TalentPoolOptions(
      directions: values('directions'),
      tags: values('tags'),
      currentCities: values('currentCities', optional: true),
      targetCities: values('targetCities', optional: true),
      searchFilterVersion: int.tryParse('${data['searchFilterVersion']}') ?? 1,
    );
  }
  final List<String> directions, tags, currentCities, targetCities;
  final int searchFilterVersion;
}

class TalentPoolResult {
  const TalentPoolResult({
    required this.rows,
    required this.tags,
    required this.nextPage,
    required this.hasMore,
    required this.limited,
    required this.scannedPages,
  });
  final List<Map<String, dynamic>> rows;
  final List<String> tags;
  final int nextPage;
  final bool hasMore;
  final bool limited;
  final int scannedPages;
}

/// Production uses the existing server-side filters and real pagination.
/// Legacy callback injection remains available for older preview/test adapters.
class TalentPoolDataSource {
  const TalentPoolDataSource({
    TalentPoolLoader? loader,
    TalentPoolAdvancedLoader advancedLoader = searchAdvancedTalentPool,
    Future<Map<String, dynamic>> Function() optionsLoader =
        loadTalentPoolOptions,
  }) // Keep the existing public injection names for legacy callers.
    // ignore: prefer_initializing_formals
    : _loader = loader,
       // ignore: prefer_initializing_formals
       _advancedLoader = advancedLoader,
       // ignore: prefer_initializing_formals
       _optionsLoader = optionsLoader;

  static const pageSize = 20;
  static const statusScanLimit = 3;
  final TalentPoolLoader? _loader;
  final TalentPoolAdvancedLoader _advancedLoader;
  final Future<Map<String, dynamic>> Function() _optionsLoader;

  Future<TalentPoolOptions> loadOptions() async =>
      TalentPoolOptions.fromJson(await _optionsLoader());

  Future<TalentPoolResult> load({
    String? keyword,
    String? tag,
    int? status,
    String? direction,
    int? archiveSource,
    TalentPoolFilters extended = const TalentPoolFilters(),
    int pageNum = 1,
  }) async {
    if ((extended.minimumEducation != null &&
            !TalentPoolFilters.educationLabels.containsKey(
              extended.minimumEducation,
            )) ||
        (extended.experienceRange != null &&
            !TalentPoolFilters.experienceLabels.containsKey(
              extended.experienceRange,
            )) ||
        !['current', 'target'].contains(extended.cityType) ||
        (extended.city != null &&
            (extended.city!.trim().isEmpty || extended.city!.length > 50)) ||
        (extended.loginWithinDays != null &&
            ![1, 3, 7, 14, 30, 90].contains(extended.loginWithinDays))) {
      throw const FormatException('高级人才筛选参数不正确');
    }
    if (_loader != null && extended.hasExtendedFilters) {
      throw const FormatException('当前数据源不支持高级人才筛选，请使用新版服务');
    }
    if (extended.hasExtendedFilters &&
        (await loadOptions()).searchFilterVersion < 2) {
      throw const FormatException('后端尚未支持高级筛选，请先部署新版人才库接口');
    }
    final localFilter =
        _loader != null &&
        (status != null || direction != null || archiveSource != null);
    if (pageNum < 1 ||
        (status != null && (status < 0 || status > 9)) ||
        (archiveSource != null && (archiveSource < 0 || archiveSource > 4)) ||
        (localFilter && pageNum != 1)) {
      throw const FormatException('候选人筛选参数不正确');
    }
    final rows = <Map<String, dynamic>>[];
    final tags = <String>{};
    var page = pageNum;
    var scanned = 0;
    var fullPage = false;
    do {
      final raw = _loader != null
          ? await _loader(
              keyword: keyword?.trim(),
              tag: tag?.trim(),
              pageNum: page,
              pageSize: pageSize,
            )
          : await _advancedLoader(
              keyword: keyword?.trim(),
              tag: tag?.trim(),
              direction: direction?.trim(),
              archiveSource: archiveSource,
              status: status,
              minimumEducation: extended.minimumEducation,
              experienceRange: extended.experienceRange,
              city: extended.city?.trim(),
              cityType: extended.city == null ? null : extended.cityType,
              loginWithinDays: extended.loginWithinDays,
              pageNum: page,
              pageSize: pageSize,
            );
      if (raw.length > pageSize) {
        throw const FormatException('候选人分页响应异常，请重试');
      }
      for (final row in raw) {
        if (talentId(row['talentId']) == null) {
          throw const FormatException('候选人列表包含无效编号，请重试');
        }
        if (_loader == null &&
            ((status != null && int.tryParse('${row['status']}') != status) ||
                (direction != null &&
                    row['jobDirection'] != direction.trim()) ||
                (archiveSource != null &&
                    int.tryParse('${row['archiveSource']}') !=
                        archiveSource))) {
          throw const FormatException('后端返回的数据不符合筛选条件，请确认服务版本后重试');
        }
        if (extended.hasExtendedFilters &&
            int.tryParse('${row['searchFilterVersion']}') != 2) {
          throw const FormatException('后端尚未支持高级筛选，请先部署新版人才库接口');
        }
        tags.addAll(talentPoolTags(row['tags']));
        if (_loader == null ||
            ((status == null || int.tryParse('${row['status']}') == status) &&
                (direction == null || row['jobDirection'] == direction) &&
                (archiveSource == null ||
                    int.tryParse('${row['archiveSource']}') ==
                        archiveSource))) {
          rows.add(row);
        }
      }
      fullPage = raw.length == pageSize;
      scanned++;
      page++;
    } while (localFilter && fullPage && scanned < statusScanLimit);
    return TalentPoolResult(
      rows: mergeTalentPoolRows(const [], rows),
      tags: List.unmodifiable(tags),
      nextPage: page,
      hasMore: !localFilter && fullPage,
      // A full third page means completeness cannot be established without a fourth request.
      limited: localFilter && fullPage && scanned == statusScanLimit,
      scannedPages: scanned,
    );
  }
}

List<String> talentPoolTags(Object? raw) => (raw?.toString() ?? '')
    .split(',')
    .map((tag) => tag.trim())
    .where((tag) => tag.isNotEmpty)
    .toSet()
    .toList();

/// Keep the first occurrence, including across page boundaries, in server order.
List<Map<String, dynamic>> mergeTalentPoolRows(
  Iterable<Map<String, dynamic>> existing,
  Iterable<Map<String, dynamic>> incoming,
) {
  final seen = <int>{};
  final result = <Map<String, dynamic>>[];
  for (final row in [...existing, ...incoming]) {
    final id = talentId(row['talentId']);
    if (id == null) {
      throw const FormatException('候选人列表包含无效编号，请重试');
    }
    if (seen.add(id)) {
      result.add(Map<String, dynamic>.unmodifiable(row));
    }
  }
  return List.unmodifiable(result);
}
