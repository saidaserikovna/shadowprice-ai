import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/product_model.dart';

class PriceService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Product> addProduct(Product product) async {
    final docRef = await _db.collection('tracked_products').add(product.toMap());
    return Product(
      id: docRef.id,
      userId: product.userId,
      name: product.name,
      url: product.url,
      currencyCode: product.currencyCode,
      currentPrice: product.currentPrice,
      marketAvg: product.marketAvg,
      lowestPrice: product.lowestPrice,
      highestPrice: product.highestPrice,
      status: product.status,
      platform: product.platform,
      category: product.category,
      imageUrl: product.imageUrl,
      notifyOnDrop: product.notifyOnDrop,
    );
  }

  Stream<List<Product>> getUserProducts(String userId) {
    return _db
        .collection('tracked_products')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Product.fromDoc(doc)).toList());
  }

  Future<void> updateProduct(String id, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('tracked_products').doc(id).update(updates);
    notifyListeners();
  }

  Future<void> deleteProduct(String id) async {
    final historySnap = await _db
        .collection('price_history')
        .where('productId', isEqualTo: id)
        .get();

    for (final doc in historySnap.docs) {
      await doc.reference.delete();
    }

    await _db.collection('tracked_products').doc(id).delete();
    notifyListeners();
  }

  Future<void> toggleNotify(String id, bool current) async {
    await updateProduct(id, {'notifyOnDrop': !current});
  }

  Future<void> addPriceHistory(PriceHistoryEntry entry) async {
    await _db.collection('price_history').add(entry.toMap());
  }

  Stream<List<PriceHistoryEntry>> getPriceHistory(String productId) {
    return _db
        .collection('price_history')
        .where('productId', isEqualTo: productId)
        .orderBy('recordedAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => PriceHistoryEntry.fromDoc(doc)).toList());
  }
}
