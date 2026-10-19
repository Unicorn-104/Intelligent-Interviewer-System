import 'dart:typed_data';

import 'package:enterprise_recruiter/features/enterprise/jobs/data/jd_document_picker.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/models/jd_import_draft.dart';
import 'package:file_picker/file_picker.dart';

Map<String, dynamic> jdDraftJson([Map<String, dynamic> overrides = const {}]) =>
    {
      'title': '合成移动端工程师',
      'dept': '测试研发部',
      'city': '上海',
      'salaryMin': 15000.50,
      'salaryMax': 25000,
      'experience': '3-5年',
      'education': 3,
      'jobType': 1,
      'responsibilities': ['开发移动端功能', '编写自动化测试'],
      'requirements': ['熟悉 Dart'],
      'skills': [
        {'name': 'Dart', 'required': 1},
        {'name': 'Flutter', 'required': null},
      ],
      'summary': '维护合成测试应用',
      'softRequirements': ['团队协作'],
      'warnings': ['  OCR 提示：请核对薪资\n并检查原文  '],
      ...overrides,
    };

JdImportDraft jdDraft([Map<String, dynamic> overrides = const {}]) =>
    JdImportDraft.fromJson(jdDraftJson(overrides));

JdPickedDocument jdDocument([String name = 'synthetic-jd.pdf']) =>
    JdPickedDocument(
      name: name,
      bytes: Uint8List.fromList([37, 80, 68, 70, 45]),
    );

/// In-memory provider; no filesystem access or real personal documents.
final class SyntheticJdPlatformFile extends PlatformFile {
  SyntheticJdPlatformFile({
    this.name = 'synthetic.pdf',
    Uint8List? bytes,
    this.reportedSize,
    this.unknownSize = false,
    this.failRead = false,
    this.failLength = false,
    this.streamSource,
  }) : bytes = bytes ?? Uint8List.fromList([1, 2, 3]);

  @override
  final String name;
  final Uint8List bytes;
  final int? reportedSize;
  final bool unknownSize;
  final bool failRead;
  final bool failLength;
  final Stream<Uint8List> Function()? streamSource;
  int reads = 0;

  @override
  Uri get uri => Uri.parse('memory://synthetic/${Uri.encodeComponent(name)}');

  @override
  Never get xFile => throw UnsupportedError('Not needed by the adapter');

  @override
  int? lengthSync() =>
      unknownSize || failLength ? null : reportedSize ?? bytes.length;

  @override
  Future<int?> length() async {
    if (failLength) {
      throw StateError('Synthetic metadata read failed');
    }
    return unknownSize ? null : reportedSize ?? bytes.length;
  }

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Stream<Uint8List> readAsByteStream() async* {
    reads++;
    if (failRead) {
      throw StateError('Synthetic stream read failed');
    }
    if (streamSource != null) {
      yield* streamSource!();
    } else {
      yield bytes;
    }
  }
}
