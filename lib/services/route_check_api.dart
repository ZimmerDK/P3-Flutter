import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import '../models/gps_location_data.dart';
import 'auth_service.dart';
import 'offline_queue_service.dart';

class RouteCheckApi {
  final http.Client _client;
  final String _baseUrl;
  final AuthService _authService = AuthService();
    final OfflineQueueService _queueService = OfflineQueueService();

  RouteCheckApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? Environment.effectiveBaseUrl();

  /// Sends a GPSLocationData record to the backend route check endpoint.
  /// The endpoint path still includes trackerId; id inside JSON is separate.
  Future<http.Response> sendLocationData({
    required String trackerId,
    required GPSLocationData data,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/GPSTracker/phone/$trackerId');
    final token = await _authService.getToken();

    if (token == null) {
      return http.Response('Unauthorized: No token found', 401);
    }

    try {
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data.toJson()),
      );

      // On success try to flush any queued locations as well.
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await flushQueued(trackerId: trackerId);
      } else if (response.statusCode >= 500 || response.statusCode == 0) {
        // Special case: backend wrapped a 404 NOT_FOUND into a 500 with a clear message.
        final lowerBody = response.body.toLowerCase();
        final looksLikeTrackerNotFound = lowerBody.contains('404') &&
            lowerBody.contains('tracker id') &&
            lowerBody.contains('not found');

        if (looksLikeTrackerNotFound) {
            // Wrong tracker ID – do NOT queue.
            // You may want to log this clearly for debugging:
            // debugPrint('Not queuing point: tracker not found: $body');
        } else {
            // Real server error / offline – queue for retry.
            await _queueService.enqueue(data);
        }
      } else {
        // 4xx or other client-side errors are not queued.
      }

      return response;
    } catch (e) {
      // Network/other failure; enqueue for later retry.
      await _queueService.enqueue(data);
      return http.Response('Offline or error: $e', 503);
    }
  }

  /// Attempts to send all queued location records.
  Future<void> flushQueued({required String trackerId}) async {
    final token = await _authService.getToken();
    if (token == null) {
      return;
    }

    final uri = Uri.parse('$_baseUrl/api/GPSTracker/phone/$trackerId');
    final queued = await _queueService.getAll();

    for (var i = 0; i < queued.length; i++) {
      final data = queued[i];
      try {
        final response = await _client.post(
          uri,
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(data.toJson()),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          await _queueService.removeAt(0); // always remove head
        } else {
          // If a send fails, stop to avoid hammering the server.
          break;
        }
      } catch (_) {
        // Network error; stop and keep remaining queued.
        break;
      }
    }
  }
}
