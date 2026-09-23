import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/login.dart';
import 'pages/main_navigation_screen.dart';
import 'services/auth_service.dart';
import 'role_selection/role_selection_screen.dart';
import 'rider_app/rider_home_screen.dart';

// Top-level function to handle background FCM messages when app is terminated/backgrounded
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  debugPrint('Loaded API Key: ${dotenv.env['GOOGLE_API_KEY']}');

  await Firebase.initializeApp();

  // Register background messaging handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Check onboarding status and saved role prior to launching app
  final prefs = await SharedPreferences.getInstance();
  final bool hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;
  final String? savedRole = prefs.getString('selectedRole');

  Widget initialScreen;
  if (!hasCompletedOnboarding) {
    initialScreen = const RoleSelectionScreen();
  } else if (savedRole == 'rider') {
    initialScreen = const RiderHomeScreen();
  } else {
    initialScreen = const RootInitializer();
  }

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget? initialScreen;
  const MyApp({super.key, this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cartify',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: initialScreen ?? const RoleSelectionScreen(),
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
    } else {
      // Request permissions and save token if user is already authenticated
      await _setupFCMToken(FirebaseAuth.instance.currentUser!.uid);
    }
  }

  // Helper method to request notification permissions and sync FCM token to Firestore
  Future<void> _setupFCMToken(String userId) async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        if (token != null) {
          // Save the token inside the user's Firestore document so your Cloud Function can target them
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'fcmToken': token,
          }, SetOptions(merge: true));
          debugPrint("FCM Token saved successfully: $token");
        }
      } else {
        debugPrint('User declined or has not accepted permission');
      }
    } catch (e) {
      debugPrint("Error setting up FCM token: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
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
              // Trigger FCM token saving whenever the user session is active
              _setupFCMToken(user.uid);
              return MainNavigationScreen(userId: user.uid);
            }
            return const Login();
          },
        );
      },
    );
  }
}