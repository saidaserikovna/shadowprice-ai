import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String userId;
  final String name;
  final String? url;
  final String? currencyCode;
  final double currentPrice;
  final double marketAvg;
  final double? lowestPrice;
  final double? highestPrice;
  final String status; // "buy", "wait", "tracking"
  final String? platform;
  final String? category;
  final String? imageUrl;
  final bool notifyOnDrop;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.userId,
    required this.name,
    this.url,
    this.currencyCode,
    required this.currentPrice,
    required this.marketAvg,
    this.lowestPrice,
    this.highestPrice,
    this.status = 'tracking',
    this.platform,
    this.category,
    this.imageUrl,
    this.notifyOnDrop = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get overpayPercent => marketAvg > 0 ? ((currentPrice - marketAvg) / marketAvg) * 100 : 0;
  bool get isOverpaying => overpayPercent > 0;
  double get savings => isOverpaying ? 0 : (marketAvg - currentPrice);

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'name': name,
    'url': url,
    'currencyCode': currencyCode,
    'currentPrice': currentPrice,
    'marketAvg': marketAvg,
    'lowestPrice': lowestPrice,
    'highestPrice': highestPrice,
    'status': status,
    'platform': platform,
    'category': category,
    'imageUrl': imageUrl,
    'notifyOnDrop': notifyOnDrop,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(DateTime.now()),
  };

  factory Product.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      userId: d['userId'] ?? '',
      name: d['name'] ?? '',
      url: d['url'],
      currencyCode: d['currencyCode'],
      currentPrice: (d['currentPrice'] ?? 0).toDouble(),
      marketAvg: (d['marketAvg'] ?? 0).toDouble(),
      lowestPrice: d['lowestPrice']?.toDouble(),
      highestPrice: d['highestPrice']?.toDouble(),
      status: d['status'] ?? 'tracking',
      platform: d['platform'],
      category: d['category'],
      imageUrl: d['imageUrl'],
      notifyOnDrop: d['notifyOnDrop'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Product copyWith({
    String? name,
    String? url,
    String? currencyCode,
    double? currentPrice,
    double? marketAvg,
    double? lowestPrice,
    double? highestPrice,
    String? status,
    String? platform,
    String? category,
    String? imageUrl,
    bool? notifyOnDrop,
  }) {
    return Product(
      id: id,
      userId: userId,
      name: name ?? this.name,
      url: url ?? this.url,
      currencyCode: currencyCode ?? this.currencyCode,
      currentPrice: currentPrice ?? this.currentPrice,
      marketAvg: marketAvg ?? this.marketAvg,
      lowestPrice: lowestPrice ?? this.lowestPrice,
      highestPrice: highestPrice ?? this.highestPrice,
      status: status ?? this.status,
      platform: platform ?? this.platform,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      notifyOnDrop: notifyOnDrop ?? this.notifyOnDrop,
      createdAt: createdAt,
    );
  }
}

class PriceHistoryEntry {
  final String id;
  final String productId;
  final double price;
  final String? platform;
  final DateTime recordedAt;

  PriceHistoryEntry({
    required this.id,
    required this.productId,
    required this.price,
    this.platform,
    DateTime? recordedAt,
  }) : recordedAt = recordedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'price': price,
    'platform': platform,
    'recordedAt': Timestamp.fromDate(recordedAt),
  };

  factory PriceHistoryEntry.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PriceHistoryEntry(
      id: doc.id,
      productId: d['productId'] ?? '',
      price: (d['price'] ?? 0).toDouble(),
      platform: d['platform'],
      recordedAt: (d['recordedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
