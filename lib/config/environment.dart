import 'package:flutter/foundation.dart';

/// Environment configuration for selecting the backend base URL.
/// Uses release mode to decide between production and localhost.
class Environment {
  static const bool isProduction = kReleaseMode;

  // Change the dev port if your backend runs on another port.
  static const String _productionBaseUrl = 'https://www.mulo.dk';
  static const String _devBaseUrl = 'http://localhost:8080';

  static String get baseUrl => isProduction ? _productionBaseUrl : _devBaseUrl;

  /// Optional override at runtime if needed.
  static String? _override;
  static void overrideBaseUrl(String url) => _override = url;
  static String effectiveBaseUrl() => _override ?? baseUrl;
}
