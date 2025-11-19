import 'package:flutter/foundation.dart';
import 'dev_config.dart'; // Local-only development config

/// Environment configuration for selecting the backend base URL.
/// Uses release mode to decide between production and localhost.
class Environment {
  static const bool isProduction = kReleaseMode;

  // Production URL is always fixed.
  static const String _productionBaseUrl = 'https://www.mulo.dk';
  
  static String get _devBaseUrl {
    if (kIsWeb) {
      // Running in a browser, connects to localhost.
      return 'http://localhost:8080';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // For a physical device, use the IP from the local dev_config.dart file.
      // This allows each developer to have their own IP without version control conflicts.
      return 'http://$physicalDeviceIp:8080';
      
      // For the standard Android emulator, you would use '10.0.2.2'.
      // return 'http://10.0.2.2:8080';
    } else {
      // Fallback for other platforms (iOS, desktop, etc.)
      return 'http://localhost:8080';
    }
  }

  static String get baseUrl => isProduction ? _productionBaseUrl : _devBaseUrl;

  /// Optional override at runtime if needed.
  static String? _override;
  static void overrideBaseUrl(String url) => _override = url;
  static String effectiveBaseUrl() => _override ?? baseUrl;
}
