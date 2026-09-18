import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../pages/all_reviews_screen.dart'; // Isko agle step mein banayenge

class ProductReviewsSection extends StatelessWidget {
  final String productId;

  const ProductReviewsSection({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('reviews').doc(productId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No reviews yet for this product.'),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final List<dynamic> allReviews = data['reviews'] ?? [];

        if (allReviews.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No reviews yet.'),
          );
        }

     
        final displayReviews = allReviews.take(3).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Customer Reviews',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AllReviewsScreen(productId: productId),
                        ),
                      );
                    },
                    child: const Text('See All Reviews'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 3 reviews ki list
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayReviews.length,
                itemBuilder: (context, index) {
                  final review = displayReviews[index];
                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 10.0),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                review['userName'] ?? 'Anonymous',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: List.generate(
                                  5,
                                  (starIndex) => Icon(
                                    starIndex < (review['rating'] ?? 0)
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(review['comment'] ?? ''),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              review['createdAt'] ?? '',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}