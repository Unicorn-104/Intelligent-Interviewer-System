import '../../../../api/talent_api.dart';
import '../models/talent_detail_view_data.dart';

typedef TalentPoolLoader = Future<List<Map<String, dynamic>>> Function({
  String? keyword,
  String? tag,
  required int pageNum,
  required int pageSize,
});

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

/// The existing API handles keyword/tag; status has no server-side parameter.
class TalentPoolDataSource {
  const TalentPoolDataSource({TalentPoolLoader loader = searchTalentPool})
    // Preserve the public loader injection name and the private callback field.
    // ignore: prefer_initializing_formals
    : _loader = loader;

  static const pageSize = 20;
  static const statusScanLimit = 3;
  final TalentPoolLoader _loader;

  Future<TalentPoolResult> load({
    String? keyword,
    String? tag,
    int? status,
    int pageNum = 1,
  }) async {
    if (pageNum < 1 ||
        (status != null && (status < 0 || status > 9 || pageNum != 1))) {
      throw const FormatException('候选人筛选参数不正确');
    }
    final rows = <Map<String, dynamic>>[];
    final tags = <String>{};
    var page = pageNum;
    var scanned = 0;
    var fullPage = false;
    do {
      final raw = await _loader(
        keyword: keyword?.trim(),
        tag: tag?.trim(),
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
        tags.addAll(talentPoolTags(row['tags']));
        if (status == null || int.tryParse('${row['status']}') == status) {
          rows.add(row);
        }
      }
      fullPage = raw.length == pageSize;
      scanned++;
      page++;
    } while (status != null && fullPage && scanned < statusScanLimit);
    return TalentPoolResult(
      rows: mergeTalentPoolRows(const [], rows),
      tags: List.unmodifiable(tags),
      nextPage: page,
      hasMore: status == null && fullPage,
      // A full third page means completeness cannot be established without a fourth request.
      limited: status != null && fullPage && scanned == statusScanLimit,
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
