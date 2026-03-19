import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/analysis_models.dart';
import '../models/chat_models.dart';
import 'local_url_analysis_service.dart';

class ShadowPriceApiException implements Exception {
  const ShadowPriceApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ShadowPriceApiService extends ChangeNotifier {
  static const _apiBaseUrlPrefsKey = 'shadowprice_api_base_url';

  ShadowPriceApiService({http.Client? client})
      : this._(client ?? http.Client());

  ShadowPriceApiService._(this._client)
      : _localUrlAnalysisService = LocalUrlAnalysisService(client: _client);

  final http.Client _client;
  final LocalUrlAnalysisService _localUrlAnalysisService;

  PriceAnalysis? _latestAnalysis;
  String? _cachedApiBaseUrl;
  bool _didLoadApiBaseUrl = false;

  PriceAnalysis? get latestAnalysis => _latestAnalysis;

  Future<PriceAnalysis> analyze(String query) async {
    final apiBaseUrl = await _resolveApiBaseUrl();
    try {
      final uri = Uri.parse('$apiBaseUrl/api/v1/analyze');
      final response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'query': query}),
          )
          .timeout(
            const Duration(seconds: 18),
            onTimeout: () => throw const ShadowPriceApiException(
              'The price check took too long. Paste a direct product page from Kaspi, Amazon, eBay, AliExpress, Wildberries, or Ozon.',
            ),
          );

      final json = _decodeJson(response);
      if (response.statusCode >= 400) {
        throw ShadowPriceApiException(_extractError(json));
      }

      final analysis = PriceAnalysis.fromJson(json);
      _latestAnalysis = analysis;
      notifyListeners();
      return analysis;
    } catch (error) {
      final fallback = await _localUrlAnalysisService.analyze(query);
      if (fallback != null) {
        _latestAnalysis = fallback;
        notifyListeners();
        return fallback;
      }

      throw _mapAnalyzeError(error, apiBaseUrl);
    }
  }

  Future<ChatReply> askAssistant({
    required String question,
    List<ChatMessageModel> history = const [],
    PriceAnalysis? analysis,
  }) async {
    final apiBaseUrl = await _resolveApiBaseUrl();
    final uri = Uri.parse('$apiBaseUrl/api/v1/chat');
    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'question': question,
            'analysis': (analysis ?? _latestAnalysis)?.toJson(),
            'history': history.map((message) => message.toJson()).toList(),
          }),
        )
        .timeout(
          const Duration(seconds: 18),
          onTimeout: () => throw const ShadowPriceApiException(
            'The ShadowPrice assistant took too long to answer. Please try again.',
          ),
        );

    final json = _decodeJson(response);
    if (response.statusCode >= 400) {
      throw ShadowPriceApiException(_extractError(json));
    }

    return ChatReply.fromJson(json);
  }

  String get defaultApiBaseUrl => AppConfig.defaultApiBaseUrl;

  Future<String> getConfiguredApiBaseUrl() async {
    return _resolveApiBaseUrl();
  }

  Future<void> setApiBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = AppConfig.normalizeBaseUrl(value);
    if (normalized.isEmpty) {
      await prefs.remove(_apiBaseUrlPrefsKey);
      _cachedApiBaseUrl = null;
    } else {
      await prefs.setString(_apiBaseUrlPrefsKey, normalized);
      _cachedApiBaseUrl = normalized;
    }
    _didLoadApiBaseUrl = true;
    notifyListeners();
  }

  Future<void> resetApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiBaseUrlPrefsKey);
    _cachedApiBaseUrl = null;
    _didLoadApiBaseUrl = true;
    notifyListeners();
  }

  Future<bool> pingBackend([String? rawBaseUrl]) async {
    final baseUrl = rawBaseUrl == null || rawBaseUrl.trim().isEmpty
        ? await _resolveApiBaseUrl()
        : AppConfig.normalizeBaseUrl(rawBaseUrl);
    final uri = Uri.parse('$baseUrl/healthz');
    try {
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 6));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _decodeJson(http.Response response) {
    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{};
  }

  String _extractError(Map<String, dynamic> json) {
    final detail = json['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    return 'The ShadowPrice backend request failed.';
  }

  Future<String> _resolveApiBaseUrl() async {
    if (_didLoadApiBaseUrl) {
      return _cachedApiBaseUrl ?? AppConfig.apiBaseUrl;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getString(_apiBaseUrlPrefsKey);
    if (savedValue != null && savedValue.trim().isNotEmpty) {
      _cachedApiBaseUrl = AppConfig.normalizeBaseUrl(savedValue);
    } else {
      _cachedApiBaseUrl = AppConfig.compileTimeApiBaseUrl;
    }
    _didLoadApiBaseUrl = true;
    return _cachedApiBaseUrl ?? AppConfig.defaultApiBaseUrl;
  }

  ShadowPriceApiException _mapAnalyzeError(Object error, String apiBaseUrl) {
    if (error is ShadowPriceApiException) {
      return error;
    }
    if (error is TimeoutException) {
      return const ShadowPriceApiException(
        'The price check took too long. Paste a direct product page from Kaspi, Amazon, eBay, AliExpress, Wildberries, or Ozon.',
      );
    }
    return ShadowPriceApiException(
      'ShadowPrice could not connect to $apiBaseUrl. On the Android emulator use 10.0.2.2:8000. On a real phone, open Settings and set Backend URL to your laptop Wi-Fi IP, then try the product link again.',
    );
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
