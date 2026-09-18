import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AllReviewsScreen extends StatelessWidget {
  final String productId;

  const AllReviewsScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('All Reviews'),
      ),
      body:
       StreamBuilder<DocumentSnapshot>(
        
     
        stream: FirebaseFirestore.instance.collection('reviews').doc(productId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('No reviews found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final List<dynamic> reviews = data?['reviews'] ?? [];

          if (reviews.isEmpty) {
            return const Center(child: Text('No reviews available.'));
          }

          return ListView.builder(
            
            padding: const EdgeInsets.all(16.0),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];
              return Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12.0),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                      const SizedBox(height: 8),
                      Text(review['comment'] ?? ''),
                      const SizedBox(height: 6),
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
          );
        },
      ),
    );
  }
}