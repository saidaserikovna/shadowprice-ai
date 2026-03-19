import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _compileTimeApiBaseUrl = String.fromEnvironment(
    'SHADOWPRICE_API_BASE_URL',
  );

  static String? get compileTimeApiBaseUrl {
    final value = _compileTimeApiBaseUrl.trim();
    if (value.isEmpty) {
      return null;
    }
    return normalizeBaseUrl(value);
  }

  static String get defaultApiBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    return 'http://10.0.2.2:8000';
  }

  static String get apiBaseUrl {
    return compileTimeApiBaseUrl ?? defaultApiBaseUrl;
  }

  static String normalizeBaseUrl(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) {
      return normalized;
    }

    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'http://$normalized';
    }

    return normalized.replaceFirst(RegExp(r'/+$'), '');
  }
}
