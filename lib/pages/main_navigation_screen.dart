import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
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
    // Prevent Firestore crash if userId is empty
    if (widget.userId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // PopScope intercepts the mobile hardware back button
    return PopScope(
      canPop: false, // We manually control back button behavior
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_currentIndex != 0) {
          // If we are on any other tab, pressing back switches us back to Dashboard
          setState(() {
            _currentIndex = 0;
          });
        } else {
          // If we are on the Dashboard, show a visually appealing exit confirmation popup
          final bool? shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.exit_to_app_rounded,
                    color: AppColors.primaryDark,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Close App',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: const Text(
                'Are you sure you want to exit the application?',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Exit',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );

          // If user clicked 'Exit', close the app gracefully
          if (shouldExit == true) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
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
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final num quantity = data['quantity'] ?? 1;
                      cartCount += quantity.toInt();
                    }
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
      ),
    );
  }
}