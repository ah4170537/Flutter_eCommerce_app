import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../pages/main_navigation_screen.dart';
import '../services/auth_service.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final User user = snapshot.data!;
       
          return MainNavigationScreen(userId: user.uid);
        }

        return const _GuestBootstrapper();
      },
    );
  }
}

class _GuestBootstrapper extends StatefulWidget {
  const _GuestBootstrapper();

  @override
  State<_GuestBootstrapper> createState() => _GuestBootstrapperState();
}

class _GuestBootstrapperState extends State<_GuestBootstrapper> {
  @override
  void initState() {
    super.initState();
    _signInAsGuestWhenSafe();
  }

  Future<void> _signInAsGuestWhenSafe() async {
 
    int safetyCounter = 0;
    while (AuthService.isAuthTransitionInProgress && safetyCounter < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      safetyCounter++;
    }

    if (!mounted) return;

  
    if (FirebaseAuth.instance.currentUser != null) return;

    try {
      await FirebaseAuth.instance.signInAnonymously();
   
    } catch (e) {
   
      debugPrint('Anonymous sign-in failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}