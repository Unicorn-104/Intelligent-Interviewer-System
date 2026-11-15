import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';
import 'package:intelligent_interviewer/screens/job_detail_screen.dart';
import 'job_favorites_test_support.dart';

void main() {
  testWidgets(
    'guest details never load private favorites or offer application',
    (tester) async {
      final api = FakeJobFavoriteApi();
      var privateRequests = 0;
      api.onState = () async {
        privateRequests++;
        throw StateError('Guests must not request favorites');
      };
      addTearDown(api.client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: JobDetailScreen(
            job: favoriteJob(91),
            session: const AuthSession(
              token: '',
              userId: 0,
              userName: '游客',
              nickName: '游客',
            ),
            favoriteApi: api,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(privateRequests, 0);
      expect(find.text('收藏状态加载失败'), findsNothing);
      expect(find.byTooltip('收藏职位'), findsNothing);
      expect(find.text('立即投递'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
