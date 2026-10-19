import 'package:enterprise_recruiter/features/enterprise/talent/data/talent_detail_data_source.dart';
import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/jd_http_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late JdHttpFixture http;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    http = JdHttpFixture();
  });
  tearDown(() => http.close());
  test('面试人员新增数据源 GET 解包真实 userId，空列表保持为空', () async {
    final source = TalentDetailDataSource(client: http.client);
    http.adapter.body = {
      'code': 200,
      'data': [
        {'userId': 19, 'userName': '合成面试官', 'department': '技术部'},
      ],
    };
    expect((await source.loadInterviewers()).single['userId'], 19);
    expect(http.adapter.requests.single.method, 'GET');
    expect(
      http.adapter.requests.single.path,
      '/system/conference/interviewers',
    );
    http.adapter.body = {'code': 200, 'data': <Object>[]};
    expect(await source.loadInterviewers(), isEmpty);
  });
  for (final rows in [
    null,
    {},
    [
      {'userId': 0},
    ],
    [
      {'userId': 19},
      {'userId': 19},
    ],
  ]) {
    test('无效面试人员结构拒绝成为选项：$rows', () async {
      http.adapter.body = {'code': 200, 'data': rows};
      await expectLater(
        TalentDetailDataSource(client: http.client).loadInterviewers(),
        throwsFormatException,
      );
    });
  }
  test('面试人员权限失败保留业务错误，不能变为空闲或假选项', () async {
    http.adapter.body = {'code': 403, 'msg': '合成权限不足'};
    await expectLater(
      TalentDetailDataSource(client: http.client).loadInterviewers(),
      throwsA(isA<ApiException>()),
    );
  });
}
