import 'package:authentication_module/pages/cart_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/product_review_section.dart';
import '../constants/app_strings.dart';
import '../services/cart_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/quantity_selector.dart';
import 'recommended_products_section.dart';
import 'product_image_slider.dart';
import '../widgets/write_review_sheet.dart';
import 'main_navigation_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String productId;

  const ProductDetailsScreen({super.key, required this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final CartService _cartService = CartService();

  int _selectedQuantity = 1;

  // Stores the currently selected variant name.
  final ValueNotifier<String?> _selectedVariantNotifier =
      ValueNotifier<String?>(null);

  // Use a ValueNotifier for part quantities to prevent full-page refreshes
  final ValueNotifier<Map<String, int>> _partQuantitiesNotifier =
      ValueNotifier<Map<String, int>>({});

  late final Stream<DocumentSnapshot> _productStream;

  // Unified loading notifier to lock all buttons when any action is running
  final ValueNotifier<bool> _isActionInProgress = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();

    _productStream = FirebaseFirestore.instance
        .collection(AppStrings.productsCollection)
        .doc(widget.productId)
        .snapshots();
  }

  @override
  void dispose() {
    _selectedVariantNotifier.dispose();
    _partQuantitiesNotifier.dispose();
    _isActionInProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return ValueListenableBuilder<bool>(
      valueListenable: _isActionInProgress,
      builder: (context, isBusy, child) {
        return WillPopScope(
          onWillPop: () async => !isBusy,
          child: Scaffold(
            backgroundColor: AppColors.white,
            body: SafeArea(
              child: Stack(
                children: [
                  StreamBuilder<DocumentSnapshot>(
                    stream: _productStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryDark,
                          ),
                        );
                      }

                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          !snapshot.data!.exists) {
                        return Scaffold(
                          appBar: AppBar(title: const Text('Error')),
                          body: const Center(child: Text('Product not found.')),
                        );
                      }

                      final data =
                          snapshot.data!.data() as Map<String, dynamic>;

                      final String name =
                          data[AppStrings.nameField] ??
                          AppStrings.defaultProductName;

                      final num productPrice = data[AppStrings.priceField] ?? 0;

                      final List<dynamic> imageUrlsList =
                          (data['imageUrls'] is List) ? data['imageUrls'] : [];

                      final List<String> effectiveImages =
                          imageUrlsList.isNotEmpty
                          ? imageUrlsList.map((e) => e.toString()).toList()
                          : [data[AppStrings.imageUrlField]?.toString() ?? '']
                                .where((s) => s.isNotEmpty)
                                .toList();

                      final String description =
                          data['description'] ??
                          'No description available for this product.';

                      final String subCategory = data['subCategory'] ?? '';

                      final List<dynamic> variantsDynamic =
                          data['variants'] is List ? data['variants'] : [];

                      final List<Map<String, dynamic>> variants = [];

                      for (final variant in variantsDynamic) {
                        if (variant is Map) {
                          variants.add(Map<String, dynamic>.from(variant));
                        }
                      }
                      if (variants.isNotEmpty) {
                        final bool currentVariantStillExists =
                            _selectedVariantNotifier.value != null &&
                            variants.any(
                              (variant) =>
                                  variant['name']?.toString() ==
                                  _selectedVariantNotifier.value,
                            );

                        if (!currentVariantStillExists) {
                          _selectedVariantNotifier.value = variants
                              .first['name']
                              ?.toString();
                        }
                      } else {
                        _selectedVariantNotifier.value = null;
                      }

                      // Parse components/parts if available
                      final List<dynamic> partsDynamic = data['parts'] is List
                          ? data['parts']
                          : [];

                      final List<Map<String, dynamic>> parts = [];
                      for (final part in partsDynamic) {
                        if (part is Map) {
                          final partMap = Map<String, dynamic>.from(part);
                          parts.add(partMap);

                          // Initialize part quantity to 0 if not already present
                          final String partName = partMap['partName'] ?? 'Part';
                          if (!_partQuantitiesNotifier.value.containsKey(
                            partName,
                          )) {
                            final currentMap = Map<String, int>.from(
                              _partQuantitiesNotifier.value,
                            );
                            currentMap[partName] = 0;
                            _partQuantitiesNotifier.value = currentMap;
                          }
                        }
                      }

                      final bool hasPartsList = parts.isNotEmpty;

                      return CustomScrollView(
                        slivers: [
                          SliverAppBar(
                            expandedHeight: 320,
                            pinned: true,
                            scrolledUnderElevation: 0,
                            backgroundColor: AppColors.white,
                            automaticallyImplyLeading: false,
                            leading: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: CircleAvatar(
                                backgroundColor: Colors.black.withValues(
                                  alpha: 0.4,
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: isBusy
                                      ? null
                                      : () => Navigator.pop(context),
                                ),
                              ),
                            ),
                            flexibleSpace: FlexibleSpaceBar(
                              background: ProductImageSlider(
                                effectiveImages: effectiveImages,
                              ),
                            ),
                          ),

                          SliverToBoxAdapter(
                            child: Container(
                              transform: Matrix4.translationValues(
                                0.0,
                                -20.0,
                                0.0,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(28),
                                  topRight: Radius.circular(28),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: Container(
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 20),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: AppTextStyles.brandTitle
                                                .copyWith(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primaryDark,
                                                ),
                                          ),
                                        ),

                                        ValueListenableBuilder<String?>(
                                          valueListenable:
                                              _selectedVariantNotifier,
                                          builder:
                                              (
                                                context,
                                                selectedVariantName,
                                                child,
                                              ) {
                                                num displayedPrice =
                                                    productPrice;

                                                if (selectedVariantName !=
                                                        null &&
                                                    variants.isNotEmpty) {
                                                  final Map<String, dynamic>?
                                                  selectedVariant = variants
                                                      .cast<
                                                        Map<String, dynamic>?
                                                      >()
                                                      .firstWhere(
                                                        (variant) =>
                                                            variant?['name']
                                                                ?.toString() ==
                                                            selectedVariantName,
                                                        orElse: () => null,
                                                      );

                                                  if (selectedVariant != null) {
                                                    displayedPrice =
                                                        selectedVariant['price'] ??
                                                        productPrice;
                                                  }
                                                }

                                                return Text(
                                                  'PKR $displayedPrice',
                                                  style: const TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green,
                                                  ),
                                                );
                                              },
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    StreamBuilder<DocumentSnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('reviews')
                                          .doc(widget.productId)
                                          .snapshots(),
                                      builder: (context, reviewSnapshot) {
                                        double avgRating = 0;
                                        int reviewCount = 0;

                                        if (reviewSnapshot.hasData &&
                                            reviewSnapshot.data!.exists) {
                                          final reviewData =
                                              reviewSnapshot.data!.data()
                                                  as Map<String, dynamic>?;

                                          final List<dynamic> reviewsList =
                                              reviewData?['reviews'] ?? [];

                                          reviewCount = reviewsList.length;

                                          if (reviewCount > 0) {
                                            final double totalRating =
                                                reviewsList.fold(0.0, (
                                                  sum,
                                                  review,
                                                ) {
                                                  final r =
                                                      (review
                                                          as Map<
                                                            String,
                                                            dynamic
                                                          >)['rating'] ??
                                                      0;

                                                  return sum +
                                                      (r as num).toDouble();
                                                });

                                            avgRating =
                                                totalRating / reviewCount;
                                          }
                                        }

                                        return Row(
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              color: Colors.amber,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              reviewCount > 0
                                                  ? avgRating.toStringAsFixed(1)
                                                  : 'New',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '($reviewCount reviews)',
                                              style: const TextStyle(
                                                color: AppColors.textGrey,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),

                                    if (variants.isNotEmpty) ...[
                                      const SizedBox(height: 20),
                                      const Text(
                                        'Select Option / Variant',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      ValueListenableBuilder<String?>(
                                        valueListenable:
                                            _selectedVariantNotifier,
                                        builder:
                                            (
                                              context,
                                              currentSelectedVariant,
                                              child,
                                            ) {
                                              return Wrap(
                                                spacing: 8.0,
                                                runSpacing: 4.0,
                                                children: variants.map((
                                                  variant,
                                                ) {
                                                  final String variantName =
                                                      variant['name']
                                                          ?.toString() ??
                                                      '';

                                                  final bool isSelected =
                                                      currentSelectedVariant ==
                                                      variantName;

                                                  return ChoiceChip(
                                                    label: Text(variantName),
                                                    selected: isSelected,
                                                    selectedColor:
                                                        AppColors.primaryDark,
                                                    labelStyle: TextStyle(
                                                      color: isSelected
                                                          ? Colors.white
                                                          : AppColors
                                                                .primaryDark,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    backgroundColor:
                                                        Colors.grey.shade100,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      side: BorderSide(
                                                        color: isSelected
                                                            ? AppColors
                                                                  .primaryDark
                                                            : Colors
                                                                  .grey
                                                                  .shade300,
                                                      ),
                                                    ),
                                                    onSelected: isBusy
                                                        ? null
                                                        : (selected) {
                                                            if (selected) {
                                                              _selectedVariantNotifier
                                                                      .value =
                                                                  variantName;
                                                            }
                                                          },
                                                  );
                                                }).toList(),
                                              );
                                            },
                                      ),
                                    ],

                                    // COMPONENTS & PARTS LIST WITH VALUE NOTIFIER
                                    if (hasPartsList) ...[
                                      const SizedBox(height: 20),
                                      const Text(
                                        'Components & Parts Included',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      ValueListenableBuilder<Map<String, int>>(
                                        valueListenable:
                                            _partQuantitiesNotifier,
                                        builder: (context, partQuantities, child) {
                                          return ListView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            itemCount: parts.length,
                                            itemBuilder: (context, index) {
                                              final part = parts[index];
                                              final String partName =
                                                  part['partName'] ?? 'Part';
                                              final String specs =
                                                  part['specs'] ?? '';
                                              final num partPrice =
                                                  part['price'] ?? 0;
                                              final int currentPartQty =
                                                  partQuantities[partName] ?? 0;

                                              return Container(
                                                margin: const EdgeInsets.only(
                                                  bottom: 8.0,
                                                ),
                                                padding: const EdgeInsets.all(
                                                  12.0,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.grey.shade200,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            partName,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14,
                                                                  color: AppColors
                                                                      .textDark,
                                                                ),
                                                          ),
                                                          if (specs
                                                              .isNotEmpty) ...[
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Text(
                                                              specs,
                                                              style: const TextStyle(
                                                                fontSize: 12,
                                                                color: AppColors
                                                                    .textGrey,
                                                              ),
                                                            ),
                                                          ],
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            'PKR $partPrice each',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .green,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Row(
                                                      children: [
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons
                                                                .remove_circle_outline,
                                                            size: 20,
                                                          ),
                                                          color: AppColors
                                                              .primaryDark,
                                                          onPressed:
                                                              isBusy ||
                                                                  currentPartQty <=
                                                                      0
                                                              ? null
                                                              : () {
                                                                  final updatedMap =
                                                                      Map<
                                                                        String,
                                                                        int
                                                                      >.from(
                                                                        _partQuantitiesNotifier
                                                                            .value,
                                                                      );
                                                                  updatedMap[partName] =
                                                                      currentPartQty -
                                                                      1;
                                                                  _partQuantitiesNotifier
                                                                          .value =
                                                                      updatedMap;
                                                                },
                                                        ),
                                                        Text(
                                                          '$currentPartQty',
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 14,
                                                              ),
                                                        ),
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons
                                                                .add_circle_outline,
                                                            size: 20,
                                                          ),
                                                          color: AppColors
                                                              .primaryDark,
                                                          onPressed: isBusy
                                                              ? null
                                                              : () {
                                                                  final updatedMap =
                                                                      Map<
                                                                        String,
                                                                        int
                                                                      >.from(
                                                                        _partQuantitiesNotifier
                                                                            .value,
                                                                      );
                                                                  updatedMap[partName] =
                                                                      currentPartQty +
                                                                      1;
                                                                  _partQuantitiesNotifier
                                                                          .value =
                                                                      updatedMap;
                                                                },
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ],

                                    if (!hasPartsList) ...[
                                      const SizedBox(height: 20),
                                      QuantitySelector(
                                        initialQuantity: _selectedQuantity,
                                        onChanged: (newQty) {
                                          setState(() {
                                            _selectedQuantity = newQty;
                                          });
                                        },
                                      ),
                                    ],

                                    const SizedBox(height: 24),
                                    const Text(
                                      'Description',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      description,
                                      style: const TextStyle(
                                        color: AppColors.textGrey,
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    RecommendedProductsSection(
                                      subCategory: subCategory,
                                      currentProductId: widget.productId,
                                    ),
                                    const SizedBox(height: 24),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Reviews',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: isBusy
                                              ? null
                                              : () => showModalBottomSheet(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  builder: (_) =>
                                                      WriteReviewSheet(
                                                        productId:
                                                            widget.productId,
                                                      ),
                                                ),
                                          icon: const Icon(
                                            Icons.rate_review_outlined,
                                            size: 18,
                                          ),
                                          label: const Text('Write a Review'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ProductReviewsSection(
                                      productId: widget.productId,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  Positioned(
                    top: 12,
                    right: 16,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('cart')
                          .doc(currentUserId)
                          .collection('user_cart')
                          .snapshots(),
                      builder: (context, snapshot) {
                        int cartCount = 0;

                        if (snapshot.hasData) {
                          for (var doc in snapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final num quantity = data['quantity'] ?? 1;
                            cartCount += quantity.toInt();
                          }
                        }

                        return CircleAvatar(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                          child: IconButton(
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(
                                  Icons.shopping_cart_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                if (cartCount > 0)
                                  Positioned(
                                    right: -6,
                                    top: -6,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Text(
                                        '$cartCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            onPressed: isBusy
                                ? null
                                : () {
                                    if (currentUserId.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              CartScreen(userId: currentUserId),
                                        ),
                                      );
                                    }
                                  },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            bottomNavigationBar: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16.0),
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
                child: ElevatedButton(
                  onPressed: isBusy
                      ? null
                      : () async {
                          _isActionInProgress.value = true;

                          try {
                            final User? user =
                                FirebaseAuth.instance.currentUser;
                            final String userId = user?.uid ?? '';

                            if (userId.isEmpty) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Error: User not logged in'),
                                  ),
                                );
                              }
                              return;
                            }

                            final docSnapshot = await FirebaseFirestore.instance
                                .collection(AppStrings.productsCollection)
                                .doc(widget.productId)
                                .get();

                            if (!docSnapshot.exists) {
                              return;
                            }

                            final data =
                                docSnapshot.data() as Map<String, dynamic>;

                            final List<dynamic> partsDynamic =
                                data['parts'] is List ? data['parts'] : [];
                            final bool hasPartsList = partsDynamic.isNotEmpty;

                            final List<Map<String, dynamic>> finalPartsList =
                                [];
                            if (hasPartsList) {
                              for (final part in partsDynamic) {
                                if (part is Map) {
                                  final partMap = Map<String, dynamic>.from(
                                    part,
                                  );
                                  final String partName =
                                      partMap['partName'] ?? 'Part';
                                  final int partQty =
                                      _partQuantitiesNotifier.value[partName] ??
                                      0;

                                  // Only include parts with quantity greater than 0
                                  if (partQty > 0) {
                                    finalPartsList.add({
                                      'partName': partName,
                                      'specs': partMap['specs'] ?? '',
                                      'price': partMap['price'] ?? 0,
                                      'quantity': partQty,
                                    });
                                  }
                                }
                              }
                            }

                            // -------------------------------------------------------------
                            // VALIDATION CHECK FOR PARTS
                            // -------------------------------------------------------------
                            if (hasPartsList && finalPartsList.isEmpty) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select at least one part or component.',
                                    ),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                              _isActionInProgress.value = false;
                              return;
                            }
                            // -------------------------------------------------------------

                            final cartDocRef = FirebaseFirestore.instance
                                .collection('cart')
                                .doc(userId)
                                .collection('user_cart')
                                .doc(widget.productId);

                            final List<dynamic> imageUrlsList =
                                data['imageUrls'] ?? [];

                            final List<String> effectiveImages =
                                imageUrlsList.isNotEmpty
                                ? imageUrlsList
                                      .map((e) => e.toString())
                                      .toList()
                                : [
                                    data[AppStrings.imageUrlField]
                                            ?.toString() ??
                                        '',
                                  ].where((s) => s.isNotEmpty).toList();

                            final String cartImageUrl =
                                effectiveImages.isNotEmpty
                                ? effectiveImages[0]
                                : '';

                            final String? chosenVariant =
                                _selectedVariantNotifier.value;

                            num selectedVariantPrice =
                                data[AppStrings.priceField] ?? 0;

                            final List<dynamic> variantsDynamic =
                                data['variants'] is List
                                ? data['variants']
                                : [];

                            for (final variant in variantsDynamic) {
                              if (variant is Map) {
                                final String variantName =
                                    variant['name']?.toString() ?? '';

                                if (variantName == chosenVariant) {
                                  selectedVariantPrice = variant['price'] ?? 0;
                                  break;
                                }
                              }
                            }

                            await cartDocRef.set({
                              'productId': widget.productId,
                              'name':
                                  data[AppStrings.nameField] ??
                                  AppStrings.defaultProductName,
                              'price': selectedVariantPrice,
                              'imageUrl': cartImageUrl,
                              'quantity': hasPartsList ? 1 : _selectedQuantity,
                              'variant': chosenVariant,
                              if (hasPartsList) 'parts': finalPartsList,
                              'updatedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Added to cart successfully!'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to add to cart: $e'),
                              ),
                            );
                          } finally {
                            if (mounted) {
                              _isActionInProgress.value = false;
                            }
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
                  child: isBusy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Add to Cart',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
