import 'package:enterprise_recruiter/features/enterprise/talent/data/talent_pool_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> poolRow(int id, {Object? status = 2, String tags = ''}) =>
    {'talentId': id, 'status': status, 'name': '合成候选人$id', 'tags': tags};
List<Map<String, dynamic>> poolRows(int start, int count, {int status = 2}) =>
    List.generate(count, (i) => poolRow(start + i, status: status));

void main() {
  test('普通模式每次只读20条，关键词标签去空格，分页按原始行数判断', () async {
    final calls = <Map<String, Object?>>[];
    final source = TalentPoolDataSource(
      loader:
          ({
            String? keyword,
            String? tag,
            required int pageNum,
            required int pageSize,
          }) async {
            calls.add({
              'keyword': keyword,
              'tag': tag,
              'pageNum': pageNum,
              'pageSize': pageSize,
            });
            return pageNum == 1 ? poolRows(1, 20) : poolRows(21, 3);
          },
    );
    final first = await source.load(keyword: ' 姓名 ', tag: ' 标签 ');
    expect(calls.single, {
      'keyword': '姓名',
      'tag': '标签',
      'pageNum': 1,
      'pageSize': 20,
    });
    expect(first.rows.length, 20);
    expect(first.hasMore, isTrue);
    expect(first.nextPage, 2);
    expect(first.scannedPages, 1);
    final second = await source.load(
      keyword: '姓名',
      tag: '标签',
      pageNum: first.nextPage,
    );
    expect(second.hasMore, isFalse);
    expect(second.rows.first['talentId'], 21);
    expect(second.limited, isFalse);
  });

  test('同页及跨页按talentId去重，保持第一次出现的服务端顺序', () {
    final merged = mergeTalentPoolRows(
      [poolRow(8), poolRow(3)],
      [poolRow(3)..['name'] = '重复行', poolRow(9), poolRow(1)],
    );
    expect(merged.map((row) => row['talentId']), [8, 3, 9, 1]);
    expect(merged[1]['name'], '合成候选人3');
    expect(() => merged.add(poolRow(100)), throwsUnsupportedError);
    expect(() => merged.first['name'] = '修改', throwsUnsupportedError);
  });

  test('重复行不影响满页判断，不把去重后的19条当作末页', () async {
    final source = TalentPoolDataSource(
      loader: ({
        String? keyword,
        String? tag,
        required int pageNum,
        required int pageSize,
      }) async => [...poolRows(1, 19), poolRow(1)],
    );
    final result = await source.load();
    expect(result.rows.length, 19);
    expect(result.hasMore, isTrue);
    expect(result.nextPage, 2);
  });

  test('状态跨页过滤，短页后停止，收集原始记录中的标签建议', () async {
    final calls = <int>[];
    final source = TalentPoolDataSource(
      loader:
          ({
            String? keyword,
            String? tag,
            required int pageNum,
            required int pageSize,
          }) async {
            calls.add(pageNum);
            expect(pageSize, 20);
            expect(keyword, '搜索');
            expect(tag, '精确标签');
            if (pageNum == 1) {
              return [
                poolRow(1, status: 0, tags: 'Java, 协作,Java'),
                ...poolRows(2, 19, status: 2),
              ];
            }
            return [
              poolRow(21, status: '0', tags: 'Vue'),
              poolRow(22, status: null),
            ];
          },
    );
    final result = await source.load(keyword: '搜索', tag: '精确标签', status: 0);
    expect(calls, [1, 2]);
    expect(result.rows.map((row) => row['talentId']), [1, 21]);
    expect(result.tags, ['Java', '协作', 'Vue']);
    expect(result.hasMore, isFalse);
    expect(result.limited, isFalse);
  });

  test('状态筛选严格最多3页，第三页满时标记可能不完整，不提供加载更多', () async {
    final calls = <int>[];
    final source = TalentPoolDataSource(
      loader:
          ({
            String? keyword,
            String? tag,
            required int pageNum,
            required int pageSize,
          }) async {
            calls.add(pageNum);
            return poolRows((pageNum - 1) * 20 + 1, 20, status: 0);
          },
    );
    final result = await source.load(status: 0);
    expect(calls, [1, 2, 3]);
    expect(result.rows.length, 60);
    expect(result.scannedPages, 3);
    expect(result.hasMore, isFalse);
    expect(result.limited, isTrue);
  });

  test('前三页无匹配也保留截断标记，不能当作全局空结果', () async {
    var calls = 0;
    final source = TalentPoolDataSource(
      loader:
          ({
            String? keyword,
            String? tag,
            required int pageNum,
            required int pageSize,
          }) async {
            calls++;
            return poolRows(pageNum * 20, 20, status: 2);
          },
    );
    final result = await source.load(status: 3);
    expect(calls, 3);
    expect(result.rows, isEmpty);
    expect(result.limited, isTrue);
    expect(result.hasMore, isFalse);
  });

  test('满页后空页结束，状态0按真实值筛选，不把null当0', () async {
    final calls = <int>[];
    final source = TalentPoolDataSource(
      loader:
          ({
            String? keyword,
            String? tag,
            required int pageNum,
            required int pageSize,
          }) async {
            calls.add(pageNum);
            return pageNum == 1
                ? [
                    poolRow(1, status: 0),
                    poolRow(2, status: null),
                    ...poolRows(3, 18),
                  ]
                : [];
          },
    );
    final result = await source.load(status: 0);
    expect(calls, [1, 2]);
    expect(result.rows.map((row) => row['talentId']), [1]);
    expect(result.limited, isFalse);
  });

  test('状态过滤的重复候选人保持顺序且去重', () async {
    final source = TalentPoolDataSource(
      loader:
          ({
            String? keyword,
            String? tag,
            required int pageNum,
            required int pageSize,
          }) async => pageNum == 1
          ? poolRows(1, 20, status: 0)
          : [poolRow(20, status: 0), poolRow(21, status: 0)],
    );
    final result = await source.load(status: 0);
    expect(result.rows.length, 21);
    expect(result.rows.last['talentId'], 21);
  });

  test('分页异常向上传递，状态扫描失败重试从第一页开始', () async {
    var fail = true;
    final calls = <int>[];
    final source = TalentPoolDataSource(
      loader:
          ({
            String? keyword,
            String? tag,
            required int pageNum,
            required int pageSize,
          }) async {
            calls.add(pageNum);
            if (pageNum == 2 && fail) {
              throw StateError('合成读取失败');
            }
            return pageNum == 1 ? poolRows(1, 20) : [];
          },
    );
    await expectLater(source.load(status: 2), throwsStateError);
    fail = false;
    final retry = await source.load(status: 2);
    expect(calls, [1, 2, 1, 2]);
    expect(retry.rows.length, 20);
    expect(retry.limited, isFalse);
  });

  test('非法状态或状态模式追加页在请求前拒绝', () async {
    var calls = 0;
    final source = TalentPoolDataSource(
      loader:
          ({
            String? keyword,
            String? tag,
            required int pageNum,
            required int pageSize,
          }) async {
            calls++;
            return [];
          },
    );
    await expectLater(source.load(status: -1), throwsFormatException);
    await expectLater(source.load(status: 10), throwsFormatException);
    await expectLater(
      source.load(status: 1, pageNum: 2),
      throwsFormatException,
    );
    await expectLater(source.load(pageNum: 0), throwsFormatException);
    expect(calls, 0);
  });

  test('拒绝超页数响应、缺失或非法候选人编号', () async {
    for (final rows in [
      poolRows(1, 21),
      [poolRow(0)],
      <Map<String, dynamic>>[
        {'name': '缺少编号'},
      ],
    ]) {
      final source = TalentPoolDataSource(
        loader: ({
          String? keyword,
          String? tag,
          required int pageNum,
          required int pageSize,
        }) async => rows,
      );
      await expectLater(source.load(), throwsFormatException);
    }
  });
}
