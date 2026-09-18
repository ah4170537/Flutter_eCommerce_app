import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_colors.dart';

class ReceiptScreen extends StatelessWidget {
  final String orderId;
  final String? userId;

  const ReceiptScreen({
    super.key,
    required this.orderId,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final String effectiveUserId = userId != null && userId!.isNotEmpty
        ? userId!
        : (FirebaseAuth.instance.currentUser?.uid ?? '');


final String receiptUrl = 'https://e-commerce-app-bfe73.web.app/?id=$orderId&uid=$effectiveUserId';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Order Receipt'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryDark,
        elevation: 0,
        centerTitle: true,
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
            return const Center(child: Text('Receipt details not found.'));
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Header Receipt Title
                  const Center(
                    child: Text(
                      'OFFICIAL RECEIPT',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Order ID & Date Metadata
                  Text(
                    'Order ID: #$orderId',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  if (formattedDate.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Date: $formattedDate',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                  const Divider(height: 24),

                  // Items List Header
                  const Text(
                    'Items',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Dynamic items list matching a receipt style
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index] as Map<String, dynamic>;
                      final itemName = item['name'] ?? 'Product';
                      final String? variant = item['variant'];
                      final dynamic itemPriceRaw = item['price'] ?? 0;
                      final num itemPrice = (itemPriceRaw is num)
                          ? itemPriceRaw
                          : (num.tryParse(itemPriceRaw.toString()) ?? 0);

                      final dynamic rawQty = item['quantity'] ?? 1;
                      final int quantity = (rawQty is num)
                          ? rawQty.toInt()
                          : (int.tryParse(rawQty.toString()) ?? 1);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    itemName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (variant != null && variant.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Variant: $variant',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 2),
                                  Text(
                                    'Qty: $quantity',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'PKR ${itemPrice * quantity}',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const Divider(height: 24),

                  // Total Summary Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      Text(
                        'PKR $totalPrice',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // QR Code Section at the Bottom
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'Scan to view web receipt',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        QrImageView(
                          data: receiptUrl,
                          version: QrVersions.auto,
                          size: 160.0,
                          gapless: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}