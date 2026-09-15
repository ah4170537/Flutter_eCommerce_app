import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:country_state_city_picker/country_state_city_picker.dart';

import '../theme/app_colors.dart';

/// A model holding the extra profile details collected in the popup.
class RegistrationDetails {
  final String phone;
  final String country;
  final String state;
  final String city;
  final String address;

  const RegistrationDetails({
    required this.phone,
    required this.country,
    required this.state,
    required this.city,
    required this.address,
  });
}

/// Shows a mandatory popup asking for Phone, Country, State, City, and Address.
Future<RegistrationDetails?> showRegistrationDetailsDialog(
  BuildContext context,
) {
  return showDialog<RegistrationDetails>(
    context: context,
    barrierDismissible: false, // Prevents closing by tapping outside
    builder: (context) => const _AdditionalDetailsDialog(),
  );
}

class _AdditionalDetailsDialog extends StatefulWidget {
  const _AdditionalDetailsDialog();

  @override
  State<_AdditionalDetailsDialog> createState() =>
      _AdditionalDetailsDialogState();
}

class _AdditionalDetailsDialogState extends State<_AdditionalDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();

  String _completePhoneNumber = '';
  String _country = '';
  String _state = '';
  String _city = '';

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, String fieldLabel) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldLabel is required';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_country.isEmpty || _state.isEmpty || _city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select your Country, State, and City'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_completePhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid phone number'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      RegistrationDetails(
        phone: _completePhoneNumber,
        country: _country,
        state: _state,
        city: _city,
        address: _addressController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevents closing via hardware back button
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        elevation: 12,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Decorative Header Icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        size: 36,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  const Text(
                    'Almost There!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  // Subtitle
                  const Text(
                    'Please provide your location and contact details to complete your account setup.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section Label: Contact Info
                  const Text(
                    'CONTACT INFORMATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Phone Number Field
                  IntlPhoneField(
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textGrey,
                      ),
                      filled: true,
                      fillColor: AppColors.hintGrey.withValues(alpha: 0.25),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                    initialCountryCode: 'PK',
                    onChanged: (phone) {
                      _completePhoneNumber = phone.completeNumber;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Section Label: Location Info
                  const Text(
                    'DELIVERY / LOCATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Package-based Country, State, City Cascading Dropdowns
                  SelectState(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.hintGrey.withValues(alpha: 0.25),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                    dropdownColor: Colors.white,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 14,
                    ),
                    onCountryChanged: (value) {
                      setState(() {
                        _country = value;
                      });
                    },
                    onStateChanged: (value) {
                      setState(() {
                        _state = value;
                      });
                    },
                    onCityChanged: (value) {
                      setState(() {
                        _city = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Street Address Field
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'Street Address / House No.',
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textGrey,
                      ),
                      prefixIcon: const Icon(
                        Icons.home_outlined,
                        size: 20,
                        color: AppColors.primaryDark,
                      ),
                      filled: true,
                      fillColor: AppColors.hintGrey.withValues(alpha: 0.25),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                    validator: (v) => _requiredValidator(v, 'Address'),
                  ),
                  const SizedBox(height: 28),

                  // Full-Width Prominent Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Complete Registration',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}