import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/analysis_models.dart';
import '../models/chat_models.dart';

class ShadowPriceApiException implements Exception {
  const ShadowPriceApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ShadowPriceApiService extends ChangeNotifier {
  ShadowPriceApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  PriceAnalysis? _latestAnalysis;

  PriceAnalysis? get latestAnalysis => _latestAnalysis;

  Future<PriceAnalysis> analyze(String query) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/v1/analyze');
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
  }

  Future<ChatReply> askAssistant({
    required String question,
    List<ChatMessageModel> history = const [],
    PriceAnalysis? analysis,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/v1/chat');
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

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
