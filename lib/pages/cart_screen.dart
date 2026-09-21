import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/cart_service.dart';
import '../theme/app_colors.dart';
import 'checkout_screen.dart';
import 'login.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartScreen extends StatefulWidget {
  final String userId;

  const CartScreen({super.key, required this.userId});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _cartStream;
  bool _isCheckingOut = false;
  bool _isDeletingSelected = false; // Tracks bulk deletion state

  // Track product IDs that the user has unchecked
  final Set<String> _deselectedIds = {};

  @override
  void initState() {
    super.initState();
    _cartStream = _cartService.getCartStream(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text(
          'My Cart',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.primaryDark),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _cartStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryDark),
            );
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading cart.'));
          }

          final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.data!.docs);
          docs.sort((a, b) => a.id.compareTo(b.id));

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            );
          }

          double subtotal = 0.0;
          List<Map<String, dynamic>> selectedCartItems = [];

          for (var doc in docs) {
            final data = doc.data();
            final productId = doc.id;
            final num basePrice = data['price'] ?? 0;
            final String? variant = data['variant'];
            
            final List<dynamic> partsDynamic = data['parts'] is List ? data['parts'] : [];
            final bool hasPartsListField = data.containsKey('parts');
            final num mainQuantity = data['quantity'] ?? 1;

            final bool isSelected = !_deselectedIds.contains(productId);

            // Calculate parts subtotal
            num partsSubtotal = 0;
            for (var part in partsDynamic) {
              if (part is Map) {
                final num pPrice = part['price'] ?? 0;
                final int pQty = part['quantity'] ?? 1;
                partsSubtotal += (pPrice * pQty);
              }
            }

            // Calculate total item cost: Base product price + parts subtotal
            num itemTotal = 0;
            if (hasPartsListField) {
              itemTotal = (basePrice * mainQuantity) + partsSubtotal;
            } else {
              itemTotal = basePrice * mainQuantity;
            }

            final itemMap = {
              'productId': productId,
              'name': data['name'] ?? 'Product',
              'price': basePrice,
              'quantity': mainQuantity,
              'imageUrl': data['imageUrl'] ?? '',
              'variant': variant,
              'parts': partsDynamic,
            };

            if (isSelected) {
              subtotal += itemTotal;
              selectedCartItems.add(itemMap);
            }
          }

          const double deliveryFee = 300.0;
          double total = selectedCartItems.isEmpty
              ? 0.0
              : subtotal + deliveryFee;

          return Column(
            children: [
              // -------------------------------------------------------------
              // BULK DELETE SELECTED HEADER BAR
              // -------------------------------------------------------------
              if (selectedCartItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${selectedCartItems.length} items selected',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      TextButton.icon(
                        onPressed: _isDeletingSelected
                            ? null
                            : () async {
                                setState(() {
                                  _isDeletingSelected = true;
                                });

                                try {
                                  await Future.wait(
                                    selectedCartItems.map((item) => _cartService.removeFromCart(
                                          userId: widget.userId,
                                          productId: item['productId'],
                                        )),
                                  );
                                  setState(() {
                                    _deselectedIds.clear();
                                  });
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isDeletingSelected = false;
                                    });
                                  }
                                }
                              },
                        icon: _isDeletingSelected
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.redAccent,
                                ),
                              )
                            : const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                        label: Text(
                          _isDeletingSelected ? 'Deleting...' : 'Delete Selected',
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final productId = doc.id;
                    final String name = data['name'] ?? 'Product';
                    final num price = data['price'] ?? 0;
                    final String imageUrl = data['imageUrl'] ?? '';
                    final String? variant = data['variant'];
                    
                    final List<dynamic> partsDynamic = data['parts'] is List ? data['parts'] : [];
                    final bool hasPartsListField = data.containsKey('parts');
                    final bool hasParts = partsDynamic.isNotEmpty;
                    
                    final dynamic rawQty = data['quantity'] ?? 1;
                    final int quantity = (rawQty is num)
                        ? rawQty.toInt()
                        : (int.tryParse(rawQty.toString()) ?? 1);
                    
                    final bool isSelected = !_deselectedIds.contains(productId);

                    // Calculate displayed total for this specific box item
                    num boxPartsSubtotal = 0;
                    for (var part in partsDynamic) {
                      if (part is Map) {
                        boxPartsSubtotal += ((part['price'] ?? 0) * (part['quantity'] ?? 1));
                      }
                    }

                    num boxItemTotal = 0;
                    if (hasPartsListField) {
                      boxItemTotal = (price * quantity) + boxPartsSubtotal;
                    } else {
                      boxItemTotal = price * quantity;
                    }

                    return Opacity(
                      opacity: _isDeletingSelected && isSelected ? 0.6 : 1.0,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryDark.withValues(alpha: 0.3)
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main Product Info Row
                            Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  activeColor: AppColors.primaryDark,
                                  onChanged: _isDeletingSelected
                                      ? null
                                      : (bool? value) {
                                          setState(() {
                                            if (value == true) {
                                              _deselectedIds.remove(productId);
                                            } else {
                                              _deselectedIds.add(productId);
                                            }
                                          });
                                        },
                                ),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey.shade200,
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey.shade200,
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                      if (variant != null && variant.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Variant: $variant',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        'PKR $boxItemTotal',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: _isDeletingSelected
                                      ? null
                                      : () => _cartService.removeFromCart(
                                            userId: widget.userId,
                                            productId: productId,
                                          ),
                                ),
                              ],
                            ),

                            // If product template has parts field, manage parts list
                            if (hasPartsListField) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Divider(height: 1),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Included Parts & Quantities:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  if (!hasParts)
                                    const Text(
                                      'No parts selected (Base product only)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                              if (hasParts) ...[
                                const SizedBox(height: 6),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: partsDynamic.length,
                                  itemBuilder: (context, partIndex) {
                                    final partMap = Map<String, dynamic>.from(partsDynamic[partIndex]);
                                    final String partName = partMap['partName'] ?? 'Part';
                                    final num partPrice = partMap['price'] ?? 0;
                                    final int partQty = partMap['quantity'] ?? 1;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  partName,
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                                ),
                                                Text(
                                                  'PKR $partPrice each',
                                                  style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              InkWell(
                                                onTap: _isDeletingSelected
                                                    ? null
                                                    : () async {
                                                        if (partQty <= 0) return;

                                                        partsDynamic[partIndex]['quantity'] = partQty - 1;

                                                        await FirebaseFirestore.instance
                                                            .collection('cart')
                                                            .doc(widget.userId)
                                                            .collection('user_cart')
                                                            .doc(productId)
                                                            .update({'parts': partsDynamic});
                                                      },
                                                child: Container(
                                                  padding: const EdgeInsets.all(3),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.grey.shade300),
                                                  ),
                                                  child: const Icon(Icons.remove, size: 12),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                                child: Text(
                                                  '$partQty',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: _isDeletingSelected
                                                    ? null
                                                    : () async {
                                                        partsDynamic[partIndex]['quantity'] = partQty + 1;
                                                        await FirebaseFirestore.instance
                                                            .collection('cart')
                                                            .doc(widget.userId)
                                                            .collection('user_cart')
                                                            .doc(productId)
                                                            .update({'parts': partsDynamic});
                                                      },
                                                child: Container(
                                                  padding: const EdgeInsets.all(3),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.grey.shade300),
                                                  ),
                                                  child: const Icon(Icons.add, size: 12),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ] else ...[
                              // Standard product quantity controls (Only shown for items that do NOT support parts)
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  InkWell(
                                    onTap: _isDeletingSelected
                                        ? null
                                        : () => _cartService.updateQuantity(
                                              userId: widget.userId,
                                              productId: productId,
                                              newQuantity: quantity - 1,
                                            ),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: const Icon(Icons.remove, size: 14),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                    child: Text(
                                      '$quantity',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: _isDeletingSelected
                                        ? null
                                        : () => _cartService.updateQuantity(
                                              userId: widget.userId,
                                              productId: productId,
                                              newQuantity: quantity + 1,
                                            ),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: const Icon(Icons.add, size: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Subtotal',
                            style: TextStyle(color: Colors.grey),
                          ),
                          Text(
                            'PKR ${subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Delivery Fee',
                            style: TextStyle(color: Colors.grey),
                          ),
                          Text(
                            'PKR ${selectedCartItems.isEmpty ? 0.0 : deliveryFee.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          Text(
                            'PKR ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: (_isCheckingOut || _isDeletingSelected || selectedCartItems.isEmpty)
                            ? null
                            : () async {
                                setState(() {
                                  _isCheckingOut = true;
                                });

                                await Future.delayed(
                                  const Duration(milliseconds: 100),
                                );

                                if (!context.mounted) return;

                                final User? currentUser =
                                    FirebaseAuth.instance.currentUser;
                                final bool isGuest =
                                    currentUser == null ||
                                    currentUser.isAnonymous;

                                if (isGuest) {
                                  setState(() {
                                    _isCheckingOut = false;
                                  });

                                  _showGuestCheckoutPopup(
                                    context,
                                    widget.userId,
                                    subtotal,
                                    deliveryFee,
                                    selectedCartItems,
                                  );
                                  return;
                                }

                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CheckoutScreen(
                                      userId: widget.userId,
                                      subtotal: subtotal,
                                      deliveryFee: deliveryFee,
                                      cartItems: selectedCartItems,
                                      onOrderCompleted: () async {
                                        for (var item in selectedCartItems) {
                                          await _cartService.removeFromCart(
                                            userId: widget.userId,
                                            productId: item['productId'],
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                );

                                if (mounted) {
                                  setState(() {
                                    _isCheckingOut = false;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isCheckingOut
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                selectedCartItems.isEmpty
                                    ? 'Select Items to Checkout'
                                    : 'Proceed to Checkout',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

void _showGuestCheckoutPopup(
  BuildContext context,
  String userId,
  double subtotal,
  double deliveryFee,
  List<Map<String, dynamic>> cartItems,
) {
  final CartService cartService = CartService();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Checkout Options',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'You are browsing as a guest. How would you like to proceed?',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CheckoutScreen(
                      userId: userId,
                      subtotal: subtotal,
                      deliveryFee: deliveryFee,
                      cartItems: cartItems,
                      onOrderCompleted: () async {
                        for (var item in cartItems) {
                          await cartService.removeFromCart(
                            userId: userId,
                            productId: item['productId'],
                          );
                        }
                      },
                    ),
                  ),
                );
              },
              child: const Text(
                'Continue as Guest (One-Time Order)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const Login()),
                );
              },
              child: const Text('Login or Register'),
            ),
          ],
        ),
      );
    },
  );
}