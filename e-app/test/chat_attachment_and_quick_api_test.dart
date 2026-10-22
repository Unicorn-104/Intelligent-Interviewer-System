import 'dart:convert';
import 'dart:typed_data';

import 'package:enterprise_recruiter/core/network/api_exception.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/data/chat_attachment_picker.dart';
import 'package:enterprise_recruiter/features/enterprise/notification/data/message_data_source.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/jd_http_fixture.dart';
import 'support/jd_import_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late JdHttpFixture http;
  late MessageDataSource source;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'enterprise_access_token': 'synthetic-test-token',
    });
    http = JdHttpFixture();
    source = MessageDataSource(client: http.client);
  });
  tearDown(() => http.close());
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jC1kAAAAASUVORK5CYII=',
  );

  test('常用语保留真实ID和分类，相同内容不同模板不可错位合并', () async {
    http.adapter.body = {
      'code': 200,
      'data': [
        {'id': 7, 'content': '合成常用语', 'category': '邀约'},
        {'id': 8, 'content': '合成常用语', 'category': '跟进'},
        {'id': 7, 'content': '合成重复记录', 'category': '邀约'},
      ],
    };
    final rows = await source.loadQuickReplies();
    expect(rows.map((r) => r.id), [7, 8]);
    http.adapter.body = {'code': 200};
    await source.saveQuickReply(reply: rows.last, content: '  合成修改常用语  ');
    final request = http.adapter.requests.last;
    expect(request.path, '/system/im/quick-replies');
    expect(request.method, 'POST');
    expect(request.data, {'id': 8, 'category': '跟进', 'content': '合成修改常用语'});
    await source.saveQuickReply(content: '合成新增常用语');
    expect(http.adapter.requests.last.data, {
      'category': '常用语',
      'content': '合成新增常用语',
    });
  });

  test('无登录态或空常用语不写服务端，拒绝缺失模板ID', () async {
    await expectLater(
      source.saveQuickReply(content: ' '),
      throwsFormatException,
    );
    expect(http.adapter.requests, isEmpty);
    FlutterSecureStorage.setMockInitialValues({});
    await expectLater(
      source.saveQuickReply(content: '合成内容'),
      throwsA(isA<ApiException>()),
    );
    expect(http.adapter.requests, isEmpty);
    FlutterSecureStorage.setMockInitialValues({
      'enterprise_access_token': 'synthetic-test-token',
    });
    http.adapter.body = {
      'code': 200,
      'data': [
        {'content': '合成内容'},
      ],
    };
    await expectLater(source.loadQuickReplies(), throwsFormatException);
  });

  test('图片和文件使用现有通用上传，完成上传不会自动发聊天消息', () async {
    http.adapter.body = {
      'code': 200,
      'fileName': '/profile/upload/synthetic.png',
      'url': 'https://untrusted.invalid/file',
    };
    final file = ChatPickedAttachment(
      name: 'synthetic.png',
      bytes: png,
      isImage: true,
    );
    final uploaded = await source.uploadAttachment(file);
    expect(http.adapter.requests.single.path, '/common/upload');
    expect(uploaded.url, '/profile/upload/synthetic.png');
    expect(uploaded.isImage, isTrue);
    expect(
      utf8.decode(http.adapter.wireBodies.single, allowMalformed: true),
      contains('filename="synthetic.png"'),
    );
    http.adapter.body = {'code': 200};
    await source.sendAttachment(8, uploaded);
    expect(http.adapter.requests.last.data, {
      'sessionId': 8,
      'type': 2,
      'content': 'synthetic.png',
      'attachmentUrl': '/profile/upload/synthetic.png',
    });
    await source.sendAttachment(
      8,
      const ChatUploadedAttachment(
        name: 'synthetic.pdf',
        url: '/profile/upload/synthetic.pdf',
        isImage: false,
      ),
    );
    expect(http.adapter.requests.last.data, {
      'sessionId': 8,
      'type': 3,
      'content': 'synthetic.pdf',
      'attachmentUrl': '/profile/upload/synthetic.pdf',
    });
  });

  test('不接受第三方、脚本、穿越或带密钥查询的附件地址', () async {
    for (final path in [
      '',
      'https://untrusted.invalid/profile/a.png',
      'javascript:alert(1)',
      '/profile/../secret.txt',
      '/profile/%2e%2e/secret.txt',
      '/profile/a.pdf?token=synthetic',
      '//untrusted.invalid/profile/a.png',
    ]) {
      expect(source.attachmentUrl(path), isNull, reason: path);
    }
    expect(source.attachmentUrl('/profile/upload/synthetic.png'), isNotNull);
    http.adapter.body = {'code': 200};
    await expectLater(
      source.uploadAttachment(
        ChatPickedAttachment(
          name: 'synthetic.pdf',
          bytes: Uint8List.fromList([1, 2, 3]),
          isImage: false,
        ),
      ),
      throwsFormatException,
    );
    expect(http.adapter.requests, hasLength(1));
    await expectLater(
      source.sendAttachment(
        8,
        const ChatUploadedAttachment(
          name: 'synthetic.pdf',
          url: 'https://untrusted.invalid/profile/a.pdf',
          isImage: false,
        ),
      ),
      throwsFormatException,
    );
    expect(http.adapter.requests, hasLength(1));
  });

  test('图片验证签名，文件验证类型和大小，返回字节不可更改', () {
    final image = ChatPickedAttachment(
      name: 'synthetic.PNG',
      bytes: png,
      isImage: true,
    );
    expect(image.mimeType, 'image/png');
    expect(() => image.bytes[0] = 1, throwsUnsupportedError);
    expect(
      () => ChatPickedAttachment(
        name: 'fake.png',
        bytes: Uint8List.fromList([1, 2, 3]),
        isImage: true,
      ),
      throwsFormatException,
    );
    expect(
      () => ChatPickedAttachment(
        name: 'blocked.exe',
        bytes: Uint8List(1),
        isImage: false,
      ),
      throwsFormatException,
    );
    expect(
      () => ChatPickedAttachment(
        name: 'empty.pdf',
        bytes: Uint8List(0),
        isImage: false,
      ),
      throwsFormatException,
    );
    expect(
      () => ChatPickedAttachment(
        name: 'large.pdf',
        bytes: Uint8List(ChatPickedAttachment.maxBytes + 1),
        isImage: false,
      ),
      throwsFormatException,
    );
  });

  test('取消文件选择返回null，超限元数据在读流前拦截', () async {
    expect(
      await ChatAttachmentPicker(pickFile: (_) async => null)
          .pick(image: false),
      isNull,
    );
    final tooLarge = SyntheticJdPlatformFile(
      name: 'synthetic.pdf',
      reportedSize: ChatPickedAttachment.maxBytes + 1,
    );
    await expectLater(
      ChatAttachmentPicker(pickFile: (_) async => tooLarge).pick(image: false),
      throwsFormatException,
    );
    expect(tooLarge.reads, 0);
    final wrongType = SyntheticJdPlatformFile(name: 'blocked.exe');
    await expectLater(
      ChatAttachmentPicker(pickFile: (_) async => wrongType).pick(image: false),
      throwsFormatException,
    );
    expect(wrongType.reads, 0);
    final image = SyntheticJdPlatformFile(name: 'synthetic.png', bytes: png);
    final result = await ChatAttachmentPicker(pickFile: (_) async => image)
        .pick(image: true);
    expect(result!.isImage, isTrue);
    expect(result.bytes, png);
  });

  test('文件流大小不符和未知长度超限必须拒绝', () async {
    final mismatch = SyntheticJdPlatformFile(
      name: 'synthetic.pdf',
      reportedSize: 20,
      bytes: Uint8List(10),
    );
    await expectLater(
      ChatAttachmentPicker(pickFile: (_) async => mismatch).pick(image: false),
      throwsFormatException,
    );
    final stream = SyntheticJdPlatformFile(
      name: 'synthetic.pdf',
      unknownSize: true,
      streamSource: () async* {
        yield Uint8List(ChatPickedAttachment.maxBytes);
        yield Uint8List(1);
      },
    );
    await expectLater(
      ChatAttachmentPicker(pickFile: (_) async => stream).pick(image: false),
      throwsFormatException,
    );
  });
}
