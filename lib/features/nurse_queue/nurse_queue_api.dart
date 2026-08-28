import '../../core/api/api_client.dart';

/// Status constants for help requests
class HelpRequestStatus {
  static const String newRequest = 'NEW';
  static const String acknowledged = 'ACKNOWLEDGED';
  static const String inProgress = 'IN_PROGRESS';
  static const String resolved = 'RESOLVED';
  static const String cancelled = 'CANCELLED';
}

/// Action paths for status transitions
class HelpRequestAction {
  static const String acknowledge = 'acknowledge';
  static const String inProgress = 'in-progress';
  static const String resolve = 'resolve';
  static const String cancel = 'cancel';
}

class NurseQueueApi {
  /// Fetch all wards
  static Future<List<Map<String, dynamic>>> fetchWards() async {
    final data = await ApiClient.get('/admin/wards');
    return (data as List<dynamic>)
        .map((w) => Map<String, dynamic>.from(w as Map))
        .toList();
  }

  /// Fetch help requests for a given ward, optionally filtered by status
  static Future<List<Map<String, dynamic>>> fetchHelpRequests(
    int locationId, {
    String? status,
  }) async {
    final query = status != null ? '?status=$status' : '';
    final data = await ApiClient.get(
      '/admin/wards/$locationId/help-requests$query',
    );
    return (data as List<dynamic>)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  /// Fetch a single help request by ID
  static Future<Map<String, dynamic>> getHelpRequestById(String id) async {
    final data = await ApiClient.get('/admin/help-requests/$id');
    return Map<String, dynamic>.from(data as Map);
  }

  /// Update the status of a help request.
  /// [action] must be one of: acknowledge, in-progress, resolve, cancel
  static Future<Map<String, dynamic>> updateRequestStatus(
    String id,
    String action,
  ) async {
    final data = await ApiClient.patch('/admin/help-requests/$id/$action', body: {});
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }
}
