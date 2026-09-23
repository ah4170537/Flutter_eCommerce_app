import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../theme/app_colors.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String userId;
  final String orderId;
  final double destinationLatitude;
  final double destinationLongitude;

  const LiveTrackingScreen({
    super.key,
    required this.userId,
    required this.orderId,
    required this.destinationLatitude,
    required this.destinationLongitude,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<DocumentSnapshot>? _locationSubscription;

  bool _hasReceivedFirstLocation = false;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  DateTime? _lastRouteFetchTime;
  late final LatLng _destination;

  @override
  void initState() {
    super.initState();
    _destination = LatLng(widget.destinationLatitude, widget.destinationLongitude);

    _markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: _destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Delivery Address'),
      ),
    );

    _listenToRiderLocation();
  }

  void _listenToRiderLocation() {
    final docRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.userId)
        .collection('user_orders')
        .doc(widget.orderId)
        .collection('tracking')
        .doc('liveLocation');

    _locationSubscription = docRef.snapshots().listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      final dynamic lat = data['latitude'];
      final dynamic lng = data['longitude'];
      if (lat == null || lng == null) return;

      final newPos = LatLng((lat as num).toDouble(), (lng as num).toDouble());

      setState(() {
        _hasReceivedFirstLocation = true;

        _markers.removeWhere((m) => m.markerId.value == 'rider');
        _markers.add(
          Marker(
            markerId: const MarkerId('rider'),
            position: newPos,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: const InfoWindow(title: 'Your Rider'),
            anchor: const Offset(0.5, 0.5),
            flat: true,
          ),
        );
      });

      _mapController?.animateCamera(CameraUpdate.newLatLng(newPos));

      // Redraw the road route, throttled so we don't hammer OSRM's free server
      final now = DateTime.now();
      if (_lastRouteFetchTime == null ||
          now.difference(_lastRouteFetchTime!) > const Duration(seconds: 3)) {
        _lastRouteFetchTime = now;
        _fetchRoadRoute(newPos, _destination);
      }
    });
  }

  Future<void> _fetchRoadRoute(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url, headers: {'User-Agent': 'CartifyCustomerApp'});
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return;

      final geometry = routes[0]['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;

      final List<LatLng> routePoints = coordinates.map((coord) {
        final c = coord as List<dynamic>;
        return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
      }).toList();

      if (!mounted) return;

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: routePoints,
            color: AppColors.primaryDark,
            width: 5,
          ),
        };
      });
    } catch (e) {
      debugPrint('Route fetch failed: $e');
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Track Your Rider'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primaryDark,
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _destination, zoom: 15),
            markers: _markers,
            polylines: _polylines,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) => _mapController = controller,
          ),
          if (!_hasReceivedFirstLocation)
            Container(
              color: Colors.white.withOpacity(0.85),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primaryDark),
                    SizedBox(height: 12),
                    Text(
                      'Waiting for rider location...',
                      style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Card(
              color: Colors.white,
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.delivery_dining, color: AppColors.primaryDark, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Out for Delivery',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryDark),
                          ),
                          Text(
                            _hasReceivedFirstLocation ? 'Your rider is on the way' : 'Connecting to rider...',
                            style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}