import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import '../models/gps_location_data.dart';
import 'auth_service.dart';

class RouteCheckApi {
  final http.Client _client;
  final String _baseUrl;
  final AuthService _authService = AuthService();

  RouteCheckApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? Environment.effectiveBaseUrl();

  /// Sends a GPSLocationData record to the backend route check endpoint.
  /// The endpoint path still includes trackerId; id inside JSON is separate.
  Future<http.Response> sendLocationData({
    required String trackerId,
    required GPSLocationData data,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/route/$trackerId');
    final token = await _authService.getToken();

    if (token == null) {
      return http.Response('Unauthorized: No token found', 401);
    }

    return _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data.toJson()),
    );
  }
}
