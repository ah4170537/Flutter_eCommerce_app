import 'package:cloud_firestore/cloud_firestore.dart';

class CartService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Standardized path for all cart operations: cart -> {userId} -> user_cart
  CollectionReference<Map<String, dynamic>> _cartRef(String userId) {
    return _firestore.collection('cart').doc(userId).collection('user_cart');
  }

  Future<void> addToCart({
    required String userId,
    required String productId,
    required String name,
    required num price,
    required String imageUrl,
    required int quantity,
    String? variant,
  }) async {
    // Generate a unique document ID based on product and variant
    // so different sizes/colors don't overwrite each other.
    final String sanitizedVariant = (variant != null && variant.isNotEmpty)
        ? variant.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        : 'default';
    final String cartDocId = '${productId}_$sanitizedVariant';

    final cartRef = _cartRef(userId).doc(cartDocId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(cartRef);

      if (snapshot.exists) {
        final existingQty = snapshot.data()?['quantity'] ?? 0;
        transaction.update(cartRef, {
          'quantity': existingQty + quantity,
          'variant': variant,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(cartRef, {
          'productId': productId,
          'name': name,
          'price': price,
          'imageUrl': imageUrl,
          'quantity': quantity,
          'variant': variant,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> updateQuantity({
    required String userId,
    required String productId, // This is the unique cartDocId
    required int newQuantity,
  }) async {
    if (newQuantity <= 0) {
      await removeFromCart(userId: userId, productId: productId);
    } else {
      await _cartRef(userId).doc(productId).update({
        'quantity': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> removeFromCart({
    required String userId,
    required String productId, // This is the unique cartDocId
  }) async {
    await _cartRef(userId).doc(productId).delete();
  }

  // Clear entire cart (Used after completing checkout)
  Future<void> clearCart(String userId) async {
    final snapshots = await _cartRef(userId).get();
    final batch = _firestore.batch();
    for (var doc in snapshots.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getCartStream(String userId) {
    return _cartRef(userId).orderBy('updatedAt', descending: true).snapshots();
  }

  Future<void> reorderItems({
    required String userId,
    required List<dynamic> orderedItems,
  }) async {
    final cartRef = _cartRef(userId);

    for (var item in orderedItems) {
      final String productId = item['productId'] ?? item['id'];
      final String? variant = item['variant'];

      // Use null-aware operator '?' or check if variant is not null safely
      final String sanitizedVariant = (variant != null && variant.isNotEmpty)
          ? variant.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          : 'default';

      final String cartDocId = '${productId}_$sanitizedVariant';

      await cartRef.doc(cartDocId).set({
        'productId': productId,
        'name': item['name'],
        'price': item['price'],
        'quantity': item['quantity'] ?? 1,
        'imageUrl': item['imageUrl'] ?? '',
        'variant': variant,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}
