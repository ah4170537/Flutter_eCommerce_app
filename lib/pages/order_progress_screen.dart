import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';


class OrderProgressScreen extends StatefulWidget {
  final String? initialOrderId;

  const OrderProgressScreen({super.key, this.initialOrderId});

  @override
  State<OrderProgressScreen> createState() => _OrderProgressScreenState();
}

class _OrderProgressScreenState extends State<OrderProgressScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _activeOrderId;

  @override
  void initState() {
    super.initState();
    if (widget.initialOrderId != null && widget.initialOrderId!.isNotEmpty) {
      _searchController.text = widget.initialOrderId!;
      _activeOrderId = widget.initialOrderId!.trim();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch() {
    final queryId = _searchController.text.trim();
    if (queryId.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _activeOrderId = queryId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isStandalone = widget.initialOrderId == null || widget.initialOrderId!.isEmpty;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Order Progress'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primaryDark,
        scrolledUnderElevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isStandalone) ...[
              const Text(
                'Track Your Order',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Enter Order ID',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _handleSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Search', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Main Content Area
            Expanded(
              child: _activeOrderId == null || _activeOrderId!.isEmpty
                  ? const Center(child: Text('Enter an Order ID to view progress.'))
                  : currentUserId == null
                      ? const Center(
                          child: Text(
                            'Please log in to track your orders.',
                            style: TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        )
                      : StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('orders')
                              .doc(currentUserId)
                              .collection('user_orders')
                              .doc(_activeOrderId)
                              .snapshots(),
                          builder: (context, primaryOrderSnapshot) {
                            if (primaryOrderSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: AppColors.primaryDark));
                            }

                            if (!primaryOrderSnapshot.hasData || !primaryOrderSnapshot.data!.exists) {
                              return Center(
                                child: Text(
                                  'Order #$_activeOrderId not found.',
                                  style: const TextStyle(color: Colors.red, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }

                            final primaryData = primaryOrderSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                            final items = primaryData['items'] as List<dynamic>? ?? [];
                            final primaryStatus = primaryData['status'] ?? primaryData['orderStatus'] ?? 'Processing';

                            // Nest the progress subcollection listener so that if the progress doc doesn't exist yet,
                            // we still successfully display the main order items and status cleanly.
                            return StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('order_progress')
                                  .doc(currentUserId)
                                  .collection('user_progress_items')
                                  .doc(_activeOrderId)
                                  .snapshots(),
                              builder: (context, progressSnapshot) {
                                final progressData = progressSnapshot.hasData && progressSnapshot.data!.exists
                                    ? progressSnapshot.data!.data() as Map<String, dynamic>?
                                    : null;

                                final currentStatus = progressData?['currentStatus'] ?? primaryStatus;
                                final progressSteps = progressData?['progressSteps'] as List<dynamic>? ?? [];

                                return _buildOrderContent(
                                  orderId: _activeOrderId!,
                                  currentStatus: currentStatus,
                                  items: items,
                                  progressSteps: progressSteps,
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderContent({
    required String orderId,
    required String currentStatus,
    required List<dynamic> items,
    required List<dynamic> progressSteps,
  }) {
    return ListView(
      children: [
        Text(
          'Order ID: #$orderId',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.textGrey,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Text(
              'Status: ',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              currentStatus,
              style: TextStyle(
                color: currentStatus.toString().toLowerCase() == 'cancelled'
                    ? Colors.red
                    : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const Divider(height: 24),

        // Items List (Always displayed with variants)
        if (items.isNotEmpty) ...[
          const Text(
            'Items in Order',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: items.map((item) {
                final itemName = item['name'] ?? 'Product';
                final String? variant = item['variant'];
                final dynamic rawQty = item['quantity'] ?? 1;
                final int quantity = (rawQty is num)
                    ? rawQty.toInt()
                    : (int.tryParse(rawQty.toString()) ?? 1);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• $itemName',
                              style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (variant != null && variant.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 12.0, top: 2),
                                child: Text(
                                  'Variant: $variant',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        'Qty: $quantity',
                        style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 24),
        ],

        // Tracking Timeline Section
        const Text(
          'Order Progress Timeline',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        
        progressSteps.isEmpty
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.primaryDark, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No detailed timeline updates available yet. Your order has been placed successfully.',
                        style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                      ),
                    ),
                  ],
                ),
              )
            : _buildTrackingTimeline(progressSteps),
      ],
    );
  }

  Widget _buildTrackingTimeline(List<dynamic> trackingSteps) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: trackingSteps.length,
      itemBuilder: (context, index) {
        final step = trackingSteps[index] as Map<String, dynamic>;
        final title = step['title'] ?? '';
        final location = step['location'] ?? '';
        final description = step['subtitle'] ?? step['description'] ?? '';

        final dynamic rawTime = step['timestamp'];
        String timeString = '';
        if (rawTime != null && rawTime is Timestamp) {
          DateTime dt = rawTime.toDate();
          String hour = dt.hour.toString().padLeft(2, '0');
          String minute = dt.minute.toString().padLeft(2, '0');
          timeString = '${dt.day}-${dt.month}-${dt.year} $hour:$minute';
        }

        final bool isLatest = index == trackingSteps.length - 1;
        final bool isLastStepOverall = isLatest && title.toLowerCase().contains('delivered');

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isLatest ? AppColors.primaryDark : Colors.green,
                  ),
                  child: Icon(
                    isLastStepOverall ? Icons.check : (isLatest ? Icons.radio_button_checked : Icons.done),
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                if (index != trackingSteps.length - 1)
                  Container(
                    width: 2,
                    height: 50,
                    color: Colors.green,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: isLatest ? FontWeight.bold : FontWeight.w600,
                            fontSize: 15,
                            color: isLatest ? AppColors.primaryDark : Colors.black87,
                          ),
                        ),
                        if (timeString.isNotEmpty)
                          Text(
                            timeString,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                      ],
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        location,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                    if(description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}