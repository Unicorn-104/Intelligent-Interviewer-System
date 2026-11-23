import '../core/network/enterprise_api_client.dart';

Future<Map<String, dynamic>> getSendCenterContext({
  required int candidateId,
  required int positionId,
}) async {
  final response = await EnterpriseApiClient().get(
    '/enterprise/send/context',
    query: {'candidateId': candidateId, 'positionId': positionId},
  );
  return Map<String, dynamic>.from(response['data'] as Map? ?? const {});
}
