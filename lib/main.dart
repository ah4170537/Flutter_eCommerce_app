import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'pages/main_navigation_screen.dart';
import 'pages/login.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  
  if (FirebaseAuth.instance.currentUser == null) {
    FirebaseAuth.instance.signInAnonymously().catchError((e) {
      debugPrint('Background anonymous sign-in error: $e');
    });
  }

  // 4. Launch the app immediately
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Your App Name',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Show loading only if connection is actively waiting
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final User? user = snapshot.data;
          
          // If user is logged in (Guest or Real user), show main navigation
          if (user != null) {
            return MainNavigationScreen(userId: user.uid);
          }

          // If logged out (user is null), show your Login Screen
          return const Login();
        },
      ),
    );
  }
}