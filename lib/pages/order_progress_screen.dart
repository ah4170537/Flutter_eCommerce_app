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
  bool _isLoading = false;
  Map<String, dynamic>? _orderData;
  String? _foundOrderId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialOrderId != null && widget.initialOrderId!.isNotEmpty) {
      _searchController.text = widget.initialOrderId!;
      _fetchOrderDetails(widget.initialOrderId!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrderDetails(String orderId) async {
    final trimmedId = orderId.trim();
    if (trimmedId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _orderData = null;
      _foundOrderId = null;
    });

    try {
      // Step 1: look up which userId this order belongs to — a plain
      // document read, no index needed.
      final indexDoc = await FirebaseFirestore.instance
          .collection('order_index')
          .doc(trimmedId)
          .get();

      if (!indexDoc.exists) {
        setState(() {
          _errorMessage = 'Order #$trimmedId not found.';
          _isLoading = false;
        });
        return;
      }

      final String? ownerUserId = indexDoc.data()?['userId'];
      if (ownerUserId == null || ownerUserId.isEmpty) {
        setState(() {
          _errorMessage = 'Order #$trimmedId not found.';
          _isLoading = false;
        });
        return;
      }

      // Step 2: fetch the actual order progress directly by path — also
      // a plain document read, no index needed.
      final orderDoc = await FirebaseFirestore.instance
          .collection('order_progress')
          .doc(ownerUserId)
          .collection('user_progress_items')
          .doc(trimmedId)
          .get();

      if (orderDoc.exists) {
        setState(() {
          _orderData = orderDoc.data();
          _foundOrderId = orderDoc.data()?['orderId'] ?? orderDoc.id;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Order #$trimmedId not found.';
          _isLoading = false;
        });
      }
    } on FirebaseException catch (e) {
      debugPrint('Firestore error code: ${e.code}');
      debugPrint('Firestore error message: ${e.message}');
      setState(() {
        _errorMessage = e.code == 'permission-denied'
            ? "This order exists, but you don't have permission to view it."
            // TEMPORARY: showing the raw error so we can diagnose it.
            // Revert to a generic message once this is confirmed working.
            : 'Error (${e.code}): ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Non-Firebase error: $e');
      setState(() {
        _errorMessage = 'Something went wrong: $e';
        _isLoading = false;
      });
    }
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
                      onPressed: () => _fetchOrderDetails(_searchController.text),
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
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primaryDark),
                ),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
              )
            else if (_orderData == null)
              const Expanded(
                child: Center(
                  child: Text('Enter an Order ID to view progress.'),
                ),
              )
            else
              Expanded(
                child: ListView(
                  children: [
                    // Order ID & Status Header
                    Text(
                      'Order ID: #$_foundOrderId',
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
                          _orderData!['currentStatus'] ?? 'Pending',
                          style: TextStyle(
                            color: (_orderData!['currentStatus'] ?? '').toString().toLowerCase() == 'cancelled'
                                ? Colors.red
                                : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Products Summary / Items if present in the document
                    if (_orderData!.containsKey('items')) ...[
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
                          children: ((_orderData!['items'] as List<dynamic>? ?? [])).map((item) {
                            final itemName = item['name'] ?? 'Product';
                            final dynamic rawQty = item['quantity'] ?? 1;
                            final int quantity = (rawQty is num) ? rawQty.toInt() : (int.tryParse(rawQty.toString()) ?? 1);

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

                    // Tracking Timeline (mapped to 'progressSteps' from seeder)
                    const Text(
                      'Order Progress Timeline',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    _buildTrackingTimeline((_orderData!['progressSteps'] as List<dynamic>? ?? [])),
                  ],
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