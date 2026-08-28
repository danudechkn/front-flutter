import 'dart:async';

/// Native fallback. The deployed patient page is Flutter Web, where SSE is
/// enabled by the conditional web implementation below.
class HelpRequestRealtime {
  static Stream<Map<String, dynamic>> watch(String sessionId) =>
      const Stream<Map<String, dynamic>>.empty();

  static Stream<Map<String, dynamic>> watchAdmin() =>
      const Stream<Map<String, dynamic>>.empty();
}
