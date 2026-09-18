
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_state_city/country_state_city.dart' as csc;
import 'package:intl_phone_field/intl_phone_field.dart';

import '../services/order_service.dart';
import '../theme/app_colors.dart';
import 'location_picker_screen.dart';
import 'order_detail_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

class CheckoutScreen extends StatefulWidget {
  final String userId;
  final double subtotal;
  final double deliveryFee;
  final List<Map<String, dynamic>> cartItems;
  final VoidCallback? onOrderCompleted;

  const CheckoutScreen({
    super.key,
    required this.userId,
    required this.subtotal,
    required this.deliveryFee,
    required this.cartItems,
    this.onOrderCompleted,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();

  String _phone = '';
  String _secondaryPhone = '';

  String _country = '';
  String _state = '';
  String _city = '';

  final _postalCodeController = TextEditingController();
  final _addressController = TextEditingController();

  // Coordinates picked from the Google Map, kept alongside the text address.
  double? _selectedLat;
  double? _selectedLng;

  String _selectedDeliveryMode = 'Cash on Delivery';
  bool _isLoading = false;
  bool _isSavingInfo = true;

  bool _profileLoaded = false;

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
    _initLocationAndProfile();
  }

  Future<void> _initLocationAndProfile() async {
    // Load the full country list once, up front.
    final countries = await csc.getAllCountries();
    if (mounted) {
      setState(() {
        _countries = countries;
        _loadingCountries = false;
      });
    }

    await _loadUserRegistrationAndShippingInfo();
    await _hydrateLocationFromSavedNames();
  }

  Future<void> _loadUserRegistrationAndShippingInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!doc.exists || doc.data() == null || !mounted) return;

      final data = doc.data()!;
      final User? authUser = FirebaseAuth.instance.currentUser;

      final registeredName =
          data['name'] ?? data['fullName'] ?? authUser?.displayName ?? '';
      final registeredEmail = data['email'] ?? authUser?.email ?? '';

      String loadedPhone = '';
      String loadedSecondaryPhone = '';
      String loadedCountry = '';
      String loadedState = '';
      String loadedCity = '';
      String loadedPostalCode = '';
      String loadedAddress = '';
      double? loadedLat;
      double? loadedLng;

      final shipping = data['shippingAddress'] as Map<String, dynamic>?;
      if (shipping != null) {
        String rawCountry = (shipping['country'] ?? '').toString().trim();
        final codePrefix = RegExp(r'^[A-Z]{2,3}\s+');
        if (codePrefix.hasMatch(rawCountry)) {
          rawCountry = rawCountry.replaceFirst(codePrefix, '').trim();
        }

        loadedPhone = (shipping['phone'] ?? '').toString();
        loadedSecondaryPhone = (shipping['secondaryPhone'] ?? '').toString();
        loadedCountry = rawCountry;
        loadedState = (shipping['state'] ?? '').toString();
        loadedCity = (shipping['city'] ?? '').toString();
        loadedPostalCode = (shipping['postalCode'] ?? '').toString();
        loadedAddress = (shipping['address'] ?? '').toString();

        final rawLat = shipping['latitude'];
        final rawLng = shipping['longitude'];
        if (rawLat is num) loadedLat = rawLat.toDouble();
        if (rawLng is num) loadedLng = rawLng.toDouble();
      }

      if (!mounted) return;

      setState(() {
        _fullNameController.text = registeredName;
        _emailController.text = registeredEmail;

        _phone = loadedPhone;
        _secondaryPhone = loadedSecondaryPhone;
        _country = loadedCountry;
        _state = loadedState;
        _city = loadedCity;
        _postalCodeController.text = loadedPostalCode;
        _addressController.text = loadedAddress;
        _selectedLat = loadedLat;
        _selectedLng = loadedLng;

        _profileLoaded = true;
      });
    } catch (e) {
      debugPrint('Error loading user registration info: $e');
    }
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
    if (_country.isEmpty || _countries.isEmpty) {
      return;
    }

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

      final cities = await csc.getStateCities(
        matchedCountry.isoCode,
        matchedState.isoCode,
      );
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

  // Opens the Google Map picker screen. When the user confirms a location,
  // fills the Street Address field and stores the raw coordinates.
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

  Future<void> _saveShippingInfoToDatabase() async {
    if (!_isSavingInfo) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({
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
    } catch (e) {
      debugPrint('Error saving shipping info: $e');
    }
  }

 Future<void> _handleCheckout() async {
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

  setState(() => _isLoading = true);

  try {
    await _saveShippingInfoToDatabase();

    final String generatedOrderId = await OrderService.instance.placeOrder(
      userId: widget.userId,
      fullName: _fullNameController.text,
      email: _emailController.text,
      phone: _phone,
      secondaryPhone: _secondaryPhone,
      country: _country,
      state: _state,
      city: _city,
      address: _addressController.text,
      postalCode: _postalCodeController.text,
      deliveryMode: _selectedDeliveryMode,
      cartItems: widget.cartItems,
      subtotal: widget.subtotal,
      deliveryFee: widget.deliveryFee,
      latitude: _selectedLat,
      longitude: _selectedLng,
    );

    widget.onOrderCompleted?.call();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Order placed successfully & confirmation email sent!',
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );

    // 2. Navigate to OrderDetailScreen instead of MainNavigationScreen
    // Using pushAndRemoveUntil ensures that pressing "Back" from the order details 
    // safely returns the user to the main app dashboard rather than looping back to checkout.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(
          orderId: generatedOrderId,
          userId: widget.userId,
        ),
      ),
      (route) => route.isFirst, // Keeps your root/main navigation stack beneath it
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to place order: $e'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
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

  InputDecoration _buildInputDecoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.primaryDark, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
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
      key: ValueKey('countryDropdown-$_locationHydrated'),
      isExpanded: true,
      initialValue: _selectedCountryIso,
      decoration: _buildInputDecoration(
        'Country',
        Icons.public_outlined,
        suffixIcon: _loadingCountries ? _loadingSuffix() : null,
      ),
      hint: const Text('Select Country'),
      items: _countries
          .map(
            (c) => DropdownMenuItem(value: c.isoCode, child: Text(c.name)),
          )
          .toList(),
      onChanged: _loadingCountries ? null : _onCountryChanged,
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildStateDropdown() {
    final enabled = _selectedCountryIso != null && !_loadingStates;
    return DropdownButtonFormField<String>(
      key: ValueKey('stateDropdown-$_locationHydrated'),
      isExpanded: true,
      initialValue: _selectedStateIso,
      decoration: _buildInputDecoration(
        'State',
        Icons.map_outlined,
        suffixIcon: _loadingStates ? _loadingSuffix() : null,
      ),
      hint: Text(
        _selectedCountryIso == null ? 'Select country first' : 'Select State',
      ),
      items: _states
          .map(
            (s) => DropdownMenuItem(value: s.isoCode, child: Text(s.name)),
          )
          .toList(),
      onChanged: enabled ? _onStateChanged : null,
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildCityDropdown() {
    final enabled = _selectedStateIso != null && !_loadingCities;
    return DropdownButtonFormField<String>(
      key: ValueKey('cityDropdown-$_locationHydrated'),
      isExpanded: true,
      initialValue: _selectedCityName,
      decoration: _buildInputDecoration(
        'City',
        Icons.location_city_outlined,
        suffixIcon: _loadingCities ? _loadingSuffix() : null,
      ),
      hint: Text(
        _selectedStateIso == null ? 'Select state first' : 'Select City',
      ),
      items: _cities
          .map(
            (c) => DropdownMenuItem(value: c.name, child: Text(c.name)),
          )
          .toList(),
      onChanged: enabled ? _onCityChanged : null,
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.subtotal + widget.deliveryFee;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Checkout',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
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
              // ── Shipping Information card ──────────────────────────────
              // NOTE: this card is a plain Container with a white background
              // color. The CheckboxListTile below is wrapped in its own
              // Material so its background/ink-splash paint on that Material
              // instead of being hidden behind this Container's opaque color.
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.local_shipping_outlined,
                          color: AppColors.primaryDark,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Shipping Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: _buildInputDecoration(
                        'Full Name',
                        Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      decoration: _buildInputDecoration(
                        'Email Address',
                        Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                    IntlPhoneField(
                      key: ValueKey('primaryPhone-$_profileLoaded'),
                      initialValue: _stripDialCode(_phone, '+92'),
                      decoration: _buildInputDecoration(
                        'Primary Phone Number',
                        Icons.phone_outlined,
                      ),
                      initialCountryCode: 'PK',
                      onChanged: (phone) {
                        setState(() {
                          _phone = phone.completeNumber;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    IntlPhoneField(
                      key: ValueKey('secondaryPhone-$_profileLoaded'),
                      initialValue: _stripDialCode(_secondaryPhone, '+92'),
                      decoration: _buildInputDecoration(
                        'Secondary Phone (Optional)',
                        Icons.phone_android_outlined,
                      ),
                      initialCountryCode: 'PK',
                      onChanged: (phone) {
                        setState(() {
                          _secondaryPhone = phone.completeNumber;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildCountryDropdown(),
                    const SizedBox(height: 14),
                    _buildStateDropdown(),
                    const SizedBox(height: 14),
                    _buildCityDropdown(),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _postalCodeController,
                            keyboardType: TextInputType.number,
                            decoration: _buildInputDecoration(
                              'Postal Code',
                              Icons.local_post_office_outlined,
                            ),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _addressController,
                      decoration: _buildInputDecoration(
                        'Street Address',
                        Icons.home_outlined,
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.map_outlined,
                            color: AppColors.primaryDark,
                          ),
                          tooltip: 'Pick on map',
                          onPressed: _openLocationPicker,
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    if (_selectedLat != null && _selectedLng != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          'Pinned: ${_selectedLat!.toStringAsFixed(5)}, '
                          '${_selectedLng!.toStringAsFixed(5)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    // FIX: CheckboxListTile wrapped in its own Material so
                    // its ripple/background paints correctly instead of
                    // being hidden behind the white card Container above.
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Save this information for future orders',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value: _isSavingInfo,
                        activeColor: AppColors.primaryDark,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (val) {
                          setState(() {
                            _isSavingInfo = val ?? true;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Payment & Delivery card ─────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.payment_outlined,
                          color: AppColors.primaryDark,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Payment & Delivery',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // FIX: the tileColor now lives on the Material itself
                    // (not on an intermediate Container), and the
                    // RadioListTile no longer sets its own tileColor —
                    // this is what the original warning was flagging.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Material(
                        color: Colors.grey.shade50,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: RadioListTile<String>(
                            title: const Text(
                              'Cash on Delivery (COD)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: const Text(
                              'Pay with cash upon delivery',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: 'Cash on Delivery',
                            activeColor: AppColors.primaryDark,
                            groupValue: _selectedDeliveryMode,
                            onChanged: (val) =>
                                setState(() => _selectedDeliveryMode = val!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Order Summary card ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Subtotal',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          'PKR ${widget.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Delivery Fee',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          'PKR ${widget.deliveryFee.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          'PKR ${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isLoading ? null : _handleCheckout,
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Place Order',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}