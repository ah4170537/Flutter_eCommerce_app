import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _emailJsServiceId = 'service_3a778zs';
  static const String _emailJsTemplateId = 'template_elx7tm7';
  static const String _emailJsPublicKey = 'xLJyWo6CV8LvFq26t';

  Future<void> placeOrder({
    required String userId,
    required String fullName,
    required String email,
    required String phone,
    required String secondaryPhone,
    required String country,
    required String state,
    required String city,
    required String address,
    required String postalCode,
    required String deliveryMode,
    required List<Map<String, dynamic>> cartItems,
    required double subtotal,
    required double deliveryFee,
  }) async {
    final total = subtotal + deliveryFee;
    final trimmedEmail = email.trim().toLowerCase();

    // Save order inside orders -> {userId} -> user_orders subcollection
    final orderRef = _firestore
        .collection('orders')
        .doc(userId)
        .collection('user_orders')
        .doc();

    final String orderId = orderRef.id;

    await orderRef.set({
      'orderId': orderId,
      'userId': userId,
      'fullName': fullName.trim(),
      'email': trimmedEmail,
      'phone': phone.trim(),
      'secondaryPhone': secondaryPhone.trim(),
      'country': country.trim(),
      'state': state.trim(),
      'city': city.trim(),
      'address': address.trim(),
      'postalCode': postalCode.trim(),
      'deliveryMode': deliveryMode,
      'items': cartItems,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'total': total,
      'status': 'placed',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final batch = _firestore.batch();
    for (final item in cartItems) {
      final String? productId = item['productId'];
      if (productId == null || productId.isEmpty) continue;

      final itemRef = _firestore
          .collection('cart')
          .doc(userId)
          .collection('user_cart')
          .doc(productId);

      batch.delete(itemRef);
    }
    await batch.commit();

    String formattedItems = cartItems
        .map((item) {
          final name = item['name'] ?? 'Product';
          final quantity = item['quantity'] ?? 1;
          final price = item['price'] ?? 0.0;
          return '• $name (Qty: $quantity) - PKR ${(price * quantity).toStringAsFixed(2)}';
        })
        .join('\n');

    // Send Email via EmailJS
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    final response = await http.post(
      url,
      headers: {
        'origin': 'http://localhost',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'service_id': _emailJsServiceId,
        'template_id': _emailJsTemplateId,
        'user_id': _emailJsPublicKey,
        'template_params': {
          'to_name': fullName.trim(),
          'to_email': trimmedEmail,
          'order_address': '${address.trim()}, ${city.trim()}, ${state.trim()}, ${country.trim()} (Postal Code: ${postalCode.trim()})',
          'phone': phone.trim(),
          'delivery_mode': deliveryMode,
          'order_items': formattedItems,
          'subtotal': 'PKR ${subtotal.toStringAsFixed(2)}',
          'delivery_fee': 'PKR ${deliveryFee.toStringAsFixed(2)}',
          'total_amount': 'PKR ${total.toStringAsFixed(2)}',
          'order_id': orderId,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Email delivery failed: ${response.body}');
    }
  }

  Future<void> cancelOrder({
    required String userId,
    required String orderId,
  }) async {
    final orderRef = _firestore
        .collection('orders')
        .doc(userId)
        .collection('user_orders')
        .doc(orderId);

    await orderRef.update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }
}