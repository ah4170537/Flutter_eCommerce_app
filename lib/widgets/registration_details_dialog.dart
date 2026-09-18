import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:country_state_city/country_state_city.dart' as csc;

import '../theme/app_colors.dart';
import '../widgets/gradient_header.dart';
import '../widgets/pill_button.dart';
import '../widgets/auth_card.dart';

/// A model holding the extra profile details collected on this page.
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

/// Full-screen page asking for Phone, Country, State, City, and Address.
class RegistrationDetailsPage extends StatefulWidget {
  const RegistrationDetailsPage({super.key});

  @override
  State<RegistrationDetailsPage> createState() =>
      _RegistrationDetailsPageState();
}

class _RegistrationDetailsPageState extends State<RegistrationDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _scrollController = ScrollController();

  String _completePhoneNumber = '';
  
  // Stored state for country_state_city
  String _country = '';
  String _state = '';
  String _city = '';

  List<csc.Country> _countries = [];
  List<csc.State> _states = [];
  List<csc.City> _cities = [];

  String? _selectedCountryIso;
  String? _selectedStateIso;
  String? _selectedCityName;

  bool _loadingCountries = true;
  bool _loadingStates = false;
  bool _loadingCities = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initCountries();
  }

  Future<void> _initCountries() async {
    final countries = await csc.getAllCountries();
    if (mounted) {
      setState(() {
        _countries = countries;
        _loadingCountries = false;
      });
    }
  }

  Future<void> _onCountryChanged(String? isoCode) async {
    if (isoCode == null) return;
    final country = _countries.firstWhere((c) => c.isoCode == isoCode);

    setState(() {
      _selectedCountryIso = isoCode;
      _country = country.name;

      _selectedStateIso = null;
      _state = '';
      _states = [];

      _selectedCityName = null;
      _city = '';
      _cities = [];

      _loadingStates = true;
    });

    final states = await csc.getStatesOfCountry(isoCode);
    if (!mounted) return;
    setState(() {
      _states = states;
      _loadingStates = false;
    });
  }

  Future<void> _onStateChanged(String? isoCode) async {
    if (isoCode == null || _selectedCountryIso == null) return;
    final state = _states.firstWhere((s) => s.isoCode == isoCode);

    setState(() {
      _selectedStateIso = isoCode;
      _state = state.name;

      _selectedCityName = null;
      _city = '';
      _cities = [];

      _loadingCities = true;
    });

    final cities = await csc.getStateCities(_selectedCountryIso!, isoCode);
    if (!mounted) return;
    setState(() {
      _cities = cities;
      _loadingCities = false;
    });
  }

  void _onCityChanged(String? cityName) {
    if (cityName == null) return;
    setState(() {
      _selectedCityName = cityName;
      _city = cityName;
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, String fieldLabel) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldLabel is required';
    }
    return null;
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  void _submit() {
    _clearError();

    if (!_formKey.currentState!.validate()) {
      _showError('Please fill in the required fields correctly.');
      return;
    }

    if (_country.isEmpty || _state.isEmpty || _city.isEmpty) {
      _showError('Please select your Country, State, and City.');
      return;
    }

    if (_completePhoneNumber.isEmpty) {
      _showError('Please enter a valid phone number.');
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

  InputDecoration _buildInputDecoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.textGrey),
      prefixIcon: Icon(icon, color: AppColors.primaryDark, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.hintGrey.withValues(alpha: 0.25),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppColors.primaryDark.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
    );
  }

  Widget _loadingSuffix() => const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );

  Widget _buildCountryDropdown() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: _selectedCountryIso,
      decoration: _buildInputDecoration(
        'Country',
        Icons.public_outlined,
        suffixIcon: _loadingCountries ? _loadingSuffix() : null,
      ),
      hint: const Text('Select Country', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
      items: _countries
          .map(
            (c) => DropdownMenuItem(value: c.isoCode, child: Text(c.name, style: const TextStyle(fontSize: 14))),
          )
          .toList(),
      onChanged: _loadingCountries ? null : _onCountryChanged,
      validator: (v) => v == null || v.isEmpty ? 'Country is required' : null,
    );
  }

  Widget _buildStateDropdown() {
    final enabled = _selectedCountryIso != null && !_loadingStates;
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: _selectedStateIso,
      decoration: _buildInputDecoration(
        'State',
        Icons.map_outlined,
        suffixIcon: _loadingStates ? _loadingSuffix() : null,
      ),
      hint: Text(
        _selectedCountryIso == null ? 'Select country first' : 'Select State',
        style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
      ),
      items: _states
          .map(
            (s) => DropdownMenuItem(value: s.isoCode, child: Text(s.name, style: const TextStyle(fontSize: 14))),
          )
          .toList(),
      onChanged: enabled ? _onStateChanged : null,
      validator: (v) => v == null || v.isEmpty ? 'State is required' : null,
    );
  }

  Widget _buildCityDropdown() {
    final enabled = _selectedStateIso != null && !_loadingCities;
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: _selectedCityName,
      decoration: _buildInputDecoration(
        'City',
        Icons.location_city_outlined,
        suffixIcon: _loadingCities ? _loadingSuffix() : null,
      ),
      hint: Text(
        _selectedStateIso == null ? 'Select state first' : 'Select City',
        style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
      ),
      items: _cities
          .map(
            (c) => DropdownMenuItem(value: c.name, child: Text(c.name, style: const TextStyle(fontSize: 14))),
          )
          .toList(),
      onChanged: enabled ? _onCityChanged : null,
      validator: (v) => v == null || v.isEmpty ? 'City is required' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            children: [
              const GradientHeader(
                height: 150,
                logoSize: 50,
              ),
              Transform.translate(
                offset: const Offset(0, 50),
                child: AuthCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Error banner ──
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _errorMessage == null
                              ? const SizedBox.shrink()
                              : Padding(
                                  key: const ValueKey('error-banner'),
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.red.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.error_outline_rounded,
                                          color: Colors.red.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: _clearError,
                                          child: Icon(
                                            Icons.close_rounded,
                                            color: Colors.red.shade700,
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),

                        // Decorative Header Icon
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark.withValues(
                                alpha: 0.1,
                              ),
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
                          decoration: _buildInputDecoration(
                            'Phone Number',
                            Icons.phone_outlined,
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

                        // Country Dropdown
                        _buildCountryDropdown(),
                        const SizedBox(height: 14),

                        // State Dropdown
                        _buildStateDropdown(),
                        const SizedBox(height: 14),

                        // City Dropdown
                        _buildCityDropdown(),

                        const SizedBox(height: 16),

                        // Street Address Field
                        TextFormField(
                          controller: _addressController,
                          decoration: _buildInputDecoration(
                            'Street Address / House No.',
                            Icons.home_outlined,
                          ),
                          validator: (v) =>
                              _requiredValidator(v, 'Address'),
                        ),

                        const SizedBox(height: 28),

                        // Full-Width Prominent Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: PillButton(
                            text: 'Complete Registration',
                            backgroundColor: AppColors.primaryDark,
                            textStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            onPressed: _submit,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}