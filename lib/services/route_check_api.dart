import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import '../models/gps_location_data.dart';

class RouteCheckApi {
  final http.Client _client;
  final String _baseUrl;

  RouteCheckApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? Environment.effectiveBaseUrl();

  /// Sends a GPSLocationData record to the backend route check endpoint.
  /// The endpoint path still includes trackerId; id inside JSON is separate.
  Future<http.Response> sendLocationData({
    required String trackerId,
    required GPSLocationData data,
  }) {
    final uri = Uri.parse('$_baseUrl/api/route/check/$trackerId');
    return _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(data.toJson()),
    );
  }
}
