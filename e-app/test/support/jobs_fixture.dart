import 'dart:async';

class JobsFixture {
  final calls = <({String? keyword, int? status, int page})>[];
  final writes = <(int, int)>[];
  final rows = List.generate(
    25,
    (index) => <String, dynamic>{
      'posId': index + 1,
      'title': index == 7
          ? 'JD_IMPORT_SMOKE_8'
          : index == 9
          ? 'PERSISTENCE_SMOKE_10'
          : '示例岗位 ${index + 1}',
      'dept': index.isEven ? '研发' : '产品',
      'city': '示例城市',
      'salaryMin': 12500,
      'salaryMax': 20000,
      'education': 3,
      'experience': '3-5年',
      'applicantCount': index == 0 ? 120 : index,
      'status': index % 3,
      'jdJson': '{"skills":["Spring","Dart"]}',
    },
  );
  Object? error;
  bool failNextPage = false;
  Completer<void>? statusGate;
  Completer<List<Map<String, dynamic>>>? loadGate;

  Future<List<Map<String, dynamic>>> load({
    String? keyword,
    String? dept,
    int? status,
    required int pageNum,
    required int pageSize,
  }) async {
    calls.add((keyword: keyword, status: status, page: pageNum));
    if (loadGate != null) return loadGate!.future;
    if (error != null) throw error!;
    if (failNextPage && pageNum > 1) {
      throw StateError('controlled page failure');
    }
    final filtered = rows.where(
      (row) =>
          (status == null || row['status'] == status) &&
          (keyword == null ||
              keyword.isEmpty ||
              '${row['title']} ${row['dept']}'.contains(keyword)),
    );
    return filtered
        .skip((pageNum - 1) * pageSize)
        .take(pageSize)
        .map((row) => Map<String, dynamic>.of(row))
        .toList();
  }

  Future<void> update(int id, int status) async {
    writes.add((id, status));
    if (statusGate != null) await statusGate!.future;
    rows.firstWhere((row) => row['posId'] == id)['status'] = status;
  }
}
