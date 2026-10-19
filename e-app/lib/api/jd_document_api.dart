import 'package:dio/dio.dart';

import '../core/network/api_exception.dart';
import '../core/network/enterprise_api_client.dart';
import '../features/enterprise/jobs/data/jd_document_picker.dart';
import '../features/enterprise/jobs/models/jd_import_draft.dart';

/// Parses a document into a reviewable draft. Never creates or publishes a job.
Future<JdImportDraft> parseJdDocument(
  JdPickedDocument document, {
  EnterpriseApiClient? client,
  CancelToken? cancelToken,
  ProgressCallback? onSendProgress,
}) async {
  final response = await (client ?? EnterpriseApiClient()).uploadFile(
    '/enterprise/jd/parse-document',
    filename: document.name,
    bytes: document.bytes,
    fieldName: 'file',
    mimeType: document.mimeType,
    cancelToken: cancelToken,
    onSendProgress: onSendProgress,
  );
  final data = response['data'];
  if (data is! Map<String, dynamic>) {
    throw const ApiException('解析服务未返回有效的 JD 草稿，请重试');
  }
  try {
    return JdImportDraft.fromJson(data);
  } on FormatException catch (error) {
    throw ApiException('JD 草稿格式不正确：${error.message}');
  }
}
