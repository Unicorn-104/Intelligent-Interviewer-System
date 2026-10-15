import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/features/resume/data/resume_api.dart';
import 'package:intelligent_interviewer/features/resume/domain/app_resume.dart';

void main() {
  test(
    'sends corrected resume JSON and unchanged PDF in one multipart request',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'resume-upload-test-',
      );
      final file = File('${directory.path}/简历.pdf');
      final bytes = utf8.encode(
        '%PDF-1.7\nSynthetic binary fixture\n\u0000\u0001',
      );
      await file.writeAsBytes(bytes);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = ApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
      final served = server.first.then((request) async {
        expect(request.uri.path, '/app/resumes/import-pdf');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer test-session',
        );
        final received = await request.fold<List<int>>(
          [],
          (data, chunk) => data..addAll(chunk),
        );
        expect(received.length, request.contentLength);
        final boundary = request.headers.contentType!.parameters['boundary']!;
        final parts = utf8.decode(received).split('--$boundary');
        final resumePart = parts.singleWhere(
          (part) => part.contains('name="resume"'),
        );
        expect(
          resumePart,
          contains('Content-Type: application/json; charset=utf-8'),
        );
        final json =
            jsonDecode(resumePart.split('\r\n\r\n').last.trim())
                as Map<String, dynamic>;
        expect(json['resumeName'], '已核对的简历');
        expect(json['jobDirection'], 'Java 开发');
        expect(json.containsKey('localPdfPath'), isFalse);
        expect(json.containsKey('filePath'), isFalse);
        final filePart = parts.singleWhere(
          (part) => part.contains('name="file"'),
        );
        expect(filePart, contains('filename="简历.pdf"'));
        expect(filePart, contains('Content-Type: application/pdf'));
        expect(
          utf8.encode(
            filePart.split('\r\n\r\n').last.substring(0, bytes.length),
          ),
          bytes,
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'code': 200,
            'data': {
              'resumeId': 7,
              'resumeName': '已核对的简历',
              'fileName': '简历.pdf',
              'fileSize': bytes.length,
              'pdfUrl': '/app/resumes/7/pdf',
            },
          }),
        );
        await request.response.close();
      });
      try {
        final saved = await ResumeApi(client).save(
          'test-session',
          AppResume(
            resumeName: '已核对的简历',
            jobDirection: 'Java 开发',
            localPdfPath: file.path,
          ),
        );
        await served;
        expect(saved.resumeId, 7);
        expect(saved.pdfUrl, '/app/resumes/7/pdf');
        expect(saved.localPdfPath, isNull);
      } finally {
        client.close();
        await server.close(force: true);
        await directory.delete(recursive: true);
      }
    },
  );
}
