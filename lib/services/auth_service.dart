import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  static bool isAuthTransitionInProgress = false;
  static bool manualLogoutOccurred = false;
  static bool isInitialized = false;

  // EmailJS Credentials
  static const String _emailJsServiceId = 'service_3a778zs';
  static const String _emailJsTemplateId = 'template_n4ykzgf';
  static const String _emailJsPublicKey = 'xLJyWo6CV8LvFq26t';

  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? country,
    String? state,
    String? city,
    String? address,
  }) async {
    isAuthTransitionInProgress = true;
    try {
      final trimmedEmail = email.trim().toLowerCase();
      final trimmedName = name.trim();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      if (credential.user != null) {
        // 1. Update Firebase Auth Display Name
        await credential.user!.updateDisplayName(trimmedName);

        try {
          await _firestore.collection('users').doc(credential.user!.uid).set({
            'uid': credential.user!.uid,
            'name': trimmedName,
            'email': trimmedEmail,
            if (phone != null) 'phone': phone.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            if (phone != null || address != null || city != null || state != null || country != null)
              'shippingAddress': {
                'email': trimmedEmail,
                if (phone != null) 'phone': phone.trim(),
                'secondaryPhone': '',
                'postalCode': '',
                if (address != null) 'address': address.trim(),
                if (city != null) 'city': city.trim(),
                if (state != null) 'state': state.trim(),
                if (country != null) 'country': country.trim(),
              },
          });
        } catch (_) {}
      }

      return credential;
    } finally {
      isAuthTransitionInProgress = false;
    }
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    isAuthTransitionInProgress = true;
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } finally {
      isAuthTransitionInProgress = false;
    }
  }
 
  Future<void> signOut() async {
    manualLogoutOccurred = true;
    isAuthTransitionInProgress = true;
    try {
      await _auth.signOut();
    } finally {
      isAuthTransitionInProgress = false;
    }
  }
 

  Future<bool> checkEmailExists(String email) async {
    final trimmedEmail = email.trim().toLowerCase();

    try {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: trimmedEmail)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Save or update user checkout details under their user document subcollection
  Future<void> saveCheckoutDetails({
    required String userId,
    required Map<String, dynamic> checkoutData,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('checkout_details')
        .doc('saved_info')
        .set({
      ...checkoutData,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetch saved checkout details for pre-filling the checkout page
  Future<Map<String, dynamic>?> getCheckoutDetails(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('checkout_details')
        .doc('saved_info')
        .get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> sendEmailOtp(String email) async {
    final String trimmedEmail = email.trim().toLowerCase();
    final String otp = (1000 + Random().nextInt(9000)).toString();

    await _firestore.collection('otp_codes').doc(trimmedEmail).set({
      'code': otp,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': DateTime.now()
          .add(const Duration(minutes: 5))
          .millisecondsSinceEpoch,
    });

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service_id': _emailJsServiceId,
        'template_id': _emailJsTemplateId,
        'user_id': _emailJsPublicKey,
        'template_params': {'user_email': trimmedEmail, 'otp_code': otp},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Email delivery failed: ${response.body}');
    }
  }

  Future<bool> verifyEmailOtp({
    required String email,
    required String userOtp,
  }) async {
    final String trimmedEmail = email.trim().toLowerCase();
    final docSnapshot = await _firestore
        .collection('otp_codes')
        .doc(trimmedEmail)
        .get();

    if (!docSnapshot.exists) return false;

    final data = docSnapshot.data()!;
    final String storedOtp = data['code'];
    final int expiresAt = data['expiresAt'];

    if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
      await _firestore.collection('otp_codes').doc(trimmedEmail).delete();
      return false;
    }

    if (storedOtp == userOtp.trim()) {
      await _firestore.collection('otp_codes').doc(trimmedEmail).delete();
      return true;
    }

    return false;
  }

  Future<void> resetPasswordForEmail({
    required String email,
    required String newPassword,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    final url = Uri.parse(
      'https://auth-app-backend-jet.vercel.app/api/reset-password',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': trimmedEmail,
        'newPassword': newPassword.trim(),
      }),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to update password');
    }
  }

  String messageForError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'weak-password':
        return 'Password is too weak.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}