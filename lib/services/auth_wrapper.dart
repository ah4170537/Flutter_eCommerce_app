import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../pages/main_navigation_screen.dart';
import '../pages/login.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show a clean loading screen only while Firebase is initially resolving the connection state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryDark),
            ),
          );
        }

        // 1. If the user explicitly logged out, respect it and show the Login screen[cite: 2]
        if (AuthService.manualLogoutOccurred) {
          return const Login();
        }

        // 2. If there is already an active user session (logged-in user or previous guest), show dashboard immediately[cite: 2]
        if (snapshot.hasData && snapshot.data != null) {
          // Save token to ensure it stays fresh on active runs
          AuthService.instance.saveFCMToken(snapshot.data!.uid);
          return MainNavigationScreen(userId: snapshot.data!.uid);
        }

        // 3. True cold start with no session: trigger anonymous sign-in in the background[cite: 2]
        // while displaying the blank loading scaffold so no login screen ever flashes.[cite: 2]
        _ensureGuestSession();

        return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primaryDark),
          ),
        );
      },
    );
  }

  void _ensureGuestSession() async {
    if (FirebaseAuth.instance.currentUser == null && !AuthService.manualLogoutOccurred) {
      try {
        UserCredential credential = await FirebaseAuth.instance.signInAnonymously();
        if (credential.user != null) {
          await AuthService.instance.saveFCMToken(credential.user!.uid);
        }
      } catch (e) {
        debugPrint('Anonymous sign-in failed: $e');
      }
    }
  }
}