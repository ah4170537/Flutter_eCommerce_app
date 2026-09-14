import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_strings.dart';
import '../services/auth_service.dart';
import '../services/cart_merge_helper.dart';
import '../utils/validators.dart';
import '../widgets/gradient_header.dart';
import '../widgets/pill_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/social_icons_row.dart';
import '../widgets/auth_footer_link.dart';
import '../widgets/auth_card.dart';
import '../widgets/registration_details_dialog.dart';
import 'login.dart';
import 'dashboard.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final CartMergeHelper _cartMergeHelper = CartMergeHelper();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_nameController.text.trim().isEmpty) {
      _showMessage("Please enter your name");
      return;
    }
    final emailError = Validators.emailError(_emailController.text);
    if (emailError != null) {
      _showMessage(emailError);
      return;
    }
    final passwordError = Validators.passwordError(_passwordController.text);
    if (passwordError != null) {
      _showMessage(passwordError);
      return;
    }
    if (_confirmPasswordController.text != _passwordController.text) {
      _showMessage("Passwords do not match");
      return;
    }

    // All base fields are valid — now collect the additional profile
    // details via the popup before actually creating the account.
    final RegistrationDetails? details =
        await showRegistrationDetailsDialog(context);

    // User cancelled the popup — don't proceed with registration.
    if (details == null) return;

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Capture the guest's UID BEFORE creating the new account — once
      // signUp() succeeds, FirebaseAuth.instance.currentUser switches to
      // the new account and the anonymous UID is no longer reachable.
      final User? preRegisterUser = FirebaseAuth.instance.currentUser;
      final bool wasGuest = preRegisterUser?.isAnonymous ?? false;
      final String? guestUserId = wasGuest ? preRegisterUser?.uid : null;

      // PHASE 1: capture + clear the guest cart WHILE STILL authenticated
      // as the guest — Security Rules only allow a user to touch their
      // own cart, so this must happen before the session switches.
      List<Map<String, dynamic>> guestCartItems = [];
      if (guestUserId != null && guestUserId.isNotEmpty) {
        guestCartItems =
            await _cartMergeHelper.captureAndClearGuestCart(guestUserId);
      }

      final credential = await AuthService.instance.signUp(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        firstName: details.firstName,
        lastName: details.lastName,
        phone: details.phone,
        address: details.address,
        city: details.city,
      );
      await credential.user?.updateDisplayName(_nameController.text.trim());

      if (!mounted) return;

      final String userId = credential.user?.uid ?? '';

      // PHASE 2: now authenticated as the real user — write the captured
      // guest items into their own (brand-new) cart.
      if (guestCartItems.isNotEmpty) {
        await _cartMergeHelper.mergeItemsIntoUserCart(
          newUserId: userId,
          guestItems: guestCartItems,
        );
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => Dashboard(userId: userId)),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(AuthService.instance.messageForError(e));
    } catch (_) {
      _showMessage("Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const GradientHeader(height: 150, logoSize: 50),
              Transform.translate(
                offset: const Offset(0, 50),
                child: AuthCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        AppStrings.createAccount,
                        style: AppTextStyles.heading,
                      ),
                      const SizedBox(height: 25),

                      AuthTextField(
                        label: AppStrings.userNameLabel,
                        controller: _nameController,
                        icon: Icons.person_outline,
                      ),
                      AuthTextField(
                        label: AppStrings.emailLabel,
                        controller: _emailController,
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      AuthTextField(
                        label: AppStrings.passwordLabel,
                        controller: _passwordController,
                        icon: Icons.lock_outline,
                        isPassword: true,
                      ),
                      AuthTextField(
                        label: 'Confirm Password',
                        controller: _confirmPasswordController,
                        icon: Icons.lock_outline,
                        isPassword: true,
                      ),

                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: PillButton(
                          text: AppStrings.registerNow,
                          backgroundColor: AppColors.secondaryDark,
                          textStyle: AppTextStyles.buttonTextWhite,
                          isLoading: _isLoading,
                          onPressed: _handleRegister,
                        ),
                      ),

                      const SizedBox(height: 25),
                      const Center(
                        child: Text(
                          AppStrings.orRegisterSocial,
                          style: AppTextStyles.footerText,
                        ),
                      ),
                      const SizedBox(height: 15),
                      const SocialIconsRow(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.only(top: 50),
                child: AuthFooterLink(
                  promptText: AppStrings.haveAccount,
                  actionText: AppStrings.login,
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const Login()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}