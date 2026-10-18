import 'dart:async';
import 'dart:typed_data';

import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/profile/account_page.dart';
import 'package:enterprise_recruiter/features/enterprise/profile/data/profile_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/profile/models/profile_view_data.dart';
import 'package:enterprise_recruiter/features/enterprise/profile/widgets/profile_edit_dialog.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeProfileSource extends ProfileDataSource {
  Map<String, dynamic> user = {
    'userId': 17,
    'userName': 'synthetic-account',
    'nickName': '合成招聘经理',
    'phonenumber': '',
    'email': 'synthetic@example.com',
    'sex': '0',
    'remark': '合成招聘说明',
    'dept': {'deptName': '合成研发部'},
    'loginDate': '2026-10-18 10:00:00',
    'loginIp': '192.0.2.10',
  };
  bool loadFails = false,
      saveFails = false,
      settingsFail = false,
      passwordFails = false,
      uploadFails = false;
  int loads = 0, picks = 0, uploads = 0;
  Completer<void>? saveGate, passwordGate;
  Completer<void>? preferencesGate;
  bool preferencesSaveFails = false;
  final saved = <Map<String, Object?>>[], passwords = <(String, String)>[];
  ProfilePreferences prefs = const ProfilePreferences();
  final prefSaves = <ProfilePreferences>[];
  ProfileAvatar? picked;
  @override
  Future<EnterpriseProfile> loadProfile() async {
    loads++;
    if (loadFails) throw const ApiException('合成网络失败');
    return EnterpriseProfile.fromResponse({
      'data': user,
      'roleGroup': '招聘管理员',
      'postGroup': '招聘经理',
    });
  }

  @override
  Future<void> saveProfile(Map<String, Object?> fields) async {
    saved.add(fields);
    if (saveFails) throw const ApiException('合成邮箱已存在');
    await saveGate?.future;
    user = {...user, ...fields};
  }

  @override
  Future<void> changePassword(String oldPassword, String newPassword) async {
    passwords.add((oldPassword, newPassword));
    if (passwordFails) throw const ApiException('旧密码错误');
    await passwordGate?.future;
  }

  @override
  Future<ProfilePreferences> loadPreferences(int userId) async {
    if (settingsFail) throw StateError('settings');
    return prefs;
  }

  @override
  Future<void> savePreferences(int userId, ProfilePreferences value) async {
    prefSaves.add(value);
    if (preferencesSaveFails) throw const ApiException('本机设置写入失败');
    await preferencesGate?.future;
    prefs = value;
  }

  @override
  Future<ProfileAvatar?> pickAvatar() async {
    picks++;
    return picked;
  }

  @override
  Future<String> uploadAvatar(ProfileAvatar image) async {
    uploads++;
    if (uploadFails) throw const ApiException('合成上传失败');
    return '/profile/avatar/test.png';
  }
}

Future<void> mountProfile(
  WidgetTester tester,
  FakeProfileSource source, {
  Size size = const Size(430, 1000),
  VoidCallback? logout,
  GlobalKey<AccountPageState>? pageKey,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        appBar: AppBar(title: const Text('我的')),
        body: AccountPage(
          key: pageKey,
          source: source,
          onLogout: logout ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> profileTap(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      350,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> profileEnter(WidgetTester tester, String key, String value) async {
  final field = find.byKey(Key(key));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, value);
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('设置保存中锁定切换，写入失败保留原值并可重试', (tester) async {
    final source = FakeProfileSource()..preferencesSaveFails = true;
    await mountProfile(tester, source);
    await profileTap(tester, find.byKey(const Key('profile-tab-2')));
    await profileTap(tester, find.byKey(const Key('profile-notice-interview')));
    await profileTap(tester, find.byKey(const Key('profile-preferences-save')));
    expect(find.text('本机设置写入失败'), findsOneWidget);
    expect(source.prefs.notices['interview'], isTrue);
    source.preferencesSaveFails = false;
    source.preferencesGate = Completer<void>();
    await tester.tap(find.byKey(const Key('profile-preferences-save')));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('profile-tab-1')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('profile-preferences-save')),
          )
          .onPressed,
      isNull,
    );
    source.preferencesGate!.complete();
    await tester.pumpAndSettle();
    expect(source.prefs.notices['interview'], isFalse);
  });

  testWidgets('我的展示服务端资料、角色部门和三分区，切换不写接口', (tester) async {
    final source = FakeProfileSource();
    await mountProfile(tester, source);
    expect(find.text('合成招聘经理'), findsWidgets);
    expect(find.text('招聘管理员'), findsOneWidget);
    expect(find.textContaining('招聘经理 · 合成研发部'), findsOneWidget);
    await profileTap(tester, find.byKey(const Key('profile-tab-1')));
    expect(find.text('工作偏好'), findsOneWidget);
    await profileTap(tester, find.byKey(const Key('profile-tab-2')));
    expect(find.byKey(const Key('profile-notice-interview')), findsOneWidget);
    expect(source.saved, isEmpty);
    expect(source.prefSaves, isEmpty);
    expect(source.loads, 1);
  });
  testWidgets('资料弹窗取消不保存，成功保存刷新昵称；保存中阻止重复点击', (tester) async {
    final source = FakeProfileSource();
    await mountProfile(tester, source);
    await profileTap(tester, find.byKey(const Key('profile-edit')));
    await profileEnter(tester, 'profile-edit-nickName', '取消的昵称');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(source.saved, isEmpty);
    expect(find.text('取消的昵称'), findsNothing);
    await profileTap(tester, find.byKey(const Key('profile-edit')));
    await profileEnter(tester, 'profile-edit-nickName', '修改后的合成昵称');
    source.saveGate = Completer<void>();
    await tester.tap(find.byKey(const Key('profile-edit-save')));
    await tester.pump();
    expect(source.saved, hasLength(1));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('profile-edit-save')))
          .onPressed,
      isNull,
    );
    source.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ProfileEditDialog), findsNothing);
    expect(source.loads, 2);
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-display-name'))).data,
      '修改后的合成昵称',
    );
    expect(source.saved.single.containsKey('deptId'), isFalse);
  });
  testWidgets('资料字段校验及服务端拒绝保留表单，不假报保存成功', (tester) async {
    final source = FakeProfileSource()..saveFails = true;
    await mountProfile(tester, source);
    await profileTap(tester, find.byKey(const Key('profile-edit')));
    await profileEnter(tester, 'profile-edit-nickName', '');
    await profileEnter(tester, 'profile-edit-email', 'not-email');
    await profileTap(tester, find.byKey(const Key('profile-edit-save')));
    expect(find.text('请填写姓名或昵称'), findsOneWidget);
    expect(find.text('请输入有效邮箱地址'), findsOneWidget);
    expect(source.saved, isEmpty);
    await profileEnter(tester, 'profile-edit-nickName', '合成新昵称');
    await profileEnter(tester, 'profile-edit-email', 'new@example.com');
    await profileTap(tester, find.byKey(const Key('profile-edit-save')));
    expect(find.text('合成邮箱已存在'), findsOneWidget);
    expect(find.byType(ProfileEditDialog), findsOneWidget);
    expect(source.loads, 1);
  });
  testWidgets('修改密码验证确认一致，失败可重试，成功沿用现有会话', (tester) async {
    final source = FakeProfileSource()..passwordFails = true;
    await mountProfile(tester, source);
    await profileTap(tester, find.byKey(const Key('profile-change-password')));
    await profileEnter(tester, 'profile-password-old', 'syntheticOld6');
    await profileEnter(tester, 'profile-password-new', 'syntheticNew6');
    await profileEnter(tester, 'profile-password-confirm', 'mismatch');
    await profileTap(tester, find.byKey(const Key('profile-password-save')));
    expect(find.text('两次新密码不一致'), findsOneWidget);
    expect(source.passwords, isEmpty);
    await profileEnter(tester, 'profile-password-confirm', 'syntheticNew6');
    await profileTap(tester, find.byKey(const Key('profile-password-save')));
    expect(find.text('旧密码错误'), findsOneWidget);
    source.passwordFails = false;
    await profileTap(tester, find.byKey(const Key('profile-password-save')));
    expect(source.passwords, hasLength(2));
    expect(source.loads, 2);
    expect(find.byType(ProfilePasswordDialog), findsNothing);
  });
  testWidgets('通知偏好保存后重新进入可回读，切换偏好不会覆盖其他选项', (tester) async {
    final source = FakeProfileSource();
    await mountProfile(tester, source);
    await profileTap(tester, find.byKey(const Key('profile-tab-2')));
    await profileTap(tester, find.byKey(const Key('profile-notice-interview')));
    expect(source.prefSaves, isEmpty);
    await profileTap(tester, find.byKey(const Key('profile-preferences-save')));
    expect(source.prefs.notices['interview'], isFalse);
    await profileTap(tester, find.byKey(const Key('profile-tab-1')));
    await profileTap(
      tester,
      find.byKey(const ValueKey('profile-pref-duration-45')),
    );
    await tester.tap(find.text('60 分钟').last);
    await tester.pumpAndSettle();
    await profileTap(tester, find.byKey(const Key('profile-preferences-save')));
    expect(source.prefs.duration, 60);
    expect(source.prefs.notices['interview'], isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await mountProfile(tester, source);
    await profileTap(tester, find.byKey(const Key('profile-tab-2')));
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('profile-notice-interview')),
          )
          .value,
      isFalse,
    );
  });
  testWidgets('头像选择取消不上传，上传失败提示错误，成功后重新加载资料', (tester) async {
    final source = FakeProfileSource();
    await mountProfile(tester, source);
    await profileTap(tester, find.byKey(const Key('profile-avatar')));
    expect(source.picks, 1);
    expect(source.uploads, 0);
    source.picked = ProfileAvatar(
      name: 'synthetic.png',
      bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
    );
    source.uploadFails = true;
    await profileTap(tester, find.byKey(const Key('profile-avatar')));
    expect(find.text('合成上传失败'), findsOneWidget);
    expect(source.loads, 1);
    source.uploadFails = false;
    await profileTap(tester, find.byKey(const Key('profile-avatar')));
    expect(source.uploads, 2);
    expect(source.loads, 2);
  });
  testWidgets('错误可重试，外部reload读取最新资料，退出须用户确认', (tester) async {
    final source = FakeProfileSource()..loadFails = true;
    var logout = 0;
    final key = GlobalKey<AccountPageState>();
    await mountProfile(tester, source, pageKey: key, logout: () => logout++);
    expect(find.text('合成网络失败'), findsOneWidget);
    source.loadFails = false;
    await profileTap(tester, find.text('重试'));
    source.user['nickName'] = '刷新后的合成昵称';
    await key.currentState!.reload();
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-display-name'))).data,
      '刷新后的合成昵称',
    );
    await profileTap(tester, find.byKey(const Key('profile-logout')));
    expect(logout, 0);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await profileTap(tester, find.byKey(const Key('profile-logout')));
    await tester.tap(find.byKey(const Key('profile-logout-confirm')));
    await tester.pumpAndSettle();
    expect(logout, 1);
  });
  testWidgets('本机设置读取失败不阻断个人资料，也不允许覆盖坏数据', (tester) async {
    final source = FakeProfileSource()..settingsFail = true;
    await mountProfile(tester, source);
    expect(find.text('基本信息'), findsOneWidget);
    await profileTap(tester, find.byKey(const Key('profile-tab-1')));
    expect(find.text('本机设置读取失败，请重试'), findsOneWidget);
    expect(find.byKey(const Key('profile-preferences-save')), findsNothing);
    source.settingsFail = false;
    source.prefs = const ProfilePreferences(duration: 60);
    await profileTap(tester, find.text('重新读取设置'));
    expect(find.byKey(const Key('profile-preferences-save')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('profile-pref-duration-60')),
      findsOneWidget,
    );
  });
  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('我的和资料弹窗在 $size 与键盘场景下无溢出', (tester) async {
      await mountProfile(tester, FakeProfileSource(), size: size);
      expect(tester.takeException(), isNull);
      await profileTap(tester, find.byKey(const Key('profile-edit')));
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height < 500 ? 120 : 260,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await profileTap(tester, find.byKey(const Key('profile-tab-2')));
      expect(tester.takeException(), isNull);
    });
  }
}
