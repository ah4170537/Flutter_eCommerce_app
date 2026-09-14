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

class ProductDetailsScreen extends StatefulWidget {
  final String productId;

  const ProductDetailsScreen({super.key, required this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final CartService _cartService = CartService();
  int _selectedQuantity =
      1; // Sirf variable rakha hai, setState ki zaroorat nahi
  late final Stream<DocumentSnapshot> _productStream;
  final ValueNotifier<bool> _isAddingToCart = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _productStream = FirebaseFirestore.instance
        .collection(AppStrings.productsCollection)
        .doc(widget.productId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: _productStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primaryDark),
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

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final String name =
                data[AppStrings.nameField] ?? AppStrings.defaultProductName;
            final num price = data[AppStrings.priceField] ?? 0;

            final List<dynamic> imageUrlsList = (data['imageUrls'] is List)
                ? data['imageUrls']
                : [];

            final List<String> effectiveImages = imageUrlsList.isNotEmpty
                ? imageUrlsList.map((e) => e.toString()).toList()
                : [data[AppStrings.imageUrlField]?.toString() ?? '']
                      .where((s) => s.isNotEmpty)
                      .toList();

            final String description =
                data['description'] ??
                'No description available for this product.';
            final String subCategory = data['subCategory'] ?? '';

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
                      backgroundColor: Colors.black.withValues(alpha: 0.4),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
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
                    transform: Matrix4.translationValues(0.0, -20.0, 0.0),
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
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: AppTextStyles.brandTitle.copyWith(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                              Text(
                                'PKR $price',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
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
                              // Still loading — show a neutral placeholder, not "New" or "0 reviews"
                              if (reviewSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: Colors.amber.withValues(
                                        alpha: 0.3,
                                      ),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 60,
                                      height: 12,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }

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
                                  final double totalRating = reviewsList.fold(
                                    0.0,
                                    (sum, review) {
                                      final r =
                                          (review
                                              as Map<
                                                String,
                                                dynamic
                                              >)['rating'] ??
                                          0;
                                      return sum + (r as num).toDouble();
                                    },
                                  );
                                  avgRating = totalRating / reviewCount;
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

                          // Yahan setState hata kar sirf variable update kiya hai
                          QuantitySelector(
                            initialQuantity: _selectedQuantity,
                            onChanged: (newQuantity) {
                              _selectedQuantity =
                                  newQuantity; // No setState here!
                            },
                          ),
                          const SizedBox(height: 24),

                          RecommendedProductsSection(
                            subCategory: subCategory,
                            currentProductId: widget.productId,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                onPressed: () => showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => WriteReviewSheet(
                                    productId: widget.productId,
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

                          ProductReviewsSection(productId: widget.productId),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
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
          child: ValueListenableBuilder<bool>(
            valueListenable: _isAddingToCart,
            builder: (context, isAdding, child) {
              return ElevatedButton(
                onPressed: isAdding
                    ? null
                    : () async {
                        _isAddingToCart.value = true;

                        try {
                          final User? user = FirebaseAuth.instance.currentUser;
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
                          final List<dynamic> imageUrlsList =
                              data['imageUrls'] ?? [];

                          final List<String> effectiveImages =
                              imageUrlsList.isNotEmpty
                              ? imageUrlsList.map((e) => e.toString()).toList()
                              : [
                                  data[AppStrings.imageUrlField]?.toString() ??
                                      '',
                                ].where((s) => s.isNotEmpty).toList();

                          final String cartImageUrl = effectiveImages.isNotEmpty
                              ? effectiveImages[0]
                              : '';

                          await _cartService.addToCart(
                            userId: userId,
                            productId: widget.productId,
                            name:
                                data[AppStrings.nameField] ??
                                AppStrings.defaultProductName,
                            price: data[AppStrings.priceField] ?? 0,
                            imageUrl: cartImageUrl,
                            quantity: _selectedQuantity,
                          );

                          if (!mounted) return;

                          // Show success snackbar instead of pushing CartScreen
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
                          _isAddingToCart.value = false;
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
                child: isAdding
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
              );
            },
          ),
        ),
      ),
    );
  }
}
