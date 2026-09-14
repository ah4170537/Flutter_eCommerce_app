import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

import '../widgets/cancel_order_button.dart';
import "order_progress_screen.dart";
import 'main_navigation_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  final String? userId;

  const OrderDetailScreen({super.key, required this.orderId, this.userId});

  @override
  Widget build(BuildContext context) {
    final String effectiveUserId = userId != null && userId!.isNotEmpty
        ? userId!
        : (FirebaseAuth.instance.currentUser?.uid ?? '');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primaryDark,
        scrolledUnderElevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('orders')
            .doc(effectiveUserId)
            .collection('user_orders')
            .doc(orderId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryDark),
            );
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(child: Text('Order details not found.'));
          }

          final orderData = snapshot.data!.data() as Map<String, dynamic>;
          final items = orderData['items'] as List<dynamic>? ?? [];

          final dynamic rawPrice =
              orderData['totalPrice'] ??
              orderData['total'] ??
              orderData['amount'] ??
              orderData['grandTotal'] ??
              0;
          final num totalPrice = (rawPrice is num)
              ? rawPrice
              : (num.tryParse(rawPrice.toString()) ?? 0);

          final status = orderData['status'] ?? 'Pending';

          // Extract and format the date/timestamp
          final dynamic rawTimestamp =
              orderData['createdAt'] ??
              orderData['timestamp'] ??
              orderData['date'];
          String formattedDate = '';
          if (rawTimestamp != null && rawTimestamp is Timestamp) {
            DateTime dt = rawTimestamp.toDate();
            String hour = dt.hour.toString().padLeft(2, '0');
            String minute = dt.minute.toString().padLeft(2, '0');
            formattedDate = '${dt.day}-${dt.month}-${dt.year}  $hour:$minute';
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order ID: #$orderId',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textGrey,
                  ),
                ),

                // Date & Time Display
                if (formattedDate.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Date: $formattedDate',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],

                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text(
                      'Status: ',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        color: status == 'cancelled'
                            ? Colors.red
                            : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text(
                  'Items Purchased',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index] as Map<String, dynamic>;
                      final itemName = item['name'] ?? 'Product';
                      final dynamic itemPriceRaw = item['price'] ?? 0;
                      final num itemPrice = (itemPriceRaw is num)
                          ? itemPriceRaw
                          : (num.tryParse(itemPriceRaw.toString()) ?? 0);

                      final dynamic rawQty = item['quantity'] ?? 1;
                      final int quantity = (rawQty is num)
                          ? rawQty.toInt()
                          : (int.tryParse(rawQty.toString()) ?? 1);

                      final String imageUrl = item['imageUrl'] ?? '';

                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                                  width: 60,
                                                  height: 60,
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(
                                                    Icons.image_not_supported,
                                                    size: 24,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                      )
                                    : Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.shopping_bag,
                                          size: 24,
                                          color: Colors.grey,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      itemName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Qty: $quantity',
                                      style: const TextStyle(
                                        color: AppColors.textGrey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'PKR ${itemPrice * quantity}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),
                // Cancel Order — visible for 30 minutes after order creation
                // (server-time enforced via Firestore Security Rules).
                if (orderData['createdAt'] is Timestamp)
                  CancelOrderButton(
                    userId: effectiveUserId,
                    orderId: orderId,
                    createdAt: orderData['createdAt'] as Timestamp,
                    currentStatus: status,
                    onCancelled: () {
                      Navigator.pop(context);
                    },
                  ),

                // --- Add this button right above the Reorder button ---
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OrderProgressScreen(
                            initialOrderId: orderId, // Changed from widget.orderId to orderId
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.local_shipping_outlined,
                      color: AppColors.primaryDark,
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryDark),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    label: const Text(
                      // Changed from child: to label:
                      'View Order Progress',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'PKR $totalPrice',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Reorder Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryDark,
                          ),
                        ),
                      );

                      try {
                        final cartRef = FirebaseFirestore.instance
                            .collection('cart')
                            .doc(effectiveUserId)
                            .collection('user_cart');

                        for (var item in items) {
                          final String productId =
                              item['productId'] ??
                              item['id'] ??
                              item['product_id'] ??
                              '';
                          final int itemQty = (item['quantity'] is num)
                              ? item['quantity'].toInt()
                              : (int.tryParse(item['quantity'].toString()) ??
                                    1);

                          final docRef = productId.isNotEmpty
                              ? cartRef.doc(productId)
                              : cartRef.doc();

                          await docRef.set({
                            'productId': productId.isNotEmpty
                                ? productId
                                : docRef.id,
                            'name': item['name'] ?? 'Product',
                            'price': item['price'] ?? 0,
                            'quantity': FieldValue.increment(itemQty),
                            'imageUrl': item['imageUrl'] ?? '',
                            'updatedAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));
                        }

                        if (!context.mounted) return;

                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MainNavigationScreen(
                              userId: userId ?? '',
                              initialIndex: 1,
                            ),
                          ),
                          (route) => false,
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to reorder: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Reorder',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
