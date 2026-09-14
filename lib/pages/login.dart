import 'package:authentication_module/pages/forgot_password.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_strings.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../widgets/gradient_header.dart';
import '../widgets/pill_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/social_icons_row.dart';
import '../widgets/auth_footer_link.dart';
import '../widgets/auth_card.dart';
import 'register.dart';
import 'main_navigation_screen.dart';
import '../services/cart_merge_helper.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final CartMergeHelper _cartMergeHelper = CartMergeHelper();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final emailError = Validators.emailError(_emailController.text);
    if (emailError != null) {
      _showMessage(emailError);
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showMessage("Password is required");
      return;
    }

    setState(() => _isLoading = true);
    try {

      final User? preLoginUser = FirebaseAuth.instance.currentUser;
      final bool wasGuest = preLoginUser?.isAnonymous ?? false;
      final String? guestUserId = wasGuest ? preLoginUser?.uid : null;

      List<Map<String, dynamic>> guestCartItems = [];
      if (guestUserId != null && guestUserId.isNotEmpty) {
        guestCartItems =
            await _cartMergeHelper.captureAndClearGuestCart(guestUserId);
      }

      final UserCredential userCredential = await AuthService.instance.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;

      final String userId = userCredential.user?.uid ?? '';

      if (guestCartItems.isNotEmpty) {
        await _cartMergeHelper.mergeItemsIntoUserCart(
          newUserId: userId,
          guestItems: guestCartItems,
        );
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => MainNavigationScreen(userId: userId)),
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
                        AppStrings.helloTitle,
                        style: AppTextStyles.heading,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        AppStrings.signInSubtitle,
                        style: AppTextStyles.subheading,
                      ),
                      const SizedBox(height: 30),

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

                      // Added Forgot Password link
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPassword(),
                              ),
                            );
                          },
                          child: const Text(
                            AppStrings.forgotPassword,
                            style: AppTextStyles.footerText,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: PillButton(
                          text: AppStrings.login,
                          backgroundColor: AppColors.primaryLight,
                          textStyle: AppTextStyles.buttonTextWhite,
                          isLoading: _isLoading,
                          onPressed: _handleLogin,
                        ),
                      ),

                      const SizedBox(height: 25),
                      const Center(
                        child: Text(
                          AppStrings.orLoginSocial,
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
                  promptText: AppStrings.noAccount,
                  actionText: AppStrings.registerNow,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const Register()),
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