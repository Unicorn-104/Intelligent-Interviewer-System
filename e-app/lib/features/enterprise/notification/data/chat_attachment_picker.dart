import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class ChatPickedAttachment {
  ChatPickedAttachment({
    required String name,
    required Uint8List bytes,
    required this.isImage,
  }) : name = name.split(RegExp(r'[/\\]')).last,
       bytes = Uint8List.fromList(bytes).asUnmodifiableView() {
    validateName(this.name, isImage);
    validateSize(bytes.length);
    if (isImage && !_hasImageHeader(extension, bytes)) {
      throw const FormatException('图片内容与格式不符，请重新选择');
    }
  }
  static const maxBytes = 10 * 1024 * 1024;
  static const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp'];
  static const fileExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'zip',
  ];
  final String name;
  final Uint8List bytes;
  final bool isImage;
  String get extension => name.split('.').last.toLowerCase();
  String get mimeType => switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'bmp' => 'image/bmp',
    'pdf' => 'application/pdf',
    'txt' => 'text/plain',
    'zip' => 'application/zip',
    _ => 'application/octet-stream',
  };
  static void validateSize(int size) {
    if (size <= 0) throw const FormatException('附件为空，请重新选择');
    if (size > maxBytes) throw const FormatException('附件不能超过10MB');
  }

  static void validateName(String name, bool image) {
    if (name.isEmpty ||
        name.length > 180 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
      throw const FormatException('附件文件名无效或过长，请重命名后选择');
    }
    final extension = name.split('.').last.toLowerCase();
    if (!name.contains('.') ||
        !(image ? imageExtensions : fileExtensions).contains(extension)) {
      throw FormatException(
        image ? '请选择 JPG、PNG、GIF 或 BMP 图片' : '请选择 PDF、Office、TXT 或 ZIP 文件',
      );
    }
  }

  static bool _hasImageHeader(String extension, Uint8List b) =>
      switch (extension) {
        'jpg' ||
        'jpeg' => b.length >= 3 && b[0] == 255 && b[1] == 216 && b[2] == 255,
        'png' =>
          b.length >= 8 && b.take(8).join(',') == '137,80,78,71,13,10,26,10',
        'gif' =>
          b.length >= 6 &&
              ['GIF87a', 'GIF89a'].contains(String.fromCharCodes(b.take(6))),
        'bmp' => b.length >= 2 && b[0] == 66 && b[1] == 77,
        _ => false,
      };
}

class ChatUploadedAttachment {
  const ChatUploadedAttachment({
    required this.name,
    required this.url,
    required this.isImage,
  });
  final String name, url;
  final bool isImage;
}

class ChatAttachmentPicker {
  ChatAttachmentPicker({Future<PlatformFile?> Function(bool image)? pickFile})
    : _pickFile = pickFile ?? _pickNative;
  final Future<PlatformFile?> Function(bool image) _pickFile;
  static Future<PlatformFile?> _pickNative(bool image) => FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: image
        ? ChatPickedAttachment.imageExtensions
        : ChatPickedAttachment.fileExtensions,
  );
  Future<ChatPickedAttachment?> pick({required bool image}) async {
    try {
      final file = await _pickFile(image);
      if (file == null) return null;
      ChatPickedAttachment.validateName(file.name, image);
      final reported = file.lengthSync() ?? await file.length();
      if (reported != null) ChatPickedAttachment.validateSize(reported);
      final buffer = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        if (buffer.length + chunk.length > ChatPickedAttachment.maxBytes) {
          throw const FormatException('附件不能超过10MB');
        }
        buffer.add(chunk);
      }
      final bytes = buffer.takeBytes();
      if (reported != null && reported != bytes.length) {
        throw const FormatException('附件读取不完整，请重新选择');
      }
      return ChatPickedAttachment(
        name: file.name,
        bytes: bytes,
        isImage: image,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('无法读取所选附件，请重新选择');
    }
  }
}
