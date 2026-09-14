import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAuth.instance.signInAnonymously();
  print('Signed in as ${FirebaseAuth.instance.currentUser?.uid} for seeding.');

  await seedSingleOrderProgress();
  print('Order progress seeded successfully!');
}

Future<void> seedSingleOrderProgress() async {
  const String userId = 'rdI5Y9LZubeioOBfaTCimQSkQDP2';
  const String orderId = 'XJhuwJVxu9tnzIspYPje';

  const bool isGuestOrder = false;

  await FirebaseFirestore.instance
      .collection('order_progress')
      .doc(userId)
      .collection('user_progress_items')
      .doc(orderId)
      .set({
        'orderId': orderId,
        'userId': userId,
        'isGuestOrder': isGuestOrder,
        'currentStatus': 'Out for Delivery',
        'progressSteps': [
          {
            'title': 'Order Placed',
            'subtitle': 'Your order has been logged in our system.',
            'timestamp': Timestamp.now(),
          },
          {
            'title': 'Payment Verified',
            'subtitle': 'Cash on Delivery option confirmed.',
            'timestamp': Timestamp.now(),
          },
          {
            'title': 'Order Dispatched',
            'subtitle': 'Your order has left our Lahore warehouse.',
            'timestamp': Timestamp.now(),
          },
          {
            'title': 'Arrived at Sorting Hub',
            'subtitle': 'Package arrived at the regional sorting facility.',
            'timestamp': Timestamp.now(),
          },
          {
            'title': 'Arrived at Local Hub',
            'subtitle': 'Package arrived at the local delivery hub near you.',
            'timestamp': Timestamp.now(),
          },
          
        
        ],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));


  await FirebaseFirestore.instance
      .collection('order_index')
      .doc(orderId)
      .set({'userId': userId}, SetOptions(merge: true));
}