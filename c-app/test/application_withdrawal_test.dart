import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/applications/data/application_api.dart';
import 'package:intelligent_interviewer/features/applications/domain/job_application.dart';
import 'package:intelligent_interviewer/features/applications/presentation/application_detail_screen.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';

JobApplication item({bool withdrawn = false, bool eligible = true}) =>
    JobApplication(
      id: 91,
      jobTitle: '合成岗位',
      companyName: '合成企业',
      status: withdrawn ? 'closed' : 'active',
      statusText: withdrawn ? '已撤回' : '待处理',
      canWithdraw: !withdrawn && eligible,
    );

class _Api extends ApplicationApi {
  _Api(super.client);
  JobApplication current = item();
  int calls = 0;
  bool reject = false;
  @override
  Future<JobApplication> detail(String token, int applicationId) async =>
      current;
  @override
  Future<JobApplication> withdraw(String token, int applicationId) async {
    expect(token, 'synthetic');
    expect(applicationId, 91);
    calls++;
    if (reject) {
      current = item(eligible: false);
      throw const ApiException('投递状态已更新，无法撤回');
    }
    return current = item(withdrawn: true);
  }
}

void main() {
  Future<void> open(WidgetTester tester, _Api api) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ApplicationDetailScreen(
          session: const AuthSession(
            token: 'synthetic',
            userId: 17,
            userName: 'test',
            nickName: 'test',
          ),
          applicationId: 91,
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('撤回投递'));
    await tester.tap(find.text('撤回投递'));
    await tester.pumpAndSettle();
  }

  testWidgets('cancel withdrawal does not send request', (tester) async {
    final client = ApiClient();
    addTearDown(client.close);
    final api = _Api(client);
    await open(tester, api);
    await tester.tap(find.text('暂不撤回'));
    await tester.pumpAndSettle();
    expect(api.calls, 0);
    expect(find.text('撤回投递'), findsOneWidget);
  });

  testWidgets(
    'confirmed withdrawal displays retained record and removes action',
    (tester) async {
      final client = ApiClient();
      addTearDown(client.close);
      final api = _Api(client);
      await open(tester, api);
      await tester.tap(find.text('确认撤回'));
      await tester.pumpAndSettle();
      expect(api.calls, 1);
      expect(find.text('合成岗位'), findsOneWidget);
      expect(find.text('已撤回'), findsOneWidget);
      expect(find.text('撤回投递'), findsNothing);
    },
  );

  testWidgets(
    'state conflict refreshes detail instead of showing withdrawn success',
    (tester) async {
      final client = ApiClient();
      addTearDown(client.close);
      final api = _Api(client)..reject = true;
      await open(tester, api);
      await tester.tap(find.text('确认撤回'));
      await tester.pumpAndSettle();
      expect(find.text('投递状态已更新，无法撤回'), findsOneWidget);
      expect(find.text('撤回投递'), findsNothing);
      expect(find.text('已撤回'), findsNothing);
    },
  );
}
