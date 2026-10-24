import 'dart:async';
import 'dart:typed_data';

import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/profile/account_page.dart';
import 'package:enterprise_recruiter/features/enterprise/profile/account_settings_page.dart';
import 'package:enterprise_recruiter/features/enterprise/profile/profile_edit_page.dart';
import 'package:enterprise_recruiter/features/enterprise/profile/data/profile_data_source.dart';
import 'package:enterprise_recruiter/features/enterprise/profile/models/profile_view_data.dart';
import 'package:enterprise_recruiter/features/enterprise/profile/widgets/profile_edit_dialog.dart';
import 'package:enterprise_recruiter/theme/app_theme.dart';
import 'package:enterprise_recruiter/features/enterprise/talent/talent_page.dart';
import 'package:enterprise_recruiter/features/enterprise/interview/recording_page.dart';
import 'package:enterprise_recruiter/features/enterprise/schedule/reschedule_review_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  if (target.evaluate().isEmpty &&
      find.byKey(const Key('profile-settings')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('profile-settings')));
    await tester.pumpAndSettle();
  }
  if (target.evaluate().isEmpty && find.text('账号与安全中心').evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('profile-tab-0')));
    await tester.pumpAndSettle();
  }
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
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('企业管理移到我的名片下方，齿轮仅保留个人设置', (tester) async {
    final source = FakeProfileSource();
    await mountProfile(tester, source);
    expect(find.text('我的'), findsOneWidget);
    expect(find.byKey(const Key('profile-business-card')), findsOneWidget);
    expect(find.byKey(const Key('profile-tab-1')), findsNothing);
    expect(find.byKey(const Key('profile-tab-2')), findsNothing);
    expect(find.text('账号与安全'), findsNothing);
    expect(find.text('最近登录'), findsNothing);
    expect(find.byKey(const Key('profile-enterprise-settings')), findsNothing);
    expect(find.text('企业管理'), findsOneWidget);
    expect(find.byKey(const Key('profile-logout')), findsNothing);
    await profileTap(tester, find.byKey(const Key('profile-settings')));
    expect(find.byType(AccountSettingsPage), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.byKey(const Key('profile-tab-1')), findsOneWidget);
    expect(find.byKey(const Key('profile-tab-2')), findsOneWidget);
    expect(find.text('账号与安全中心'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('profile-settings-scroll')),
      const Offset(0, -1800),
    );
    await tester.pumpAndSettle();
    expect(find.text('企业设置'), findsNothing);
    expect(find.byKey(const Key('profile-enterprise-settings')), findsNothing);
    expect(source.prefSaves, isEmpty);
    expect(source.saved, isEmpty);
    await tester.tap(find.byKey(const Key('profile-settings-back')));
    await tester.pumpAndSettle();
    expect(find.byType(AccountSettingsPage), findsNothing);
    expect(find.byKey(const Key('profile-business-card')), findsOneWidget);
    expect(find.text('账号与安全'), findsNothing);
  });

  testWidgets('设置中的联系方式编辑返回时设置资料与名片均刷新', (tester) async {
    final source = FakeProfileSource();
    await mountProfile(tester, source);
    await profileTap(tester, find.text('联系邮箱'));
    expect(find.byType(ProfileEditPage), findsOneWidget);
    await profileEnter(tester, 'profile-edit-nickName', '设置中更新的昵称');
    await profileTap(tester, find.byKey(const Key('profile-edit-save')));
    expect(find.byType(AccountSettingsPage), findsOneWidget);
    expect(find.byType(ProfileEditPage), findsNothing);
    await tester.tap(find.byKey(const Key('profile-settings-back')));
    await tester.pumpAndSettle();
    expect(find.text('账号与安全中心'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-settings-back')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-display-name'))).data,
      '设置中更新的昵称',
    );
  });

  testWidgets('我的用浅蓝资料区和右侧箭头编辑，敏感字段不展示且取消不保存', (tester) async {
    final source = FakeProfileSource();
    await mountProfile(tester, source);
    expect(find.text('基本信息'), findsNothing);
    expect(find.text('个人资料'), findsOneWidget);
    expect(find.text('账号安全'), findsNothing);
    expect(find.text('通知偏好'), findsNothing);
    expect(find.byKey(const Key('profile-settings')), findsOneWidget);
    expect(find.text('synthetic@example.com'), findsNothing);
    expect(find.text('登录账号：synthetic-account'), findsNothing);
    expect(find.text('合成招聘说明'), findsOneWidget);
    final card = find.byKey(const Key('profile-business-card'));
    final decor = tester.widget<DecoratedBox>(
      find.ancestor(of: card, matching: find.byType(DecoratedBox)).first,
    );
    expect((decor.decoration as BoxDecoration).gradient, isA<LinearGradient>());
    final frame = tester.widget<Material>(
      find.byKey(const Key('profile-card-frame')),
    );
    expect(frame.color, AppColors.canvas);
    expect(frame.elevation, 0);
    final shape = frame.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(8));
    expect(shape.side.width, 1);
    expect(shape.side.color, AppColors.interactive.withValues(alpha: .22));
    await profileTap(tester, card);
    expect(find.byType(ProfileEditPage), findsOneWidget);
    expect(find.byType(ProfilePasswordDialog), findsNothing);
    expect(find.text('基本资料'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('profile-edit-email')))
          .controller!
          .text,
      'synthetic@example.com',
    );
    await profileEnter(tester, 'profile-edit-nickName', '不保存的名称');
    await profileTap(tester, find.byKey(const Key('profile-edit-back')));
    expect(source.saved, isEmpty);
    expect(source.loads, 1);
    expect(
      tester.widget<Text>(find.byKey(const Key('profile-display-name'))).data,
      '合成招聘经理',
    );
  });

  testWidgets('联系方式安全入口仍打开同一编辑页，系统返回保留原资料', (tester) async {
    final source = FakeProfileSource();
    await mountProfile(tester, source);
    await profileTap(tester, find.text('联系邮箱'));
    expect(find.byType(ProfileEditPage), findsOneWidget);
    await profileEnter(tester, 'profile-edit-email', 'cancelled@example.com');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ProfileEditPage), findsNothing);
    expect(source.saved, isEmpty);
    expect(source.user['email'], 'synthetic@example.com');
  });

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
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('profile-settings-back')))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AccountSettingsPage), findsOneWidget);
    source.preferencesGate!.complete();
    await tester.pumpAndSettle();
    expect(source.prefs.notices['interview'], isFalse);
  });

  testWidgets('我的展示名片，齿轮进入设置分区且切换不写接口', (tester) async {
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
  testWidgets('独立编辑页取消不保存，成功保存刷新名片；保存中阻止重复点击', (tester) async {
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
    await tester.ensureVisible(find.byKey(const Key('profile-edit-save')));
    await tester.pumpAndSettle();
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
    expect(find.byType(ProfileEditPage), findsNothing);
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
    expect(find.byType(ProfileEditPage), findsOneWidget);
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
  testWidgets('名片进入编辑页更换头像，取消选图不上传，失败可重试，返回刷新名片', (tester) async {
    final source = FakeProfileSource();
    await mountProfile(tester, source);
    expect(find.byKey(const Key('profile-avatar')), findsNothing);
    await profileTap(tester, find.byKey(const Key('profile-business-card')));
    expect(find.byType(ProfileEditPage), findsOneWidget);
    expect(find.text('个人资料'), findsOneWidget);
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
    await profileEnter(tester, 'profile-edit-nickName', '头像变更不应提交的昵称');
    source.uploadFails = false;
    await profileTap(tester, find.byKey(const Key('profile-avatar')));
    expect(source.uploads, 2);
    expect(source.loads, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(source.loads, 2);
    expect(source.saved, isEmpty);
    expect(source.user['nickName'], '合成招聘经理');
    expect(find.byType(ProfileEditPage), findsNothing);
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
    expect(find.text('基本信息'), findsNothing);
    expect(find.byKey(const Key('profile-business-card')), findsOneWidget);
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
  testWidgets('设置首页是纵向分类，未接入能力明确提示且不写数据', (tester) async {
    final source = FakeProfileSource();
    await mountProfile(tester, source);
    await profileTap(tester, find.byKey(const Key('profile-settings')));
    for (final label in ['账号与安全中心', '通知与提醒', '隐私保护', '通用设置', '消息设置']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('最近登录'), findsNothing);
    await profileTap(tester, find.text('隐私保护'));
    expect(find.text('隐私保护功能开发中'), findsOneWidget);
    expect(source.saved, isEmpty);
    expect(source.prefSaves, isEmpty);
    await profileTap(tester, find.byKey(const Key('profile-tab-0')));
    expect(find.byKey(const Key('profile-change-password')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('账号与安全中心'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AccountSettingsPage), findsNothing);
  });

  testWidgets('首页去掉重复快捷入口，四个企业管理入口紧接资料区且各保留一次', (tester) async {
    final source = FakeProfileSource();
    await mountProfile(tester, source);
    expect(find.text('个人资料'), findsOneWidget);
    expect(find.text('账号安全'), findsNothing);
    expect(find.text('通知偏好'), findsNothing);
    final card = find.byKey(const Key('profile-business-card'));
    final management = find.byKey(const Key('profile-enterprise-management'));
    expect(management, findsOneWidget);
    expect(
      tester.getTopLeft(management).dy - tester.getBottomLeft(card).dy,
      inInclusiveRange(0, 12),
    );
    for (final name in ['部门管理', '成员管理', '通知模板', '集成配置']) {
      expect(find.byKey(ValueKey('profile-management-$name')), findsOneWidget);
    }
    await profileTap(tester, find.byKey(const Key('profile-edit')));
    expect(find.byType(ProfileEditPage), findsOneWidget);
    await profileTap(tester, find.byKey(const Key('profile-edit-back')));
    await profileTap(tester, find.byKey(const Key('profile-settings')));
    expect(find.text('账号与安全中心'), findsOneWidget);
    await profileTap(tester, find.byKey(const Key('profile-tab-2')));
    expect(find.byKey(const Key('profile-notice-interview')), findsOneWidget);
    expect(source.prefSaves, isEmpty);
    expect(source.saved, isEmpty);
  });

  testWidgets('我的招聘工具一排展示迁移入口，真实人才库及审批不标演示，录播保留演示标识', (tester) async {
    final source = FakeProfileSource();
    await mountProfile(tester, source);
    for (final (label, pageType, demo) in [
      ('人才库', TalentPage, false),
      ('录播', RecordingPage, true),
      ('改期审批', RescheduleReviewPage, false),
    ]) {
      final entry = find.byKey(ValueKey('profile-tool-$label'));
      await tester.ensureVisible(entry);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: entry, matching: find.text('演示数据')),
        demo ? findsOneWidget : findsNothing,
      );
      await tester.tap(entry);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(find.byType(pageType), findsOneWidget);
      if (label == '人才库') {
        expect(
          tester.widget<TalentPage>(find.byType(TalentPage)).discovery,
          isTrue,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('profile-tool-$label')), findsOneWidget);
    }
    expect(source.saved, isEmpty);
    expect(source.prefSaves, isEmpty);
  });

  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('企业管理四项在宽度$width下横向同排且依次排列', (tester) async {
      await mountProfile(tester, FakeProfileSource(), size: Size(width, 1000));
      expect(find.byKey(const Key('profile-management-row')), findsOneWidget);
      final entries = [
        for (final name in ['部门管理', '成员管理', '通知模板', '集成配置'])
          find.byKey(ValueKey('profile-management-$name')),
      ];
      final firstTop = tester.getTopLeft(entries.first).dy;
      var previousRight = 0.0;
      for (final entry in entries) {
        final left = tester.getTopLeft(entry);
        final right = tester.getTopRight(entry);
        expect(left.dy, closeTo(firstTop, .01));
        expect(left.dx, greaterThanOrEqualTo(previousRight));
        expect(right.dx, lessThanOrEqualTo(width));
        previousRight = right.dx;
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('320dp大字号个人中心与设置分类可滚动且不溢出', (tester) async {
    await mountProfile(tester, FakeProfileSource(), size: const Size(320, 700));
    final context = tester.element(find.byType(AccountPage));
    final widget = MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(2)),
      child: AccountPage(source: FakeProfileSource(), onLogout: () {}),
    );
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: widget));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await profileTap(tester, find.byKey(const Key('profile-settings')));
    await tester.scrollUntilVisible(
      find.text('第三方共享清单'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('第三方共享清单').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('我的和独立编辑页在 $size 与键盘场景下无溢出', (tester) async {
      await mountProfile(tester, FakeProfileSource(), size: size);
      expect(tester.takeException(), isNull);
      for (final name in ['部门管理', '成员管理', '通知模板', '集成配置']) {
        final entry = find.byKey(ValueKey('profile-management-$name'));
        await tester.scrollUntilVisible(
          entry,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(entry);
        await tester.pumpAndSettle();
        expect(entry.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const Key('profile-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
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
      expect(find.byType(AccountSettingsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
