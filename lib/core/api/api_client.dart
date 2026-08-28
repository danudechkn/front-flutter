import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

/// Custom exception for API errors to easily handle status codes and messages
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'Error $statusCode: $message';
}

/// Central API Client for handling all HTTP requests
class ApiClient {
  // Update this to your actual backend URL.
  // Using LAN IP so that mobile devices on the same Wi-Fi can connect.
  static const String baseUrl = 'http://172.16.46.47:3002/api';
  
  // Default timeout for all API requests
  static const Duration timeout = Duration(seconds: 15);

  // Access token for authenticated requests
  static String? accessToken;

  /// Helper to get headers for requests
  static Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    
    return headers;
  }

  /// GET Request
  static Future<dynamic> get(String endpoint) async {
    return _sendRequest(() async {
      return await http
          .get(Uri.parse('$baseUrl$endpoint'), headers: _getHeaders())
          .timeout(timeout);
    });
  }

  /// POST Request
  static Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    return _sendRequest(() async {
      return await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: _getHeaders(),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(timeout);
    });
  }

  /// PUT Request
  static Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    return _sendRequest(() async {
      return await http
          .put(
            Uri.parse('$baseUrl$endpoint'),
            headers: _getHeaders(),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(timeout);
    });
  }

  /// DELETE Request
  static Future<dynamic> delete(String endpoint) async {
    return _sendRequest(() async {
      return await http
          .delete(Uri.parse('$baseUrl$endpoint'), headers: _getHeaders())
          .timeout(timeout);
    });
  }

  /// PATCH Request
  static Future<dynamic> patch(String endpoint, {Map<String, dynamic>? body}) async {
    return _sendRequest(() async {
      return await http
          .patch(
            Uri.parse('$baseUrl$endpoint'),
            headers: _getHeaders(),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(timeout);
    });
  }

  /// Internal wrapper to handle timeouts, response processing, and errors
  static Future<dynamic> _sendRequest(Future<http.Response> Function() requestFunc) async {
    try {
      final response = await requestFunc();
      return _processResponse(response);
    } on TimeoutException {
      throw ApiException(408, 'Request timed out. Please check your connection.');
    } catch (e) {
      if (e is ApiException) rethrow; // Pass custom exceptions up
      throw ApiException(500, 'Network error: ${e.toString()}');
    }
  }

  /// Process the raw HTTP response
  static dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return json.decode(response.body);
      } catch (e) {
        return response.body; // Return as plain string if not JSON
      }
    } else {
      // Handle errors based on status code
      String errorMessage = 'Unknown error occurred';
      try {
        final errorData = json.decode(response.body);
        errorMessage = errorData['message'] ?? response.body;
      } catch (e) {
        errorMessage = response.body.isNotEmpty ? response.body : response.reasonPhrase ?? 'Error';
      }
      throw ApiException(response.statusCode, errorMessage);
    }
  }
}
