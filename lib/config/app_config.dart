import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _apiBaseUrlOverride = String.fromEnvironment('SHADOWPRICE_API_BASE_URL');

  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride;
    }

    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    return 'http://10.0.2.2:8000';
  }
}
