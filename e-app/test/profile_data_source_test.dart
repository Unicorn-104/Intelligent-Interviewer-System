import 'dart:convert';
import 'dart:typed_data';

import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/profile/data/profile_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/profile/models/profile_view_data.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/jd_http_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late JdHttpFixture http;
  late ProfileDataSource source;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'enterprise_access_token': 'synthetic-test-token',
    });
    http = JdHttpFixture();
    source = ProfileDataSource(client: http.client);
  });
  tearDown(() => http.close());
  test('资料解包后端data、roleGroup、postGroup，展示真实角色部门', () async {
    http.adapter.body = {
      'code': 200,
      'data': {
        'userId': 17,
        'userName': 'synthetic-account',
        'nickName': '合成招聘经理',
        'dept': {'deptName': '合成研发部'},
        'sex': '1',
      },
      'roleGroup': '招聘管理员',
      'postGroup': '招聘经理',
    };
    final profile = await source.loadProfile();
    expect(profile.name, '合成招聘经理');
    expect(profile.role, '招聘管理员');
    expect(profile.position, '招聘经理');
    expect(profile.department, '合成研发部');
    expect(profile.sex, '女');
    expect(http.adapter.requests.single.path, '/system/user/profile');
    expect(
      http.adapter.requests.single.headers['authorization'] ??
          http.adapter.requests.single.headers['Authorization'],
      'Bearer synthetic-test-token',
    );
  });
  test('资料保存仅发送允许编辑字段，不发送账号角色部门', () async {
    await source.saveProfile({
      'nickName': '合成姓名',
      'phonenumber': '',
      'email': 'synthetic@example.com',
      'sex': '2',
      'remark': '合成简介',
      'userId': 1,
      'roles': ['admin'],
      'deptId': 99,
    });
    final request = http.adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.path, '/system/user/profile');
    expect((request.data as Map).keys.toSet(), {
      'nickName',
      'phonenumber',
      'email',
      'sex',
      'remark',
    });
  });
  test('密码修改使用原接口JSON体，仅发送旧密码和新密码', () async {
    await source.changePassword('syntheticOld6', 'syntheticNew6');
    expect(http.adapter.requests.single.path, '/system/user/profile/updatePwd');
    expect(http.adapter.requests.single.method, 'PUT');
    expect(http.adapter.requests.single.data, {
      'oldPassword': 'syntheticOld6',
      'newPassword': 'syntheticNew6',
    });
  });
  test('头像使用avatarfile multipart字段，从响应顶层imgUrl读取', () async {
    http.adapter.body = {
      'code': 200,
      'imgUrl': '/profile/avatar/synthetic.png',
    };
    final value = await source.uploadAvatar(
      ProfileAvatar(
        name: 'avatar.png',
        bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0]),
      ),
    );
    expect(value, '/profile/avatar/synthetic.png');
    expect(http.adapter.requests.single.path, '/system/user/profile/avatar');
    final wire = latin1.decode(http.adapter.wireBodies.single);
    expect(wire, contains('name="avatarfile"'));
    expect(wire, contains('filename="avatar.png"'));
    expect(wire, contains('image/png'));
  });
  test('头像响应缺少imgUrl不假报成功，业务失败不当成功', () async {
    final avatar = ProfileAvatar(
      name: 'a.png',
      bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
    );
    http.adapter.body = {
      'code': 200,
      'data': {'imgUrl': 'wrong-level'},
    };
    await expectLater(
      source.uploadAvatar(avatar),
      throwsA(isA<ApiException>()),
    );
    http.adapter.body = {'code': 500, 'msg': '合成手机号重复'};
    await expectLater(
      source.saveProfile({}),
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', '合成手机号重复'),
      ),
    );
  });
  test('复用上传通道的失败信息转换为头像提示，不出现JD文档文案', () async {
    final avatar = ProfileAvatar(
      name: 'a.png',
      bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
    );
    http.adapter.body = {'code': 413};
    await expectLater(
      source.uploadAvatar(avatar),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          '头像上传失败，请检查图片或稍后重试',
        ),
      ),
    );
  });

  test('无登录态不发请求，401和无效资料返回可读错误', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await expectLater(
      source.loadProfile(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.isUnauthorized,
          'unauthorized',
          isTrue,
        ),
      ),
    );
    expect(http.adapter.requests, isEmpty);
    FlutterSecureStorage.setMockInitialValues({
      'enterprise_access_token': 'synthetic-test-token',
    });
    http.adapter.body = {'code': 401, 'msg': 'expired'};
    await expectLater(
      source.loadProfile(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.isUnauthorized,
          'unauthorized',
          isTrue,
        ),
      ),
    );
    http.adapter.body = {'code': 200, 'data': {}};
    await expectLater(source.loadProfile(), throwsA(isA<FormatException>()));
  });
  test('本机偏好按账号隔离，通知偏好保持布尔值，损坏数据不假报默认成功', () async {
    const prefs = ProfilePreferences(
      duration: 60,
      calendar: 'none',
      frequency: 'daily',
      notices: {
        'interview': false,
        'resume': true,
        'message': false,
        'system': true,
      },
    );
    await source.savePreferences(17, prefs);
    final own = await source.loadPreferences(17);
    final other = await source.loadPreferences(18);
    expect(own.duration, 60);
    expect(own.notices['interview'], isFalse);
    expect(own.frequency, 'daily');
    expect(other.duration, 45);
    expect(other.notices['interview'], isTrue);
    const storage = FlutterSecureStorage();
    await storage.write(
      key: 'enterprise_profile_preferences_17',
      value: 'invalid-json',
    );
    await expectLater(
      source.loadPreferences(17),
      throwsA(isA<FormatException>()),
    );
    expect(http.adapter.requests, isEmpty);
  });
  test('头像限制空内容、不支持格式、伪装格式以及5MB边界', () {
    expect(
      () => ProfileAvatar(name: 'x.png', bytes: Uint8List(0)),
      throwsFormatException,
    );
    expect(
      () => ProfileAvatar(name: 'x.pdf', bytes: Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    expect(
      () => ProfileAvatar(name: 'x.png', bytes: Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    expect(
      () => ProfileAvatar(
        name: 'x.png',
        bytes: Uint8List(ProfileAvatar.maxBytes),
      ),
      throwsFormatException,
    );
    expect(
      source.avatarUrl('/profile/avatar/x.png'),
      endsWith('/profile/avatar/x.png'),
    );
    expect(source.avatarUrl('javascript:alert(1)'), isNull);
  });
}
