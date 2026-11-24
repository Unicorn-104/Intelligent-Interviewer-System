import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/core/network/api_exception.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';
import 'package:intelligent_interviewer/features/messages/data/chat_attachment_picker.dart';
import 'package:intelligent_interviewer/features/messages/data/message_api.dart';
import 'package:intelligent_interviewer/features/messages/domain/app_message.dart';
import 'package:intelligent_interviewer/features/profile/data/profile_api.dart';
import 'package:intelligent_interviewer/features/profile/domain/user_profile.dart';
import 'package:intelligent_interviewer/features/profile/presentation/profile_avatar.dart';
import 'package:intelligent_interviewer/screens/hr_chat_screen.dart';

class _Profile extends ProfileApi {
  _Profile(super.client);
  @override
  Future<UserProfile> fetchProfile(String token) async =>
      const UserProfile(userId: 12, userName: 'synthetic', nickName: '本人');
}

class _Messages extends MessageApi {
  _Messages(super.client);
  int uploads = 0, sends = 0;
  bool failUpload = false, uncertain = false, cancelPick = false;
  @override
  Future<List<ChatMessage>> fetchHrChat(String token, int sessionId) async => [
    ChatMessage(
      messageId: 1,
      senderId: 11,
      content: '原有文本',
      mine: false,
      createdAt: DateTime(2026),
    ),
    ChatMessage(
      messageId: 2,
      senderId: 12,
      content: '本人文本',
      mine: true,
      createdAt: DateTime(2026),
    ),
  ];
  @override
  Future<ChatPickedAttachment?> pickAttachment({required bool image}) async =>
      cancelPick
      ? null
      : ChatPickedAttachment(
          name: '合成.txt',
          bytes: Uint8List.fromList([65]),
          isImage: false,
        );
  @override
  Future<ChatUploadedAttachment> uploadAttachment(
    String token,
    ChatPickedAttachment file,
  ) async {
    uploads++;
    if (failUpload) throw const ApiException('上传失败，请重试', code: 500);
    return ChatUploadedAttachment(
      name: file.name,
      url: '/profile/file.txt',
      isImage: false,
    );
  }

  @override
  Future<void> sendAttachment(
    String token,
    int sessionId,
    ChatUploadedAttachment file,
  ) async {
    sends++;
    if (uncertain) throw const ApiException('连接超时');
  }
}

void main() {
  Future<_Messages> open(WidgetTester tester) async {
    final client = ApiClient();
    addTearDown(client.close);
    final api = _Messages(client);
    await tester.pumpWidget(
      MaterialApp(
        home: HrChatScreen(
          session: const AuthSession(
            token: 'synthetic',
            userId: 12,
            userName: 'synthetic',
            nickName: '本人',
          ),
          conversation: AppMessage(
            sourceId: 8,
            category: AppMessageCategory.hr,
            title: '招聘者',
            content: '',
            occurredAt: DateTime(2026),
            unreadCount: 0,
          ),
          messageApi: api,
          profileApi: _Profile(client),
          pollInterval: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  Future<void> choose(WidgetTester tester) async {
    await tester.tap(find.byTooltip('发送图片或文件'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发送文件'));
    // 确认弹窗期间输入栏显示忙碌动画，等待弹窗入场即可。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('取消不上传；双方真实头像组件和旧文本保留；上传失败可重试', (tester) async {
    final api = await open(tester);
    expect(find.byType(ProfileAvatar), findsNWidgets(2));
    expect(find.text('原有文本'), findsOneWidget);
    api.cancelPick = true;
    await choose(tester);
    expect(api.uploads, 0);
    api.cancelPick = false;
    await choose(tester);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(api.uploads, 0);
    api.failUpload = true;
    await choose(tester);
    await tester.tap(find.text('确认发送'));
    await tester.pumpAndSettle();
    expect(api.sends, 0);
    expect(find.text('重试发送'), findsOneWidget);
    api.failUpload = false;
    await tester.tap(find.text('重试发送'));
    await tester.pumpAndSettle();
    expect(api.uploads, 2);
    expect(api.sends, 1);
    expect(find.text('重试发送'), findsNothing);
  });
  testWidgets('发送超时不提供重复发送，刷新不会重发且文字草稿保留', (tester) async {
    final api = await open(tester);
    api.uncertain = true;
    await tester.enterText(find.byType(TextField), '保留草稿');
    await choose(tester);
    await tester.tap(find.text('确认发送'));
    await tester.pumpAndSettle();
    expect(find.text('重试发送'), findsNothing);
    expect(find.textContaining('发送结果待确认'), findsOneWidget);
    await tester.tap(find.text('刷新记录'));
    await tester.pumpAndSettle();
    expect(api.sends, 1);
    expect(find.text('保留草稿'), findsOneWidget);
  });
  testWidgets('320宽与键盘出现时附件失败反馈和输入栏不溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final api = await open(tester);
    api.failUpload = true;
    await choose(tester);
    await tester.tap(find.text('确认发送'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    expect(find.text('重试发送'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
