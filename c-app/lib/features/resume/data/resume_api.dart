import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/app_resume.dart';

class ResumeApi {
  const ResumeApi(this._client);
  final ApiClient _client;

  Future<List<AppResume>> list(String token) async {
    final json = await _client.get('/app/resumes', token: token);
    final data = json['data'];
    if (data is! List) throw const ApiException('简历列表响应格式不正确');
    return data
        .whereType<Map>()
        .map(
          (item) => AppResume.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  Future<AppResume> detail(String token, int resumeId) async {
    final json = await _client.get('/app/resumes/$resumeId', token: token);
    return _resume(json);
  }

  Future<AppResume> save(String token, AppResume resume) async {
    if (resume.localPdfPath != null) {
      final json = await _client.postFile(
        resume.resumeId == null
            ? '/app/resumes/import-pdf'
            : '/app/resumes/${resume.resumeId}/import-pdf',
        token: token,
        filePath: resume.localPdfPath!,
        fieldName: 'file',
        jsonBody: resume.toJson(),
      );
      return _resume(json);
    }
    final json = resume.resumeId == null
        ? await _client.post(
            '/app/resumes',
            token: token,
            body: resume.toJson(),
          )
        : await _client.put(
            '/app/resumes/${resume.resumeId}',
            token: token,
            body: resume.toJson(),
          );
    return _resume(json);
  }

  Future<AppResume> parsePdf(String token, String filePath) async {
    final json = await _client.postFile(
      '/app/resumes/parse-pdf',
      token: token,
      filePath: filePath,
      fieldName: 'file',
    );
    final resume = _resume(json);
    if (resume.structureMethod != 'AI') {
      throw const ApiException('简历导入未完成，请重试');
    }
    if (resume.educations.isEmpty &&
        resume.works.isEmpty &&
        resume.projects.isEmpty &&
        resume.skills.isEmpty) {
      throw const ApiException('暂未识别到简历经历，请重试或选择更清晰的 PDF');
    }
    return resume;
  }

  AppResume _resume(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map) throw const ApiException('简历响应格式不正确');
    return AppResume.fromJson(
      data.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}
