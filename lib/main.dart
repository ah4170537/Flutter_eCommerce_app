import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'pages/login.dart';
import 'pages/main_navigation_screen.dart';
import 'services/auth_service.dart'; // Ensure you import your auth service for manualLogoutOccurred

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  debugPrint('Loaded API Key: ${dotenv.env['GOOGLE_API_KEY']}');

  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cartify',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const RootInitializer(),
    );
  }
}

/// A dedicated widget to handle cold start vs logout state safely without race conditions
class RootInitializer extends StatefulWidget {
  const RootInitializer({super.key});

  @override
  State<RootInitializer> createState() => _RootInitializerState();
}

class _RootInitializerState extends State<RootInitializer> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeAppState();
  }

  Future<void> _initializeAppState() async {

    if (AuthService.manualLogoutOccurred) {
      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (e) {
        debugPrint('Cold start anonymous sign-in error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        // Show a blank loading screen while the cold-start guest check finishes
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (AuthService.manualLogoutOccurred) {
              return const Login();
            }
            final User? user = authSnapshot.data;
            if (user != null) {
              return MainNavigationScreen(userId: user.uid);
            }
            return const Login();
          },
        );
      },
    );
  }
}