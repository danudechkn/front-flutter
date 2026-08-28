import 'dart:async';
import 'dart:convert';
import 'dart:html';

import '../../core/api/api_client.dart';

/// Browser EventSource connection for immediate request-status updates.
class HelpRequestRealtime {
  static Stream<Map<String, dynamic>> watch(String sessionId) {
    late final EventSource source;
    late final StreamController<Map<String, dynamic>> controller;

    controller = StreamController<Map<String, dynamic>>(
      onListen: () {
        final uri = '${ApiClient.baseUrl}/public/help-requests/stream'
            '?bed_qr_session_id=${Uri.encodeQueryComponent(sessionId)}';
        source = EventSource(uri);
        source.onMessage.listen((event) {
          try {
            final decoded = jsonDecode(event.data as String);
            if (decoded is Map) {
              controller.add(Map<String, dynamic>.from(decoded));
            }
          } catch (_) {
            // Ignore malformed keep-alive data and keep the connection open.
          }
        });
      },
      onCancel: () => source.close(),
    );

    return controller.stream;
  }

  static Stream<Map<String, dynamic>> watchAdmin() {
    late final EventSource source;
    late final StreamController<Map<String, dynamic>> controller;

    controller = StreamController<Map<String, dynamic>>(
      onListen: () {
        source = EventSource('${ApiClient.baseUrl}/admin/help-requests/stream');
        source.onMessage.listen((event) {
          try {
            final decoded = jsonDecode(event.data as String);
            if (decoded is Map) controller.add(Map<String, dynamic>.from(decoded));
          } catch (_) {}
        });
      },
      onCancel: () => source.close(),
    );
    return controller.stream;
  }
}
