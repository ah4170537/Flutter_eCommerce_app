import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatelessWidget {
  final String userId;

  const OrdersScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final String effectiveUserId = userId.isNotEmpty 
        ? userId 
        : (FirebaseAuth.instance.currentUser?.uid ?? '');

    if (effectiveUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Orders'),
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.primaryDark,
          elevation: 0,
        ),
        body: const Center(
          child: Text('Error: User session not found. Please log in again.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primaryDark,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(effectiveUserId)
            .collection('user_orders')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryDark),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading orders: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No orders found yet.'),
            );
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            itemCount: orders.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final orderData = orders[index].data() as Map<String, dynamic>;
              final orderId = orders[index].id;

              // Extract price
              final dynamic rawPrice = orderData['totalPrice'] ?? 
                                     orderData['total'] ?? 
                                     orderData['amount'] ?? 
                                     orderData['grandTotal'] ?? 0;
              final num totalPrice = (rawPrice is num) ? rawPrice : (num.tryParse(rawPrice.toString()) ?? 0);

              final status = orderData['status'] ?? 'Pending';
              final List<dynamic> items = orderData['items'] as List<dynamic>? ?? [];

              // Extract and format the date/timestamp
              // (Checks 'createdAt', 'timestamp', or 'date' fields safely)
              final dynamic rawTimestamp = orderData['createdAt'] ?? orderData['timestamp'] ?? orderData['date'];
              String formattedDate = '';
              if (rawTimestamp != null && rawTimestamp is Timestamp) {
                DateTime dt = rawTimestamp.toDate();
                // Format as: DD-MM-YYYY HH:MM (e.g., 11-09-2026 14:35)
                String hour = dt.hour.toString().padLeft(2, '0');
                String minute = dt.minute.toString().padLeft(2, '0');
                formattedDate = '${dt.day}-${dt.month}-${dt.year}  $hour:$minute';
              }

              return Card(
                color: Colors.white,
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderDetailScreen(
                          orderId: orderId,
                          userId: effectiveUserId,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order ID & Status Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order #${orderId.substring(0, orderId.length > 8 ? 8 : orderId.length).toUpperCase()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status,
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // Order Date Display
                        if (formattedDate.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),
                        
                        // Products list preview
                        ...items.map((item) {
                          final itemName = item['name'] ?? 'Product';
                          final dynamic rawQty = item['quantity'] ?? 1;
                          final int quantity = (rawQty is num) ? rawQty.toInt() : (int.tryParse(rawQty.toString()) ?? 1);
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '• $itemName',
                                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  'Qty: $quantity',
                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }),

                         const SizedBox(height: 10),

                        // Total Amount & Arrow Footer
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total: PKR $totalPrice',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const Row(
                              children: [
                                Text(
                                  'Details',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}