import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primaryDark,
        scrolledUnderElevation: 0,
      ),
      body: Center(
        child: Text(
          'User Profile Screen (ID: $userId)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textGrey),
        ),
      ),
    );
  }
}