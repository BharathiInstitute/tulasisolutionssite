import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Thin wrapper around Firebase Cloud Functions callables.
class CloudFunctionService {
  // Firebase project configuration
  static const _region = 'asia-south1';
  static const _projectId = 'newproject1234561'; // Your Firebase project ID

  /// Base URL for direct HTTP calls
  String _functionUrl(String name) =>
      'https://$_region-$_projectId.cloudfunctions.net/$name';

  /// Calls a Cloud Function with automatic retry on transient failures.
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic>? data,
    int maxRetries = 2,
  ]) async {
    int attempt = 0;
    while (true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        final token = await user?.getIdToken();

        final headers = <String, String>{'Content-Type': 'application/json'};
        if (token != null) headers['Authorization'] = 'Bearer $token';

        final response = await http.post(
          Uri.parse(_functionUrl(name)),
          headers: headers,
          body: jsonEncode({'data': data ?? {}}),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded.containsKey('result')) {
            final result = decoded['result'];
            if (result is Map) return Map<String, dynamic>.from(result);
            return <String, dynamic>{'result': result};
          }
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
          return <String, dynamic>{'result': decoded};
        }

        String errorMsg = 'HTTP ${response.statusCode}';
        try {
          final errBody = jsonDecode(response.body);
          if (errBody is Map) {
            errorMsg =
                (errBody['error'] is Map
                        ? errBody['error']['message']
                        : errBody['error'])
                    ?.toString() ??
                errorMsg;
          }
        } catch (_) {}
        throw Exception(errorMsg);
      } catch (e) {
        if (attempt >= maxRetries) rethrow;
        attempt++;
        debugPrint('CF $name attempt $attempt failed: $e, retrying...');
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }
}
