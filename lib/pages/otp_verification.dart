import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_strings.dart';
import '../services/auth_service.dart';
import '../widgets/gradient_header.dart';
import '../widgets/pill_button.dart';
import '../widgets/otp_input_row.dart';
import '../widgets/auth_footer_link.dart';
import '../widgets/auth_card.dart';
import 'new_password.dart';

class OtpVerification extends StatefulWidget {
  final String email;

  const OtpVerification({super.key, required this.email});

  @override
  State<OtpVerification> createState() => _OtpVerificationState();
}

class _OtpVerificationState extends State<OtpVerification> {
  String _code = '';
  bool _isLoading = false;
  bool _isResending = false;

  // Helper getter to determine if any action is currently running
  bool get _isAnyActionRunning => _isLoading || _isResending;

  Future<void> _handleVerifyOtp() async {
    if (_code.length != 4 || _isAnyActionRunning) return;

    setState(() => _isLoading = true);

    try {
      final isValid = await AuthService.instance.verifyEmailOtp(
        email: widget.email,
        userOtp: _code,
      );

      if (!mounted) return;

      if (isValid) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NewPassword(email: widget.email)),
        );
      } else {
        _showMessage("Invalid or expired OTP code.");
      }
    } catch (e) {
      _showMessage("Verification failed: $e");
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent back navigation while operations are executing
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
                          widget.email.isEmpty
                              ? AppStrings.otpSubtitle
                              : "Enter the 4-digit code we sent to ${widget.email}",
                          style: AppTextStyles.subheading,
                        ),
                        const SizedBox(height: 35),

                        // Disable OTP input field row when an action is in progress if supported,
                        // or rely on buttons locking out interaction.
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
                            // Disabled if code isn't 4 digits OR if resending is ongoing
                            onPressed:
                                (_code.length == 4 && !_isAnyActionRunning)
                                ? _handleVerifyOtp
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

                    onTap: _isAnyActionRunning
                        ? () {}
                        : () => _handleResendOtp(),
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
