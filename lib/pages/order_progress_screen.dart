import 'package:cloud_firestore/cloud_firestore.dart';
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
  
  // We use this state variable to hold the currently searched/active Order ID 
  // that the StreamBuilder should listen to.
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

    // Unfocus keyboard and trigger a rebuild with the new active order ID
    FocusScope.of(context).unfocus();
    setState(() {
      _activeOrderId = queryId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isStandalone = widget.initialOrderId == null || widget.initialOrderId!.isEmpty;

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

            // Main Content Area handled by StreamBuilders
            Expanded(
              child: _activeOrderId == null || _activeOrderId!.isEmpty
                  ? const Center(child: Text('Enter an Order ID to view progress.'))
                  : StreamBuilder<DocumentSnapshot>(
                      // Step 1: Listen to the order index to find out which user owns this order ID
                      stream: FirebaseFirestore.instance
                          .collection('order_index')
                          .doc(_activeOrderId)
                          .snapshots(),
                      builder: (context, indexSnapshot) {
                        if (indexSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.primaryDark));
                        }

                        if (!indexSnapshot.hasData || !indexSnapshot.data!.exists) {
                          return Center(
                            child: Text(
                              'Order #$_activeOrderId not found.',
                              style: const TextStyle(color: Colors.red, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        final indexData = indexSnapshot.data!.data() as Map<String, dynamic>?;
                        final String? ownerUserId = indexData?['userId'];

                        if (ownerUserId == null || ownerUserId.isEmpty) {
                          return Center(
                            child: Text(
                              'Order #$_activeOrderId not found.',
                              style: const TextStyle(color: Colors.red, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        // Step 2: Once we have the ownerUserId, listen to the actual progress document in real-time
                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('order_progress')
                              .doc(ownerUserId)
                              .collection('user_progress_items')
                              .doc(_activeOrderId)
                              .snapshots(),
                          builder: (context, orderSnapshot) {
                            if (orderSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: AppColors.primaryDark));
                            }

                            if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
                              return Center(
                                child: Text(
                                  'Order #$_activeOrderId not found.',
                                  style: const TextStyle(color: Colors.red, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }

                            final orderData = orderSnapshot.data!.data() as Map<String, dynamic>?;
                            if (orderData == null) {
                              return const Center(child: Text('No data available for this order.'));
                            }

                            final foundOrderId = orderData['orderId'] ?? orderSnapshot.data!.id;
                            final currentStatus = orderData['currentStatus'] ?? 'Pending';
                            final items = orderData['items'] as List<dynamic>? ?? [];
                            final progressSteps = orderData['progressSteps'] as List<dynamic>? ?? [];

                            return ListView(
                              children: [
                                // Order ID & Status Header
                                Text(
                                  'Order ID: #$foundOrderId',
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

                                // Products Summary / Items if present
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
                                        final dynamic rawQty = item['quantity'] ?? 1;
                                        final int quantity = (rawQty is num)
                                            ? rawQty.toInt()
                                            : (int.tryParse(rawQty.toString()) ?? 1);

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '• $itemName',
                                                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
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

                                // Tracking Timeline
                                const Text(
                                  'Order Progress Timeline',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 12),
                                _buildTrackingTimeline(progressSteps),
                              ],
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

  Widget _buildTrackingTimeline(List<dynamic> trackingSteps) {
    if (trackingSteps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Text('No tracking updates available yet.', style: TextStyle(color: AppColors.textGrey)),
      );
    }

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
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                    if (isLatest && !isLastStepOverall) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: const Text(
                          'Current Status',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
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