class PriceAnalysis {
  PriceAnalysis({
    required this.query,
    required this.normalizedQuery,
    required this.offers,
    required this.marketplacesChecked,
    required this.failures,
    required this.recommendation,
    required this.reasoning,
    required this.timestamp,
    this.sourceProduct,
    this.cheapestOffer,
    this.aiSummary,
  });

  factory PriceAnalysis.fromJson(Map<String, dynamic> json) {
    return PriceAnalysis(
      query: json['query'] as String? ?? '',
      normalizedQuery: json['normalized_query'] as String? ?? '',
      sourceProduct: json['source_product'] == null
          ? null
          : SourceProductInfo.fromJson(json['source_product'] as Map<String, dynamic>),
      offers: ((json['offers'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MarketplaceOfferData.fromJson)
          .toList(),
      cheapestOffer: json['cheapest_offer'] == null
          ? null
          : MarketplaceOfferData.fromJson(json['cheapest_offer'] as Map<String, dynamic>),
      marketplacesChecked: ((json['marketplaces_checked'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      failures: ((json['failures'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MarketplaceFailureData.fromJson)
          .toList(),
      recommendation: json['recommendation'] as String? ?? 'wait',
      reasoning: json['reasoning'] as String? ?? '',
      aiSummary: json['ai_summary'] as String?,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }

  final String query;
  final String normalizedQuery;
  final SourceProductInfo? sourceProduct;
  final List<MarketplaceOfferData> offers;
  final MarketplaceOfferData? cheapestOffer;
  final List<String> marketplacesChecked;
  final List<MarketplaceFailureData> failures;
  final String recommendation;
  final String reasoning;
  final String? aiSummary;
  final DateTime timestamp;

  bool get hasOffers => offers.isNotEmpty;
  bool get shouldBuyNow => recommendation == 'buy';

  double get averagePrice {
    if (offers.isEmpty) {
      return 0;
    }
    final total = offers.fold<double>(0, (sum, offer) => sum + offer.price);
    return total / offers.length;
  }

  double get lowestPrice {
    if (offers.isEmpty) {
      return 0;
    }
    return offers.map((offer) => offer.price).reduce((a, b) => a < b ? a : b);
  }

  double get highestPrice {
    if (offers.isEmpty) {
      return 0;
    }
    return offers.map((offer) => offer.price).reduce((a, b) => a > b ? a : b);
  }

  String? get preferredCurrency =>
      sourceProduct?.currency ?? cheapestOffer?.currency ?? (offers.isNotEmpty ? offers.first.currency : null);

  String get productName => sourceProduct?.productName ?? cheapestOffer?.title ?? query;

  String? get imageUrl => sourceProduct?.imageUrl ?? cheapestOffer?.imageUrl;

  double get trackedCurrentPrice => sourceProduct?.price ?? cheapestOffer?.price ?? 0;

  String? get trackedSourceUrl => sourceProduct?.productUrl ?? cheapestOffer?.productUrl;

  String? get trackedPlatform => sourceProduct?.storeName ?? cheapestOffer?.marketplace;

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'normalized_query': normalizedQuery,
      'source_product': sourceProduct?.toJson(),
      'offers': offers.map((offer) => offer.toJson()).toList(),
      'cheapest_offer': cheapestOffer?.toJson(),
      'marketplaces_checked': marketplacesChecked,
      'failures': failures.map((failure) => failure.toJson()).toList(),
      'recommendation': recommendation,
      'reasoning': reasoning,
      'ai_summary': aiSummary,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class SourceProductInfo {
  SourceProductInfo({
    required this.inputValue,
    required this.extractedFromUrl,
    required this.productName,
    required this.normalizedName,
    this.storeName,
    this.productUrl,
    this.imageUrl,
    this.price,
    this.currency,
  });

  factory SourceProductInfo.fromJson(Map<String, dynamic> json) {
    return SourceProductInfo(
      inputValue: json['input_value'] as String? ?? '',
      extractedFromUrl: json['extracted_from_url'] as bool? ?? false,
      productName: json['product_name'] as String? ?? '',
      normalizedName: json['normalized_name'] as String? ?? '',
      storeName: json['store_name'] as String?,
      productUrl: json['product_url'] as String?,
      imageUrl: json['image_url'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
    );
  }

  final String inputValue;
  final bool extractedFromUrl;
  final String productName;
  final String normalizedName;
  final String? storeName;
  final String? productUrl;
  final String? imageUrl;
  final double? price;
  final String? currency;

  Map<String, dynamic> toJson() {
    return {
      'input_value': inputValue,
      'extracted_from_url': extractedFromUrl,
      'product_name': productName,
      'normalized_name': normalizedName,
      'store_name': storeName,
      'product_url': productUrl,
      'image_url': imageUrl,
      'price': price,
      'currency': currency,
    };
  }
}

class MarketplaceOfferData {
  MarketplaceOfferData({
    required this.marketplace,
    required this.title,
    required this.normalizedTitle,
    required this.price,
    required this.productUrl,
    required this.extractedAt,
    required this.similarityScore,
    required this.matchedQuery,
    required this.extractionSource,
    this.currency,
    this.priceText,
    this.imageUrl,
    this.inStock,
  });

  factory MarketplaceOfferData.fromJson(Map<String, dynamic> json) {
    return MarketplaceOfferData(
      marketplace: json['marketplace'] as String? ?? '',
      title: json['title'] as String? ?? '',
      normalizedTitle: json['normalized_title'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String?,
      priceText: json['price_text'] as String?,
      productUrl: json['product_url'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      inStock: json['in_stock'] as bool?,
      extractedAt: DateTime.tryParse(json['extracted_at'] as String? ?? '') ?? DateTime.now(),
      similarityScore: (json['similarity_score'] as num?)?.toDouble() ?? 0,
      matchedQuery: json['matched_query'] as String? ?? '',
      extractionSource: json['extraction_source'] as String? ?? 'search_result',
    );
  }

  final String marketplace;
  final String title;
  final String normalizedTitle;
  final double price;
  final String? currency;
  final String? priceText;
  final String productUrl;
  final String? imageUrl;
  final bool? inStock;
  final DateTime extractedAt;
  final double similarityScore;
  final String matchedQuery;
  final String extractionSource;

  Map<String, dynamic> toJson() {
    return {
      'marketplace': marketplace,
      'title': title,
      'normalized_title': normalizedTitle,
      'price': price,
      'currency': currency,
      'price_text': priceText,
      'product_url': productUrl,
      'image_url': imageUrl,
      'in_stock': inStock,
      'extracted_at': extractedAt.toIso8601String(),
      'similarity_score': similarityScore,
      'matched_query': matchedQuery,
      'extraction_source': extractionSource,
    };
  }
}

class MarketplaceFailureData {
  MarketplaceFailureData({
    required this.marketplace,
    required this.reason,
  });

  factory MarketplaceFailureData.fromJson(Map<String, dynamic> json) {
    return MarketplaceFailureData(
      marketplace: json['marketplace'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
    );
  }

  final String marketplace;
  final String reason;

  Map<String, dynamic> toJson() {
    return {
      'marketplace': marketplace,
      'reason': reason,
    };
  }
}
