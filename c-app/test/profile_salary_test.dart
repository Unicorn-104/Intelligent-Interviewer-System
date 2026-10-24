import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';
import 'package:intelligent_interviewer/features/profile/data/profile_api.dart';
import 'package:intelligent_interviewer/features/profile/domain/user_profile.dart';
import 'package:intelligent_interviewer/features/profile/presentation/profile_controller.dart';
import 'package:intelligent_interviewer/screens/profile_edit_screen.dart';

class SalaryProfileApi extends ProfileApi {
  SalaryProfileApi() : super(ApiClient());
  final saved = <UserProfile>[];
  @override
  Future<UserProfile> updateProfile(String token, UserProfile profile) async {
    saved.add(profile);
    return profile;
  }
}

void main() {
  const initial = UserProfile(
    userId: 101,
    userName: 'synthetic',
    nickName: '合成用户',
  );
  test('薪资反序列化、普通资料编辑保留、显式面议/清除均不混淆', () {
    final p = UserProfile.fromJson({
      'userId': 101,
      'userName': 'synthetic',
      'nickName': '合成用户',
      'salaryMin': 8000,
      'salaryMax': 12000,
      'salaryNegotiable': 0,
    });
    expect(p.copyWith(nickName: '合成改名').salaryMax, 12000);
    expect(p.toUpdateJson()['salaryMin'], 8000);
    final negotiable = p.copyWith(updateSalary: true, salaryNegotiable: 1);
    expect(negotiable.salaryMin, isNull);
    expect(negotiable.salaryMax, isNull);
    final clear = p.copyWith(updateSalary: true);
    expect(clear.toUpdateJson()['salaryNegotiable'], isNull);
    expect(clear.toUpdateJson()['salaryMin'], isNull);
  });
  testWidgets('本人填写区间校验后通过原资料接口保存，取消不提交', (tester) async {
    final api = SalaryProfileApi();
    final controller = ProfileController(
      api,
      session: const AuthSession(
        token: 'synthetic-token',
        userId: 101,
        userName: 'synthetic',
        nickName: '合成用户',
      ),
    );
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileEditScreen(
                    initialProfile: initial,
                    controller: controller,
                  ),
                ),
              ),
              child: const Text('编辑'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-salary-mode')),
      250,
      scrollable: scroll,
    );
    await tester.tap(find.byKey(const Key('profile-salary-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('填写月薪区间').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('profile-salary-min')));
    await tester.enterText(find.byKey(const Key('profile-salary-min')), '8000');
    await tester.ensureVisible(find.byKey(const Key('profile-salary-max')));
    await tester.enterText(
      find.byKey(const Key('profile-salary-max')),
      '12000',
    );
    await tester.scrollUntilVisible(find.text('保存修改'), 250, scrollable: scroll);
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    expect(api.saved, hasLength(1));
    expect(api.saved.single.salaryMin, 8000);
    expect(api.saved.single.salaryMax, 12000);
    expect(api.saved.single.salaryNegotiable, 0);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(320, 700), const Size(900, 420)]) {
    testWidgets('薪资表单在$size大字号与键盘下可填写且取消不提交', (tester) async {
      final api = SalaryProfileApi();
      final controller = ProfileController(
        api,
        session: const AuthSession(
          token: 'synthetic-token',
          userId: 101,
          userName: 'synthetic',
          nickName: '合成用户',
        ),
      );
      addTearDown(controller.dispose);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ProfileEditScreen(
            initialProfile: initial.copyWith(
              updateSalary: true,
              salaryNegotiable: 0,
              salaryMin: 8000,
              salaryMax: 12000,
            ),
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-salary-min')),
        240,
        scrollable: scroll,
      );
      tester.view.viewInsets = FakeViewPadding(
        bottom: size.height < 500 ? 100 : 220,
      );
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(
        find.byKey(const Key('profile-salary-min')),
        '9000',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(api.saved, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(api.saved, isEmpty);
    });
  }
}
