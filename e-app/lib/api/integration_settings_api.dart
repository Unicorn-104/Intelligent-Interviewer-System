import '../core/network/enterprise_api_client.dart';

Future<bool> getExamAnalysisForceRegenerate() async {
  final response = await EnterpriseApiClient().get(
    '/system/enterprise/settings/integrations',
  );
  final data = response['data'];
  return data is Map && data['forceRegenerate'] == true;
}

Future<bool> updateExamAnalysisForceRegenerate(bool value) async {
  final response = await EnterpriseApiClient().put(
    '/system/enterprise/settings/integrations',
    body: {'forceRegenerate': value},
  );
  final data = response['data'];
  return data is Map && data['forceRegenerate'] == true;
}
