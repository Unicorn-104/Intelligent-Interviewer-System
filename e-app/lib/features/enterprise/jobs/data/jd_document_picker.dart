import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// A validated, bounded document ready for a multipart request.
class JdPickedDocument {
  JdPickedDocument._(this.name, this.extension, Uint8List bytes)
    : bytes = bytes.asUnmodifiableView();

  factory JdPickedDocument({required String name, required Uint8List bytes}) {
    final filename = name.split(RegExp(r'[/\\]')).last;
    final extension = _documentExtension(filename);
    _checkDocumentSize(bytes.length);
    return JdPickedDocument._(filename, extension, Uint8List.fromList(bytes));
  }

  static const maxBytes = 10 * 1024 * 1024;

  final String name;
  final String extension;
  final Uint8List bytes;

  int get size => bytes.length;

  String get mimeType => extension == 'pdf'
      ? 'application/pdf'
      : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
}

/// Keeps the plugin and file I/O outside the publishing page.
class JdDocumentPicker {
  JdDocumentPicker({Future<PlatformFile?> Function()? pickFile})
    : _pickFile = pickFile ?? _pickNativeFile;

  final Future<PlatformFile?> Function() _pickFile;

  static Future<PlatformFile?> _pickNativeFile() => FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'docx'],
  );

  Future<JdPickedDocument?> pick() async {
    try {
      final file = await _pickFile();
      if (file == null) return null;
      _documentExtension(file.name);
      final reportedSize = file.lengthSync() ?? await file.length();
      if (reportedSize != null) _checkDocumentSize(reportedSize);

      final buffer = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        if (buffer.length + chunk.length > JdPickedDocument.maxBytes) {
          throw const JdDocumentSelectionException('JD 文档不能超过10MB');
        }
        buffer.add(chunk);
      }
      final bytes = buffer.takeBytes();
      _checkDocumentSize(bytes.length);
      if (reportedSize != null && reportedSize != bytes.length) {
        throw const JdDocumentSelectionException('文件读取不完整，请重新选择文档');
      }
      return JdPickedDocument(name: file.name, bytes: bytes);
    } on JdDocumentSelectionException {
      rethrow;
    } catch (_) {
      throw const JdDocumentSelectionException('无法读取所选文件，请重新选择文档');
    }
  }
}

class JdDocumentSelectionException implements Exception {
  const JdDocumentSelectionException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _documentExtension(String name) {
  if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
    throw const JdDocumentSelectionException('文档文件名无效，请重新选择');
  }
  final extension = name.split('.').last.toLowerCase();
  if (!name.contains('.') || !const ['pdf', 'docx'].contains(extension)) {
    throw const JdDocumentSelectionException('仅支持PDF或DOCX文档');
  }
  return extension;
}

void _checkDocumentSize(int size) {
  if (size <= 0) {
    throw const JdDocumentSelectionException('JD 文档为空，请选择有内容的文件');
  }
  if (size > JdPickedDocument.maxBytes) {
    throw const JdDocumentSelectionException('JD 文档不能超过10MB');
  }
}
