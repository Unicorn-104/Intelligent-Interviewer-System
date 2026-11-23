import '../core/network/enterprise_api_client.dart';

Future<Map<String, dynamic>> getIntegrationSettings() async {
  final response = await EnterpriseApiClient().get(
    '/system/enterprise/settings/integrations',
  );
  final data = response['data'];
  return data is Map ? Map<String, dynamic>.from(data) : const {};
}

Future<Map<String, dynamic>> updateIntegrationSettings({
  bool? forceRegenerate,
  String? screeningAnalysisMode,
}) async {
  final body = <String, Object?>{};
  if (forceRegenerate != null) body['forceRegenerate'] = forceRegenerate;
  if (screeningAnalysisMode != null) {
    body['screeningAnalysisMode'] = screeningAnalysisMode;
  }
  final response = await EnterpriseApiClient().put(
    '/system/enterprise/settings/integrations',
    body: body,
  );
  final data = response['data'];
  return data is Map ? Map<String, dynamic>.from(data) : const {};
}

Future<bool> getExamAnalysisForceRegenerate() async {
  final data = await getIntegrationSettings();
  return data['forceRegenerate'] == true;
}

Future<bool> updateExamAnalysisForceRegenerate(bool value) async {
  final data = await updateIntegrationSettings(forceRegenerate: value);
  return data['forceRegenerate'] == true;
}
