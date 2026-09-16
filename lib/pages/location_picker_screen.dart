import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SelectedLocation {
  final double latitude;
  final double longitude;
  final String address;
  SelectedLocation({required this.latitude, required this.longitude, required this.address});
}

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  // Default center (Lahore)
  LatLng _pickedLocation = const LatLng(31.5204, 74.3587);
  String _addressPreview = "Move the map to select a location";
  bool _loadingAddress = false;

  // Ensure you store your Google API key in your .env file as GOOGLE_API_KEY
  static final String _googleApiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();

    // DEBUG: confirm the key actually loaded before we do anything else.
    // If this prints length: 0, your .env didn't load in time (or the
    // key name doesn't match), and EVERY request below will fail.
    debugPrint('GOOGLE_API_KEY loaded -> length: ${_googleApiKey.length}');

    _setInitialLocation();
  }

  Future<void> _setInitialLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      Position pos = await Geolocator.getCurrentPosition();
      final userLatLng = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _pickedLocation = userLatLng;
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: userLatLng, zoom: 15.0),
        ),
      );
      _updateAddressPreview(userLatLng);
    } catch (_) {
      // Fall back silently
    }
  }

  // Triggered when the user starts moving the map
  void _onCameraMove(CameraPosition position) {
    if (!_loadingAddress) {
      setState(() {
        _loadingAddress = true;
        _addressPreview = "Moving location...";
        _pickedLocation = position.target;
      });
    } else {
      setState(() {
        _pickedLocation = position.target;
      });
    }
  }

  // Triggered when the user stops panning the map
  void _onCameraIdle() {
    _updateAddressPreview(_pickedLocation);
  }

  // Search any location or city worldwide using Google Geocoding API
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _loadingAddress = true;
      _addressPreview = "Searching location...";
    });

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=$_googleApiKey',
      );

      final response = await http.get(url);
      debugPrint('--- SEARCH (geocode) ---');
      debugPrint('HTTP status: ${response.statusCode}');
      debugPrint('Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('API status: ${data['status']}, error: ${data['error_message']}');
        final results = data['results'] as List?;

        if (results != null && results.isNotEmpty) {
          final location = results[0]['geometry']['location'];
          final lat = location['lat'] as double;
          final lon = location['lng'] as double;
          final formatted = results[0]['formatted_address'] ?? query;

          final newPos = LatLng(lat, lon);
          setState(() {
            _pickedLocation = newPos;
            _addressPreview = formatted;
            _loadingAddress = false;
          });

          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: newPos, zoom: 15.0),
            ),
          );
        } else {
          setState(() {
            _addressPreview = "No results found for '$query'";
            _loadingAddress = false;
          });
        }
      } else {
        setState(() {
          _addressPreview = "Search error (${response.statusCode})";
          _loadingAddress = false;
        });
      }
    } catch (e) {
      debugPrint('Search Exception: $e');
      setState(() {
        _addressPreview = "Failed to search location";
        _loadingAddress = false;
      });
    }
  }

  // Reverse Geocoding using Google Maps API
  Future<void> _updateAddressPreview(LatLng position) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$_googleApiKey',
      );

      final response = await http.get(url);
      debugPrint('--- REVERSE GEOCODE ---');
      debugPrint('HTTP status: ${response.statusCode}');
      debugPrint('Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('API status: ${data['status']}, error: ${data['error_message']}');
        final results = data['results'] as List?;

        if (results != null && results.isNotEmpty) {
          final formatted = results[0]['formatted_address'] ?? 'Address not found';
          setState(() {
            _addressPreview = formatted;
            _loadingAddress = false;
          });
        } else {
          setState(() {
            _addressPreview = "Address not found";
            _loadingAddress = false;
          });
        }
      } else {
        setState(() {
          _addressPreview = "API Error (${response.statusCode})";
          _loadingAddress = false;
        });
      }
    } catch (e) {
      debugPrint('Reverse Geocode Exception: $e');
      setState(() {
        _addressPreview = "Failed to fetch address";
        _loadingAddress = false;
      });
    }
  }

  void _confirmLocation() {
    if (_loadingAddress) return;

    final result = SelectedLocation(
      latitude: _pickedLocation.latitude,
      longitude: _pickedLocation.longitude,
      address: _addressPreview,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Delivery Location")),
      body: Column(
        children: [
          // 1. Search Bar at the Top
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search any address or city...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (value) {
                _searchLocation(value);
              },
            ),
          ),

          // 2. Google Map View with a Fixed Center Pin
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _pickedLocation,
                    zoom: 15,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                ),
                // Permanent Center Marker Overlay
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 35.0), // Offset so the pin tip lands precisely center
                    child: Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 45,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Address Preview & Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _loadingAddress
                          ? const LinearProgressIndicator()
                          : Text(_addressPreview, style: const TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (!_loadingAddress) ? _confirmLocation : null,
                    child: const Text("Use This Location"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}