import 'dart:convert';
import 'package:flutter/foundation.dart'; // Import for debugPrint
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/environment.dart';

class AuthService {
  // 1. Private constructor
  AuthService._internal();

  // 2. Static private instance
  static final AuthService _instance = AuthService._internal();

  // 3. Factory constructor
  factory AuthService() {
    return _instance;
  }

  final _storage = const FlutterSecureStorage();
  final String _tokenKey = 'auth_token';

  final String _loginUrl = '${Environment.effectiveBaseUrl()}/api/auth/authenticate';

  Future<bool> login(String email, String password) async {
    try {
      debugPrint('Attempting to login with email: $email');
      final response = await http.post(
        Uri.parse(_loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        debugPrint('Login response 200 OK.');
        final responseBody = json.decode(response.body);

        if (responseBody != null && responseBody['token'] != null) {
          final token = responseBody['token'];
          debugPrint('--- TOKEN RECEIVED ---');
          debugPrint(token);
          debugPrint('----------------------');
          await _saveToken(token);
          debugPrint('Token successfully saved.');
          return true;
        } else {
          debugPrint('Login successful, but no token found in response body.');
          return false;
        }
      } else {
        debugPrint('Login failed with status: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('An exception occurred during login: $e');
      return false;
    }
  }

  Future<void> _saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    final token = await _storage.read(key: _tokenKey);
    debugPrint(token != null ? 'Token retrieved from storage.' : 'No token found in storage.');
    return token;
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    debugPrint('Token deleted from storage.');
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    // You might want to add token validation logic here
    return token != null;
  }
}
