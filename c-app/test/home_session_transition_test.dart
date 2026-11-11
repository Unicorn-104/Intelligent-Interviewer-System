import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';
import 'package:intelligent_interviewer/features/interviews/presentation/interview_calendar.dart';
import 'package:intelligent_interviewer/screens/main_shell.dart';
import 'package:intelligent_interviewer/screens/messages_screen.dart';

void main() {
  testWidgets(
    'interview calendar uses the current login after guest browsing',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> showSession(AuthSession? session) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MainShell(
              session: session,
              onLogin: () {},
              onLogout: () async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      AuthSession session(String token) => AuthSession(
        token: token,
        userId: 7,
        userName: 'candidate',
        nickName: '候选人',
      );

      String calendarToken() => tester
          .widget<InterviewCalendar>(find.byType(InterviewCalendar))
          .controller
          .token;

      await showSession(null);
      expect(find.byType(InterviewCalendar), findsNothing);

      await showSession(session('first-login'));
      expect(calendarToken(), 'first-login');

      await showSession(session('renewed-login'));
      expect(calendarToken(), 'renewed-login');
      tester
          .widget<MessagesScreen>(
            find.byType(MessagesScreen, skipOffstage: false),
          )
          .onUnreadChanged(4);
      await tester.pump();
      expect(find.byType(Badge), findsWidgets);

      await showSession(null);
      expect(find.byType(InterviewCalendar), findsNothing);
      final navigation = tester.widget<NavigationBar>(
        find.byType(NavigationBar),
      );
      expect(
        (navigation.destinations[2] as NavigationDestination).icon,
        isNot(isA<Badge>()),
      );

      await showSession(session('next-login'));
      expect(calendarToken(), 'next-login');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
