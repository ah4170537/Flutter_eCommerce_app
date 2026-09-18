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
import '../widgets/registration_details_dialog.dart';
import 'login.dart';
import 'register_otp_verification.dart'; 

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

    // 1. Navigate to the details page to collect Phone, Country, State,
    //    City, and Address (previously a popup, now its own screen).
    final RegistrationDetails? details =
        await Navigator.push<RegistrationDetails>(
      context,
      MaterialPageRoute(builder: (_) => const RegistrationDetailsPage()),
    );

    if (details == null) return;

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();

      // 2. Send email OTP via AuthService before creating user account[cite: 3]
      await AuthService.instance.sendEmailOtp(email);

      if (!mounted) return;

      // 3. Navigate to OTP Verification screen, passing form credentials along
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RegisterOtpVerification(
            name: _nameController.text,
            email: email,
            password: _passwordController.text,
            details: details,
          ),
        ),
      );
    } catch (e) {
      _showMessage("Failed to send OTP code: $e");
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