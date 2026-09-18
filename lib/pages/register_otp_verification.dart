import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_strings.dart';
import '../services/auth_service.dart';
import '../services/cart_merge_helper.dart';
import '../widgets/gradient_header.dart';
import '../widgets/pill_button.dart';
import '../widgets/otp_input_row.dart';
import '../widgets/auth_footer_link.dart';
import '../widgets/auth_card.dart';
import '../widgets/registration_details_dialog.dart';
import 'main_navigation_screen.dart';

class RegisterOtpVerification extends StatefulWidget {
  final String name;
  final String email;
  final String password;
  final RegistrationDetails details;

  const RegisterOtpVerification({
    super.key,
    required this.name,
    required this.email,
    required this.password,
    required this.details,
  });

  @override
  State<RegisterOtpVerification> createState() => _RegisterOtpVerificationState();
}

class _RegisterOtpVerificationState extends State<RegisterOtpVerification> {
  String _code = '';
  bool _isLoading = false;
  bool _isResending = false;
  final CartMergeHelper _cartMergeHelper = CartMergeHelper();

  // Helper getter to lock everything down universally when either state is busy
  bool get _isAnyActionRunning => _isLoading || _isResending;

  Future<void> _handleVerifyAndRegister() async {
    if (_code.length != 4 || _isAnyActionRunning) return;

    setState(() => _isLoading = true);

    try {
      final isValid = await AuthService.instance.verifyEmailOtp(
        email: widget.email,
        userOtp: _code,
      );

      if (!mounted) return;

      if (!isValid) {
        _showMessage("Invalid or expired OTP code.");
        setState(() => _isLoading = false);
        return;
      }

      final User? preRegisterUser = FirebaseAuth.instance.currentUser;
      final bool wasGuest = preRegisterUser?.isAnonymous ?? false;
      final String? guestUserId = wasGuest ? preRegisterUser?.uid : null;

      List<Map<String, dynamic>> guestCartItems = [];
      if (guestUserId != null && guestUserId.isNotEmpty) {
        guestCartItems = await _cartMergeHelper.captureAndClearGuestCart(guestUserId);
      }

      final credential = await AuthService.instance.signUp(
        name: widget.name,
        email: widget.email,
        password: widget.password,
        phone: widget.details.phone,
        country: widget.details.country,
        state: widget.details.state,
        city: widget.details.city,
        address: widget.details.address,
      );

      await credential.user?.updateDisplayName(widget.name.trim());

      if (!mounted) return;

      final String userId = credential.user?.uid ?? '';

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
    } catch (e) {
      _showMessage("Verification/Registration failed: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResendOtp() async {
    if (_isAnyActionRunning) return;

    setState(() => _isResending = true);

    try {
      await AuthService.instance.sendEmailOtp(widget.email);
      if (!mounted) return;
      _showMessage("A new OTP code has been sent.");
    } catch (e) {
      _showMessage("Failed to resend OTP: $e");
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_isAnyActionRunning,
      child: Scaffold(
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          AppStrings.otpTitle,
                          style: AppTextStyles.heading,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Enter the 4-digit code sent to ${widget.email} to finish registering.",
                          style: AppTextStyles.subheading,
                        ),
                        const SizedBox(height: 35),
                        OtpInputRow(
                          onChanged: _isAnyActionRunning
                              ? (_) {}
                              : (code) => setState(() => _code = code),
                        ),
                        const SizedBox(height: 35),
                        SizedBox(
                          width: double.infinity,
                          child: PillButton(
                            text: AppStrings.verify,
                            backgroundColor: AppColors.primaryLight,
                            textStyle: AppTextStyles.buttonTextWhite,
                            isLoading: _isLoading,
                            // Disabled if not 4 digits or if resending/verifying is running
                            onPressed: (_code.length == 4 && !_isAnyActionRunning)
                                ? _handleVerifyAndRegister
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
              Padding(
  padding: const EdgeInsets.only(top: 50),
  child: AuthFooterLink(
    promptText: AppStrings.resendCodePrompt,
    actionText: _isResending
        ? "Sending..."
        : AppStrings.resendCodeAction,

    onTap: _isAnyActionRunning ? () {} : () => _handleResendOtp(),
  ),
),
              ],
            ),
          ),
        ),
      ),
    );
  }
}