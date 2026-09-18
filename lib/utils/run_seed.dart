import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  final String? imgBbApiKey = dotenv.env['IMGBB_API_KEY'];

  if (imgBbApiKey == null || imgBbApiKey.isEmpty) {
    print('Error: IMGBB_API_KEY is missing from the .env file!');
    return;
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('Connecting to Firestore...');
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final CollectionReference productsRef = firestore.collection('products');

  final List<Map<String, dynamic>> localProducts = [
    // --- FEATURED PRODUCTS ---
    {
      'id': 'prod-001',
      'name': 'Wireless Headphones',
      'description': 'Premium active noise-canceling over-ear headphones.',
      'price': 3000,
      'category': 'featured',
      'subCategory': 'headphones',
      'variants': [
        {'name': 'Matte Black', 'price': 3000},
        {'name': 'Silver Gray', 'price': 3200},
        {'name': 'Navy Blue', 'price': 3500},
      ],
      'imagePaths': [
        'assets/products/headphones.jpg',
        'assets/products/headphones1.jpg',
        'assets/products/headphones2.jpg',
      ],
    },
    {
      'id': 'prod-005',
      'name': 'DSLR Digital Camera',
      'description': '4K video recording with 24.2 MP sensor and kit lens.',
      'price': 250000,
      'category': 'featured',
      'subCategory': 'camera',
      'variants': [
        {'name': 'Body Only', 'price': 250000},
        {'name': '18-55mm Lens Kit', 'price': 280000},
        {'name': '50mm Prime Kit', 'price': 295000},
      ],
      'imagePaths': [
        'assets/products/camera.jpg',
        'assets/products/camera1.jpg',
        'assets/products/camera2.jpg',
      ],
    },
    {
      'id': 'prod-009',
      'name': 'Ultra Slim Laptop',
      'description': '14-inch display, 16GB RAM, 512GB SSD high performance.',
      'price': 150000,
      'category': 'featured',
      'subCategory': 'laptop',
      'variants': [
        {'name': '16GB / 512GB SSD', 'price': 150000},
        {'name': '16GB / 1TB SSD', 'price': 175000},
        {'name': '32GB / 1TB SSD', 'price': 200000},
      ],
      'imagePaths': [
        'assets/products/laptop.png',
        'assets/products/laptop1.png',
        'assets/products/laptop2.png',
      ],
    },
    {
      'id': 'prod-014',
      'name': 'Studio Monitor Headphones',
      'description': 'Professional audio monitoring headphones for producers.',
      'price': 50000,
      'category': 'featured',
      'subCategory': 'headphones',
      'variants': [
        {'name': 'Standard Edition', 'price': 50000},
        {'name': 'Studio Pro Edition', 'price': 58000},
      ],
      'imagePaths': [
        'assets/products/studio_headphones.jpg',
        'assets/products/studio_headphones1.jpg',
        'assets/products/studio_headphones2.jpg',
      ],
    },

    // --- BEST SELLING PRODUCTS ---
    {
      'id': 'prod-002',
      'name': 'Smart Watch Series 7',
      'description': 'Fitness tracker with heart rate monitor and AMOLED display.',
      'price': 2000,
      'category': 'best_selling',
      'subCategory': 'smartwatch',
      'variants': [
        {'name': '41mm - Silver', 'price': 2000},
        {'name': '45mm - Midnight Black', 'price': 2300},
        {'name': '45mm - Rose Gold', 'price': 2500},
      ],
      'imagePaths': [
        'assets/products/smartwatch.jpg',
        'assets/products/smartwatch1.jpg',
        'assets/products/smartwatch2.jpg',
      ],
    },
    {
      'id': 'prod-003',
      'name': 'Nike Air Running Shoes',
      'description': 'Lightweight and breathable athletic running sneakers.',
      'price': 25000,
      'category': 'best_selling',
      'subCategory': 'shoes',
      'variants': [
        {'name': 'US 8', 'price': 25000},
        {'name': 'US 9', 'price': 25000},
        {'name': 'US 10', 'price': 26000},
        {'name': 'US 11', 'price': 27000},
      ],
      'imagePaths': [
        'assets/products/shoes.jpg',
        'assets/products/shoes1.png',
        'assets/products/shoes2.png',
      ],
    },
    {
      'id': 'prod-007',
      'name': 'Pro Gaming Headset',
      'description': '7.1 Surround sound with noise-canceling microphone.',
      'price': 10000,
      'category': 'best_selling',
      'subCategory': 'headphones',
      'variants': [
        {'name': 'RGB Wired', 'price': 10000},
        {'name': 'Wireless Edition', 'price': 14000},
      ],
      'imagePaths': [
        'assets/products/gaming_headset.jpg',
        'assets/products/gaming_headset1.jpg',
        'assets/products/gaming_headset2.jpg',
      ],
    },
    {
      'id': 'prod-011',
      'name': 'Luxury EDP Perfume',
      'description': 'Long-lasting floral and woody fragrance 100ml.',
      'price': 9000,
      'category': 'best_selling',
      'subCategory': 'perfume',
      'variants': [
        {'name': '50ml Bottle', 'price': 7000},
        {'name': '100ml Bottle', 'price': 9000},
        {'name': '100ml + Travel Spray', 'price': 11000},
      ],
      'imagePaths': [
        'assets/products/perfume.png',
        'assets/products/perfume1.png',
        'assets/products/perfume2.png',
      ],
    },

    // --- POPULAR PRODUCTS ---
    {
      'id': 'prod-004',
      'name': 'Classic Leather Shoes',
      'description': 'Formal genuine leather shoes for men.',
      'price': 8000,
      'category': 'popular',
      'subCategory': 'shoes',
      'variants': [
        {'name': 'UK 7', 'price': 8000},
        {'name': 'UK 8', 'price': 8000},
        {'name': 'UK 9', 'price': 8500},
        {'name': 'UK 10', 'price': 9000},
      ],
      'imagePaths': [
        'assets/products/leather_shoes.jpg',
        'assets/products/leather_shoes1.png',
        'assets/products/leather_shoes2.png',
      ],
    },
    {
      'id': 'prod-006',
      'name': 'Classic Aviator Sunglasses',
      'description': 'UV400 protection polarized lenses with metal frame.',
      'price': 4000,
      'category': 'popular',
      'subCategory': 'sunglasses',
      'variants': [
        {'name': 'Gold / Green Lens', 'price': 4000},
        {'name': 'Silver / Blue Lens', 'price': 4200},
        {'name': 'Black / Smoke Lens', 'price': 4500},
      ],
      'imagePaths': [
        'assets/products/sunglasses.jpg',
        'assets/products/sunglasses1.jpg',
        'assets/products/sunglasses2.png',
      ],
    },
    {
      'id': 'prod-010',
      'name': 'Puma Classic Sneakers',
      'description': 'Iconic suede low-top sneakers with durable rubber outsole.',
      'price': 14000,
      'category': 'popular',
      'subCategory': 'shoes',
      'variants': [
        {'name': 'US 7.5', 'price': 14000},
        {'name': 'US 8.5', 'price': 14000},
        {'name': 'US 9.5', 'price': 14500},
        {'name': 'US 10.5', 'price': 15000},
      ],
      'imagePaths': [
        'assets/products/puma_sneakers.jpg',
        'assets/products/puma_sneakers1.png',
        'assets/products/puma_sneakers2.png',
      ],
    },
    {
      'id': 'prod-012',
      'name': 'Minimalist Wooden Stool',
      'description': 'Solid oak wood aesthetic seating for modern home decor.',
      'price': 7000,
      'category': 'popular',
      'subCategory': 'stool',
      'variants': [
        {'name': 'Natural Oak', 'price': 7000},
        {'name': 'Walnut Brown', 'price': 7500},
        {'name': 'Matte White', 'price': 7200},
      ],
      'imagePaths': [
        'assets/products/wooden_stool.jpg',
        'assets/products/wooden_stool1.jpg',
        'assets/products/wooden_stool2.jpg',
      ],
    },
    {
      'id': 'prod-013',
      'name': 'Sport Smartwatch Matte Black',
      'description': 'Waterproof IP68 watch with GPS tracking.',
      'price': 11000,
      'category': 'popular',
      'subCategory': 'smartwatch',
      'variants': [
        {'name': 'Silicone Strap', 'price': 11000},
        {'name': 'Nylon Loop Strap', 'price': 12500},
      ],
      'imagePaths': [
        'assets/products/black_watch.jpg',
        'assets/products/black_watch1.png',
        'assets/products/black_watch2.jpg',
      ],
    },
  ];

  final WriteBatch batch = firestore.batch();
  int addedCount = 0;
  int updatedCount = 0;

  for (var product in localProducts) {
    final String docId = product['id'];
    final DocumentReference docRef = productsRef.doc(docId);
    final DocumentSnapshot docSnapshot = await docRef.get();

    final List<String> currentImagePaths = List<String>.from(product['imagePaths']);
    final String newName = product['name'];
    final String newDescription = product['description'];
    final num newPrice = product['price'];
    final String newCategory = product['category'];
    final String newSubCategory = product['subCategory'];
    
    final List<Map<String, dynamic>> newVariants = 
        List<Map<String, dynamic>>.from(product['variants']);

    if (!docSnapshot.exists) {
      // --- CREATE NEW PRODUCT ---
      print('New product detected: "$newName" (ID: $docId). Uploading images...');
      List<String> uploadedUrls = [];
      for (String path in currentImagePaths) {
        final String? url = await uploadAssetToImgBB(path, imgBbApiKey);
        if (url != null) uploadedUrls.add(url);
      }

      batch.set(docRef, {
        'id': docId,
        'name': newName,
        'description': newDescription,
        'price': newPrice,
        'category': newCategory,
        'subCategory': newSubCategory,
        'variants': newVariants,
        'imageUrls': uploadedUrls,
        'localImagePaths': currentImagePaths,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      addedCount++;
    } else {
      // --- CHECK FOR UPDATES ---
      final data = docSnapshot.data() as Map<String, dynamic>;

      final String existingName = data['name'] ?? '';
      final String existingDescription = data['description'] ?? '';
      final num existingPrice = data['price'] ?? 0;
      final String existingCategory = data['category'] ?? '';
      final String existingSubCategory = data['subCategory'] ?? '';
      
      final List<dynamic> existingVariantsDynamic = data['variants'] ?? [];
      final List<Map<String, dynamic>> existingVariants = existingVariantsDynamic
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      
      final List<dynamic> existingLocalPaths = data['localImagePaths'] ?? [];
      
      bool imagesChanged = existingLocalPaths.length != currentImagePaths.length ||
          !List.generate(existingLocalPaths.length, (i) => existingLocalPaths[i] == currentImagePaths[i]).every((e) => e);

      // Deep comparison for variant name and price changes
      bool variantsChanged = existingVariants.length != newVariants.length;
      if (!variantsChanged) {
        for (int i = 0; i < existingVariants.length; i++) {
          if (existingVariants[i]['name'] != newVariants[i]['name'] ||
              existingVariants[i]['price'] != newVariants[i]['price']) {
            variantsChanged = true;
            break;
          }
        }
      }

      bool fieldsChanged = existingName != newName ||
          existingDescription != newDescription ||
          existingPrice != newPrice ||
          existingCategory != newCategory ||
          existingSubCategory != newSubCategory ||
          variantsChanged;

      if (fieldsChanged || imagesChanged) {
        print('Changes detected for "$newName" (ID: $docId). Updating...');

        List<String> finalImageUrls = [];
        if (imagesChanged) {
          print('Image change detected for "$newName". Re-uploading to ImgBB...');
          for (String path in currentImagePaths) {
            final String? url = await uploadAssetToImgBB(path, imgBbApiKey);
            if (url != null) finalImageUrls.add(url);
          }
        } else {
          finalImageUrls = List<String>.from(data['imageUrls'] ?? []);
        }

        batch.update(docRef, {
          'name': newName,
          'description': newDescription,
          'price': newPrice,
          'category': newCategory,
          'subCategory': newSubCategory,
          'variants': newVariants,
          'imageUrls': finalImageUrls,
          'localImagePaths': currentImagePaths,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        updatedCount++;
      } else {
        print('No changes for "$newName" (ID: $docId). Skipping.');
      }
    }
  }

  if (addedCount > 0 || updatedCount > 0) {
    await batch.commit();
    print('\nSync complete! Added $addedCount new product(s) and updated $updatedCount product(s) in Firestore.');
  } else {
    print('\nNo new products or updates found. Everything is up to date!');
  }
}

/// Reads asset bundle bytes and uploads to ImgBB
Future<String?> uploadAssetToImgBB(String assetPath, String apiKey) async {
  try {
    final ByteData byteData = await rootBundle.load(assetPath);
    final Uint8List imageBytes = byteData.buffer.asUint8List();
    final String base64Image = base64Encode(imageBytes);

    final response = await http.post(
      Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey'),
      body: {'image': base64Image},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['url'];
    } else {
      print('ImgBB API Error: ${response.body}');
    }
  } catch (e) {
    print('Exception during asset upload ($assetPath): $e');
  }
  return null;
}