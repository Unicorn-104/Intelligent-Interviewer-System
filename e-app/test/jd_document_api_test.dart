import 'package:enterprise_recruiter/api/jd_document_api.dart';
import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/jd_http_fixture.dart';
import 'support/jd_import_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late JdHttpFixture http;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    http = JdHttpFixture();
  });
  tearDown(() => http.close());

  test('从 AjaxResult.data 解包草稿，保留薪资、技能和原始警告', () async {
    http.adapter.body = {'code': 200, 'msg': '操作成功', 'data': jdDraftJson()};
    final draft = await parseJdDocument(jdDocument(), client: http.client);
    expect(draft.title, jdDraftJson()['title']);
    expect(draft.salaryMin, 15000.5);
    expect(draft.skills.last.requiredFlag, isNull);
    expect(draft.warnings, jdDraftJson()['warnings']);
    expect(http.adapter.requests.single.path, '/enterprise/jd/parse-document');
  });

  for (final body in [
    null,
    'invalid',
    <Object>[],
    {'data': jdDraftJson()},
    {'code': 200},
    {'code': 200, 'data': null},
    {'code': 200, 'data': <Object>[]},
    {'code': 200, 'data': <String, Object>{}},
  ]) {
    test('拒绝无效 AjaxResult 结构：$body', () async {
      http.adapter.body = body;
      await expectLater(
        parseJdDocument(jdDocument(), client: http.client),
        throwsA(isA<ApiException>()),
      );
    });
  }

  test('字段类型错误转换成可展示的草稿格式错误', () async {
    http.adapter.body = {
      'code': 200,
      'data': jdDraftJson({'education': '本科'}),
    };
    await expectLater(
      parseJdDocument(jdDocument(), client: http.client),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('JD 草稿格式不正确'),
        ),
      ),
    );
  });

  test('业务失败不把 data 当作成功草稿使用', () async {
    http.adapter.body = {'code': 403, 'msg': '合成权限不足', 'data': jdDraftJson()};
    await expectLater(
      parseJdDocument(jdDocument(), client: http.client),
      throwsA(isA<ApiException>().having((error) => error.code, 'code', 403)),
    );
  });
}
