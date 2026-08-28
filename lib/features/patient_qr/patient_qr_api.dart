import '../../core/api/api_client.dart';

class PatientQrApi {
  /// Validate the QR token and return session/patient data
  static Future<Map<String, dynamic>> validateQr(String token) async {
    final response = await ApiClient.post(
      '/public/qr/validate',
      body: {'token': token},
    );

    if (response is! Map) {
      throw ApiException(500, 'Unexpected QR validation response');
    }

    return Map<String, dynamic>.from(response);
  }

  /// Fetch content/announcements for a specific ward
  static Future<List<dynamic>> fetchContents(int locationId) async {
    final res = await ApiClient.get('/public/contents?locationid=$locationId');
    return res as List<dynamic>;
  }

  /// Submit a help request
  static Future<void> sendHelpRequest(String sessionId, String type, {String? note}) async {
    final Map<String, dynamic> body = {
      'bed_qr_session_id': sessionId,
      'type': type,
    };
    if (note != null && note.isNotEmpty) {
      body['note'] = note;
    }
    await ApiClient.post('/public/help-requests', body: body);
  }
}
