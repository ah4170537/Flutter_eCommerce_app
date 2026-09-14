import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import 'dashboard.dart'; 
import 'cart_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final String userId;
  final int initialIndex; 

  const MainNavigationScreen({
    super.key, 
    required this.userId,
    this.initialIndex = 0, 
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex; 
    _screens = [
      Dashboard(userId: widget.userId),
      CartScreen(userId: widget.userId),
      OrdersScreen(userId: widget.userId),
      ProfileScreen(userId: widget.userId),
    ];
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('cart')
                  .doc(widget.userId)
                  .collection('user_cart')
                  .snapshots(),
              builder: (context, snapshot) {
                int cartCount = 0;
                if (snapshot.hasData) {
                  cartCount = snapshot.data!.docs.length;
                }

                return GNav(
                  backgroundColor: AppColors.white,
                  color: AppColors.textGrey,
                  activeColor: AppColors.primaryDark,
                  tabBackgroundColor: AppColors.primaryDark.withValues(alpha: 0.1),
                  gap: 8,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  selectedIndex: _currentIndex,
                  onTabChange: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  tabs: [
                    const GButton(
                      icon: Icons.home_rounded,
                      text: 'Home',
                    ),
                    GButton(
                    
                      icon: Icons.shopping_cart_rounded, 
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.shopping_cart_rounded,
                            color: Colors.grey, 
                            size: 24,
                          ),
                          if (cartCount > 0)
                            Positioned(
                              right: -4,
                              top: -4,
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
                      text: 'Cart',
                    ),
                    const GButton(
                      icon: Icons.receipt_long_rounded,
                      text: 'Orders',
                    ),
                    const GButton(
                      icon: Icons.person_rounded,
                      text: 'Profile',
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}