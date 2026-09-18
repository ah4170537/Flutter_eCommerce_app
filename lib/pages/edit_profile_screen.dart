import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:country_state_city/country_state_city.dart' as csc;
import 'package:intl_phone_field/intl_phone_field.dart';

import '../theme/app_colors.dart';
import 'location_picker_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> initialData;

  const EditProfileScreen({
    super.key,
    required this.userId,
    required this.initialData,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _addressController;

  String _phone = '';
  String _secondaryPhone = '';
  String _country = '';
  String _state = '';
  String _city = '';

  double? _selectedLat;
  double? _selectedLng;
  bool _isLoading = false;

  List<csc.Country> _countries = [];
  List<csc.State> _states = [];
  List<csc.City> _cities = [];

  String? _selectedCountryIso;
  String? _selectedStateIso;
  String? _selectedCityName;

  bool _loadingCountries = true;
  bool _loadingStates = false;
  bool _loadingCities = false;
  bool _locationHydrated = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.initialData['name'] ?? '');
    _emailController = TextEditingController(text: widget.initialData['email'] ?? '');
    
    final shipping = widget.initialData['shippingAddress'] as Map<String, dynamic>? ?? {};
    _phone = shipping['phone'] ?? '';
    _secondaryPhone = shipping['secondaryPhone'] ?? '';
    _country = shipping['country'] ?? '';
    _state = shipping['state'] ?? '';
    _city = shipping['city'] ?? '';
    
    _postalCodeController = TextEditingController(text: shipping['postalCode'] ?? '');
    _addressController = TextEditingController(text: shipping['address'] ?? '');

    final rawLat = shipping['latitude'];
    final rawLng = shipping['longitude'];
    if (rawLat is num) _selectedLat = rawLat.toDouble();
    if (rawLng is num) _selectedLng = rawLng.toDouble();

    _initLocationSetup();
  }

  Future<void> _initLocationSetup() async {
    final countries = await csc.getAllCountries();
    if (!mounted) return;
    setState(() {
      _countries = countries;
      _loadingCountries = false;
    });
    await _hydrateLocationFromSavedNames();
  }

  T? _findByName<T>(List<T> list, String target, String Function(T) nameOf) {
    if (target.trim().isEmpty || list.isEmpty) return null;
    final cleanTarget = target.trim().toLowerCase();

    for (final item in list) {
      if (nameOf(item).trim().toLowerCase() == cleanTarget) return item;
    }
    for (final item in list) {
      final n = nameOf(item).trim().toLowerCase();
      if (n.contains(cleanTarget) || cleanTarget.contains(n)) return item;
    }
    return null;
  }

  Future<void> _hydrateLocationFromSavedNames() async {
    if (_country.isEmpty || _countries.isEmpty) return;

    final matchedCountry = _findByName(_countries, _country, (c) => c.name);
    if (matchedCountry == null) {
      if (mounted) setState(() => _locationHydrated = true);
      return;
    }

    setState(() {
      _selectedCountryIso = matchedCountry.isoCode;
      _country = matchedCountry.name;
      _loadingStates = true;
    });

    final states = await csc.getStatesOfCountry(matchedCountry.isoCode);
    if (!mounted) return;

    setState(() {
      _states = states;
      _loadingStates = false;
    });

    final matchedState = _findByName(states, _state, (s) => s.name);
    if (matchedState != null) {
      setState(() {
        _selectedStateIso = matchedState.isoCode;
        _state = matchedState.name;
        _loadingCities = true;
      });

      final cities = await csc.getStateCities(matchedCountry.isoCode, matchedState.isoCode);
      if (!mounted) return;

      final matchedCity = _findByName(cities, _city, (c) => c.name);

      setState(() {
        _cities = cities;
        _loadingCities = false;
        if (matchedCity != null) {
          _selectedCityName = matchedCity.name;
          _city = matchedCity.name;
        }
        _locationHydrated = true;
      });
    } else {
      if (mounted) setState(() => _locationHydrated = true);
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

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<SelectedLocation>(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );

    if (result != null && mounted) {
      setState(() {
        _addressController.text = result.address;
        _selectedLat = result.latitude;
        _selectedLng = result.longitude;
      });
    }
  }

  String _stripDialCode(String fullNumber, String dialCode) {
    if (fullNumber.isEmpty) return '';
    if (fullNumber.startsWith(dialCode)) {
      return fullNumber.substring(dialCode.length);
    }
    return fullNumber;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).set({
        'name': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'shippingAddress': {
          'phone': _phone,
          'secondaryPhone': _secondaryPhone,
          'country': _country,
          'state': _state,
          'city': _city,
          'postalCode': _postalCodeController.text.trim(),
          'address': _addressController.text.trim(),
          'latitude': _selectedLat,
          'longitude': _selectedLng,
        },
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Information updated successfully!'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _postalCodeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.primaryDark, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5)),
    );
  }

  Widget _loadingSuffix() => const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Information',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
        ),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.primaryDark),
      ),
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Personal & Shipping Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: _buildInputDecoration('Full Name', Icons.person_outline),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      decoration: _buildInputDecoration('Email Address', Icons.email_outlined),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    IntlPhoneField(
                      key: ValueKey('editPhone-$_phone'),
                      initialValue: _stripDialCode(_phone, '+92'),
                      decoration: _buildInputDecoration('Primary Phone Number', Icons.phone_outlined),
                      initialCountryCode: 'PK',
                      onChanged: (phone) => _phone = phone.completeNumber,
                    ),
                    const SizedBox(height: 14),
                    IntlPhoneField(
                      key: ValueKey('editSecPhone-$_secondaryPhone'),
                      initialValue: _stripDialCode(_secondaryPhone, '+92'),
                      decoration: _buildInputDecoration('Secondary Phone (Optional)', Icons.phone_android_outlined),
                      initialCountryCode: 'PK',
                      onChanged: (phone) => _secondaryPhone = phone.completeNumber,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: ValueKey('country-$_locationHydrated'),
                      isExpanded: true,
                      initialValue: _selectedCountryIso,
                      decoration: _buildInputDecoration('Country', Icons.public_outlined, suffixIcon: _loadingCountries ? _loadingSuffix() : null),
                      hint: const Text('Select Country'),
                      items: _countries.map((c) => DropdownMenuItem(value: c.isoCode, child: Text(c.name))).toList(),
                      onChanged: _loadingCountries ? null : _onCountryChanged,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: ValueKey('state-$_locationHydrated'),
                      isExpanded: true,
                      initialValue: _selectedStateIso,
                      decoration: _buildInputDecoration('State', Icons.map_outlined, suffixIcon: _loadingStates ? _loadingSuffix() : null),
                      hint: Text(_selectedCountryIso == null ? 'Select country first' : 'Select State'),
                      items: _states.map((s) => DropdownMenuItem(value: s.isoCode, child: Text(s.name))).toList(),
                      onChanged: (_selectedCountryIso != null && !_loadingStates) ? _onStateChanged : null,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: ValueKey('city-$_locationHydrated'),
                      isExpanded: true,
                      initialValue: _selectedCityName,
                      decoration: _buildInputDecoration('City', Icons.location_city_outlined, suffixIcon: _loadingCities ? _loadingSuffix() : null),
                      hint: Text(_selectedStateIso == null ? 'Select state first' : 'Select City'),
                      items: _cities.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                      onChanged: (_selectedStateIso != null && !_loadingCities) ? _onCityChanged : null,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _postalCodeController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration('Postal Code', Icons.local_post_office_outlined),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _addressController,
                      decoration: _buildInputDecoration(
                        'Street Address',
                        Icons.home_outlined,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.map_outlined, color: AppColors.primaryDark),
                          onPressed: _openLocationPicker,
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isLoading ? null : _saveChanges,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Changes', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}