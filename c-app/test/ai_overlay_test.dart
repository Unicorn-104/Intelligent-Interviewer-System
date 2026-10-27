import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';
import 'package:intelligent_interviewer/features/messages/data/message_api.dart';
import 'package:intelligent_interviewer/features/messages/domain/app_message.dart';
import 'package:intelligent_interviewer/screens/messages_screen.dart';
import 'package:intelligent_interviewer/theme/app_theme.dart';

class _Messages extends MessageApi {
  _Messages(this.client) : super(client);
  final ApiClient client;
  @override
  Future<List<AppMessage>> fetchMessages(String token) async => List.generate(
    20,
    (i) => AppMessage(
      sourceId: i + 1,
      category: AppMessageCategory.system,
      title: '测试通知 $i',
      content: '合成通知内容',
      occurredAt: DateTime(2026, 10, 20),
      unreadCount: 0,
    ),
  );
}

void main() {
  testWidgets(
    'AI entry overlays root navigation and closes without losing message scroll',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final client = ApiClient();
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: Scaffold(
            bottomNavigationBar: const SizedBox(
              height: 64,
              child: Center(
                child: Text('测试导航栏', key: ValueKey('root-navigation')),
              ),
            ),
            body: SafeArea(
              child: MessagesScreen(
                session: const AuthSession(
                  token: 'synthetic-token',
                  userId: 17,
                  userName: 'test',
                  nickName: 'test',
                ),
                onUnreadChanged: (_) {},
                messageApi: _Messages(client),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AI Agent'), findsNothing);
      expect(find.text('全部'), findsNothing);
      expect(find.text('全部已读'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final offset = scroll.position.pixels;
      expect(offset, greaterThan(0));
      await tester.tap(find.byTooltip('AI 助手'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('关闭 AI 助手'), findsOneWidget);
      expect(find.text('你可以对我说'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('root-navigation')).hitTestable(),
        findsNothing,
      );
      expect(find.byType(TextField), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.showKeyboard(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(find.byType(TextField)).dy,
        lessThanOrEqualTo(520),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('关闭 AI 助手'));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(
        find.byKey(const ValueKey('root-navigation')).hitTestable(),
        findsOneWidget,
      );
      expect(scroll.position.pixels, closeTo(offset, 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
