import 'dart:async';
import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/analysis_models.dart';

class LocalUrlAnalysisService {
  LocalUrlAnalysisService({required http.Client client}) : _client = client;

  static const _botKeywords = <String>[
    'captcha',
    'verify you are human',
    'access denied',
    'access to this page has been denied',
    'robot check',
    'security challenge',
    'unusual traffic',
    'anti-bot',
    'доступ ограничен',
    'почти готово',
  ];

  final http.Client _client;

  Future<PriceAnalysis?> analyze(String query) async {
    try {
      final trimmed = query.trim();
      final uri = Uri.tryParse(trimmed);
      if (!_looksLikeUrl(trimmed) || uri == null || uri.host.isEmpty) {
        return null;
      }

      final response = await _client.get(
        uri,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode >= 400 || response.bodyBytes.isEmpty) {
        return null;
      }

      final html = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (html.trim().isEmpty || _looksBlocked(html)) {
        return null;
      }

      final document = html_parser.parse(html);
      final productNode = _findProductNode(_extractJsonLd(document));
      final price = _extractPrice(document, productNode);
      final title = _extractTitle(document, productNode);
      final hasProductSignals = _hasProductSignals(document, productNode, uri);
      if (!hasProductSignals || title == null || price.amount == null) {
        return null;
      }

      final canonicalUrl = _canonicalUrl(document, uri);
      final storeName = _extractStoreName(document, productNode, canonicalUrl);
      final imageUrl = _extractImageUrl(document, productNode, canonicalUrl);
      final normalizedName = _normalizeProductName(title);
      final timestamp = DateTime.now();

      final source = SourceProductInfo(
        inputValue: trimmed,
        extractedFromUrl: true,
        productName: title,
        normalizedName: normalizedName,
        storeName: storeName,
        productUrl: canonicalUrl.toString(),
        imageUrl: imageUrl,
        price: price.amount,
        currency: price.currency,
      );

      final offer = MarketplaceOfferData(
        marketplace: storeName,
        title: title,
        normalizedTitle: normalizedName,
        price: price.amount!,
        currency: price.currency,
        priceText: price.rawText,
        productUrl: canonicalUrl.toString(),
        imageUrl: imageUrl,
        inStock: price.inStock,
        extractedAt: timestamp,
        similarityScore: 1,
        matchedQuery: trimmed,
        extractionSource: 'local_product_page',
      );

      return PriceAnalysis(
        query: trimmed,
        normalizedQuery: normalizedName,
        sourceProduct: source,
        offers: [offer],
        cheapestOffer: offer,
        marketplacesChecked: [storeName],
        failures: const [],
        recommendation: 'wait',
        aiSummary: 'Live source-page price found on $storeName.',
        reasoning:
            'ShadowPrice read the live price directly from the pasted product page on $storeName. Full cross-market comparison is unavailable right now, so this result shows the verified source price first.',
        timestamp: timestamp,
      );
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeUrl(String value) {
    return RegExp(r'^https?://', caseSensitive: false).hasMatch(value);
  }

  bool _looksBlocked(String html) {
    final lowered = html.toLowerCase();
    return _botKeywords.any(lowered.contains);
  }

  List<Object?> _extractJsonLd(dom.Document document) {
    final blocks = <Object?>[];
    for (final script
        in document.querySelectorAll('script[type="application/ld+json"]')) {
      final raw = script.text.trim();
      if (raw.isEmpty) {
        continue;
      }

      try {
        blocks.add(jsonDecode(raw));
      } catch (_) {
        continue;
      }
    }
    return blocks;
  }

  Map<String, dynamic>? _findProductNode(Object? value) {
    if (value is List) {
      for (final item in value) {
        final found = _findProductNode(item);
        if (found != null) {
          return found;
        }
      }
      return null;
    }

    if (value is Map) {
      final normalized = <String, dynamic>{};
      for (final entry in value.entries) {
        normalized[entry.key.toString()] = entry.value;
      }

      final typeValue = normalized['@type'];
      final types = <String>{};
      if (typeValue is String) {
        types.add(typeValue.toLowerCase());
      } else if (typeValue is List) {
        for (final item in typeValue) {
          types.add(item.toString().toLowerCase());
        }
      }

      if (types.contains('product') ||
          (normalized['name'] != null && normalized['offers'] != null)) {
        return normalized;
      }

      for (final nested in normalized.values) {
        final found = _findProductNode(nested);
        if (found != null) {
          return found;
        }
      }
    }

    return null;
  }

  _PriceDetails _extractPrice(
      dom.Document document, Map<String, dynamic>? productNode) {
    final offer = _firstOffer(productNode?['offers']);
    final offerPrice = _stringValue(offer?['price']);
    final offerLowPrice = _stringValue(offer?['lowPrice']);
    final productPrice = _stringValue(productNode?['price']);

    for (final candidate in <String?>[
      offerPrice,
      offerLowPrice,
      productPrice,
      _metaContent(document, 'meta[property="product:price:amount"]'),
      _metaContent(document, 'meta[property="og:price:amount"]'),
      _metaContent(document, 'meta[itemprop="price"]'),
    ]) {
      final parsed = _parsePrice(candidate);
      if (parsed.amount != null) {
        final currency = _extractCurrency(
          _stringValue(offer?['priceCurrency']) ??
              _stringValue(productNode?['priceCurrency']) ??
              _metaContent(
                  document, 'meta[property="product:price:currency"]') ??
              _metaContent(document, 'meta[itemprop="priceCurrency"]') ??
              parsed.currency,
        );
        final availability =
            _stringValue(offer?['availability'])?.toLowerCase();
        bool? inStock;
        if (availability != null) {
          if (availability.contains('instock')) {
            inStock = true;
          } else if (availability.contains('outofstock')) {
            inStock = false;
          }
        }
        return _PriceDetails(
          amount: parsed.amount,
          currency: currency,
          rawText: candidate,
          inStock: inStock,
        );
      }
    }

    const selectors = <String>[
      '[itemprop="price"]',
      '.a-price .a-offscreen',
      '[data-price]',
      '[class*="price"]',
    ];

    for (final selector in selectors) {
      for (final node in document.querySelectorAll(selector)) {
        final content = node.attributes['content'] ??
            node.attributes['data-price'] ??
            node.text.trim();
        final parsed = _parsePrice(content);
        if (parsed.amount != null) {
          return _PriceDetails(
            amount: parsed.amount,
            currency: parsed.currency,
            rawText: content,
            inStock: null,
          );
        }
      }
    }

    return const _PriceDetails();
  }

  bool _hasProductSignals(
    dom.Document document,
    Map<String, dynamic>? productNode,
    Uri uri,
  ) {
    final ogType =
        _metaContent(document, 'meta[property="og:type"]')?.toLowerCase();
    return productNode != null ||
        (ogType?.contains('product') ?? false) ||
        document.querySelector('meta[property="product:price:amount"]') !=
            null ||
        document.querySelector('meta[itemprop="price"]') != null ||
        _looksLikeKnownProductPath(uri);
  }

  bool _looksLikeKnownProductPath(Uri uri) {
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    if (host.contains('kaspi.kz')) {
      return path.contains('/shop/p/');
    }
    if (host.contains('amazon.')) {
      return path.contains('/dp/') || path.contains('/gp/product/');
    }
    if (host.contains('ebay.')) {
      return path.contains('/itm/');
    }
    if (host.contains('aliexpress.')) {
      return path.contains('/item/');
    }
    if (host.contains('wildberries.')) {
      return path.contains('/catalog/') && path.contains('detail.aspx');
    }
    if (host.contains('ozon.')) {
      return path.contains('/product/');
    }

    return path.contains('/product/') ||
        path.contains('/products/') ||
        path.contains('/item/');
  }

  String? _extractTitle(
      dom.Document document, Map<String, dynamic>? productNode) {
    final title = _firstNonEmpty([
      _stringValue(productNode?['name']),
      document.querySelector('h1')?.text.trim(),
      _metaContent(document, 'meta[property="og:title"]'),
      _metaContent(document, 'meta[name="twitter:title"]'),
      _metaContent(document, 'meta[itemprop="name"]'),
      document.querySelector('title')?.text.trim(),
    ]);
    if (title == null) {
      return null;
    }
    return _cleanTitle(title);
  }

  Uri _canonicalUrl(dom.Document document, Uri baseUri) {
    final href =
        document.querySelector('link[rel="canonical"]')?.attributes['href'];
    if (href == null || href.trim().isEmpty) {
      return baseUri;
    }
    return baseUri.resolve(href);
  }

  String _extractStoreName(
    dom.Document document,
    Map<String, dynamic>? productNode,
    Uri canonicalUrl,
  ) {
    final offer = _firstOffer(productNode?['offers']);
    String? sellerName;
    final seller = offer?['seller'];
    if (seller is Map) {
      sellerName = _stringValue(seller['name']);
    }

    return _firstNonEmpty([
          sellerName,
          _metaContent(document, 'meta[property="og:site_name"]'),
          _storeFromHost(canonicalUrl),
        ]) ??
        'Source store';
  }

  String? _extractImageUrl(
    dom.Document document,
    Map<String, dynamic>? productNode,
    Uri canonicalUrl,
  ) {
    var image = productNode?['image'];
    if (image is List && image.isNotEmpty) {
      image = image.first;
    }

    final candidate = _firstNonEmpty([
      _stringValue(image),
      _metaContent(document, 'meta[property="og:image"]'),
      _metaContent(document, 'meta[name="twitter:image"]'),
    ]);
    if (candidate == null) {
      return null;
    }
    return canonicalUrl.resolve(candidate).toString();
  }

  Map<String, dynamic>? _firstOffer(Object? value) {
    if (value is List) {
      for (final item in value) {
        final offer = _firstOffer(item);
        if (offer != null) {
          return offer;
        }
      }
      return null;
    }

    if (value is Map) {
      final normalized = <String, dynamic>{};
      for (final entry in value.entries) {
        normalized[entry.key.toString()] = entry.value;
      }
      return normalized;
    }

    return null;
  }

  _ParsedPrice _parsePrice(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return const _ParsedPrice();
    }

    final text = rawValue.trim();
    final currency = _extractCurrency(text);
    var cleaned = text.replaceAll(RegExp(r'[^\d,.\-]'), '');
    if (cleaned.isEmpty) {
      return _ParsedPrice(currency: currency);
    }

    if (cleaned.contains(',') && cleaned.contains('.')) {
      if (cleaned.lastIndexOf(',') > cleaned.lastIndexOf('.')) {
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains(',')) {
      final parts = cleaned.split(',');
      if (parts.length > 1 && parts.last.length <= 2) {
        cleaned = '${parts.sublist(0, parts.length - 1).join()}.${parts.last}';
      } else {
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(cleaned)) {
      cleaned = cleaned.replaceAll('.', '');
    }

    final amount = double.tryParse(cleaned);
    return _ParsedPrice(
      amount: amount,
      currency: currency,
    );
  }

  String? _extractCurrency(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final text = value.toUpperCase();
    if (value.contains(r'$')) {
      return 'USD';
    }
    if (value.contains('€')) {
      return 'EUR';
    }
    if (value.contains('£')) {
      return 'GBP';
    }
    if (value.contains('₸') || text.contains('KZT')) {
      return 'KZT';
    }
    if (value.contains('₽') || text.contains('RUB')) {
      return 'RUB';
    }
    if (value.contains('¥') || text.contains('JPY') || text.contains('CNY')) {
      return 'CNY';
    }
    return text.trim().length == 3 ? text.trim() : null;
  }

  String? _metaContent(dom.Document document, String selector) {
    final node = document.querySelector(selector);
    final content = node?.attributes['content'];
    if (content == null || content.trim().isEmpty) {
      return null;
    }
    return content.trim();
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String? _stringValue(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String _storeFromHost(Uri uri) {
    final host =
        uri.host.replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');
    final first = host.split('.').first;
    if (first.isEmpty) {
      return host;
    }
    return '${first[0].toUpperCase()}${first.substring(1)}';
  }

  String _cleanTitle(String value) {
    var cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceFirst(RegExp(r'^[A-Za-z0-9.-]+\s*:\s*'), '');
    cleaned = cleaned.replaceFirst(
      RegExp(r'\s*:\s*Electronics\s*$', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceFirst(
      RegExp(
        r'\s*\|\s*(Amazon(?:\.com)?|AliExpress|eBay|Kaspi(?: Магазин)?|Ozon|Wildberries)\s*$',
        caseSensitive: false,
      ),
      '',
    );
    return cleaned.trim();
  }

  String _normalizeProductName(String value) {
    var cleaned = value.toLowerCase();
    cleaned = cleaned.replaceAll(RegExp(r'https?://\S+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'[_|/\\\-]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\s]+', unicode: true), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    const stopWords = <String>{
      'buy',
      'shop',
      'store',
      'sale',
      'price',
      'official',
      'original',
      'amazon',
      'ebay',
      'aliexpress',
      'kaspi',
      'wildberries',
      'ozon',
      'electronics',
      'electronic',
      'com',
    };

    final tokens = cleaned
        .split(' ')
        .where((token) => token.isNotEmpty && !stopWords.contains(token))
        .toList();
    return tokens.join(' ');
  }
}

class _ParsedPrice {
  const _ParsedPrice({
    this.amount,
    this.currency,
  });

  final double? amount;
  final String? currency;
}

class _PriceDetails {
  const _PriceDetails({
    this.amount,
    this.currency,
    this.rawText,
    this.inStock,
  });

  final double? amount;
  final String? currency;
  final String? rawText;
  final bool? inStock;
}
