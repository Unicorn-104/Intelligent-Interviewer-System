import 'dart:typed_data';

import 'package:enterprise_recruiter/features/enterprise/jobs/data/jd_document_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/jd_import_fixture.dart';

void main() {
  Future<JdPickedDocument?> pick(SyntheticJdPlatformFile file) =>
      JdDocumentPicker(pickFile: () async => file).pick();

  Matcher selectionError(String message) => isA<JdDocumentSelectionException>()
      .having((error) => error.message, 'message', contains(message));

  test('用户取消选择返回 null', () async {
    expect(await JdDocumentPicker(pickFile: () async => null).pick(), isNull);
  });

  for (final entry in [
    ('synthetic.pdf', 'application/pdf'),
    ('synthetic.PDF', 'application/pdf'),
    (
      'synthetic.docx',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    ),
    (
      'synthetic.DoCx',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    ),
  ]) {
    test('接受 ${entry.$1} 并提供正确 MIME', () async {
      final file = SyntheticJdPlatformFile(name: entry.$1);
      final result = await pick(file);
      expect(result!.name, entry.$1);
      expect(result.mimeType, entry.$2);
      expect(result.bytes, orderedEquals(file.bytes));
      expect(file.reads, 1);
    });
  }

  for (final name in ['legacy.doc', 'image.png', 'no-extension']) {
    test('拒绝不支持的扩展名 $name 且不读取内容', () async {
      final file = SyntheticJdPlatformFile(name: name);
      await expectLater(pick(file), throwsA(selectionError('仅支持PDF或DOCX')));
      expect(file.reads, 0);
    });
  }

  test('拒绝元数据声明为空的文件', () async {
    final file = SyntheticJdPlatformFile(bytes: Uint8List(0));
    await expectLater(pick(file), throwsA(selectionError('文档为空')));
    expect(file.reads, 0);
  });

  test('未知长度读取后为空也拒绝', () async {
    final file = SyntheticJdPlatformFile(
      bytes: Uint8List(0),
      unknownSize: true,
    );
    await expectLater(pick(file), throwsA(selectionError('文档为空')));
    expect(file.reads, 1);
  });

  test('恰好10MB允许上传，返回字节不可修改', () async {
    final file = SyntheticJdPlatformFile(
      bytes: Uint8List(JdPickedDocument.maxBytes),
    );
    final document = await pick(file);
    expect(document!.size, 10 * 1024 * 1024);
    expect(() => document.bytes[0] = 1, throwsUnsupportedError);
  });

  test('超过10MB的声明大小在读取之前拒绝', () async {
    final file = SyntheticJdPlatformFile(
      reportedSize: JdPickedDocument.maxBytes + 1,
    );
    await expectLater(pick(file), throwsA(selectionError('不能超过10MB')));
    expect(file.reads, 0);
  });

  test('未知长度按真实流累计大小，超限即拒绝', () async {
    final file = SyntheticJdPlatformFile(
      unknownSize: true,
      streamSource: () async* {
        yield Uint8List(JdPickedDocument.maxBytes);
        yield Uint8List(1);
        throw StateError('Must stop reading before this point');
      },
    );
    await expectLater(pick(file), throwsA(selectionError('不能超过10MB')));
  });

  test('未知长度的正常分块流允许读取', () async {
    final file = SyntheticJdPlatformFile(
      unknownSize: true,
      streamSource: () async* {
        yield Uint8List.fromList([1, 2]);
        yield Uint8List.fromList([3]);
      },
    );
    expect((await pick(file))!.bytes, orderedEquals([1, 2, 3]));
  });

  for (final entry in [(true, false), (false, true)]) {
    test('读取失败（stream=${entry.$1} metadata=${entry.$2}）转为友好错误', () async {
      await expectLater(
        pick(SyntheticJdPlatformFile(failRead: entry.$1, failLength: entry.$2)),
        throwsA(selectionError('无法读取所选文件')),
      );
    });
  }

  test('声明与实际读取长度不符时拒绝不完整文件', () async {
    await expectLater(
      pick(SyntheticJdPlatformFile(reportedSize: 8)),
      throwsA(selectionError('文件读取不完整')),
    );
  });
}
