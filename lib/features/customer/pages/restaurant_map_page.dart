import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_savr/features/customer/pages/restaurant_food_page.dart';
import 'package:url_launcher/url_launcher.dart';

class RestaurantMapPage extends StatefulWidget {
  const RestaurantMapPage({super.key});

  @override
  State<RestaurantMapPage> createState() => _RestaurantMapPageState();
}

class _RestaurantMapPageState extends State<RestaurantMapPage> {
  late GoogleMapController _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  CameraPosition? _initialCameraPosition;

  static const LatLng _defaultLocation = LatLng(3.1390, 101.6869);
  static const double _defaultZoom = 12.0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadRestaurants();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setDefaultLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setDefaultLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setDefaultLocation();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _initialCameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: _defaultZoom,
        );
      });
    } catch (e) {
      print('Error getting location: $e');
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    setState(() {
      _initialCameraPosition = CameraPosition(
        target: _defaultLocation,
        zoom: _defaultZoom,
      );
    });
  }

  Future<void> _loadRestaurants() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('restaurants')
          .where('isActive', isEqualTo: true)
          .where('verificationStatus', isEqualTo: 'approved')
          .get();

      final markers = <Marker>{};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        if (data['location'] != null) {
          final geoPoint = data['location'] as GeoPoint;
          final latLng = LatLng(geoPoint.latitude, geoPoint.longitude);

          final marker = Marker(
            markerId: MarkerId(doc.id),
            position: latLng,
            infoWindow: InfoWindow(
              title: data['name'] ?? 'Restaurant',
              snippet: data['address'] ?? 'No address',
              onTap: () {
                _showRestaurantBottomSheet(doc.id, data);
              },
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            onTap: () {
              _showRestaurantBottomSheet(doc.id, data);
            },
          );

          markers.add(marker);
        }
      }

      setState(() {
        _markers = markers;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading restaurants: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showRestaurantBottomSheet(String restaurantId, Map<String, dynamic> restaurantData) {
    final rating = restaurantData['rating'] ?? 0.0;
    final totalReviews = restaurantData['totalReviews'] ?? 0;
    final cuisineTypes = restaurantData['cuisineTypes'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.restaurant, color: Colors.orange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurantData['name'] ?? 'Restaurant',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (cuisineTypes.isNotEmpty)
                          Text(
                            cuisineTypes.join(', '),
                            style: const TextStyle(color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        Text('($totalReviews)'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      restaurantData['address'] ?? 'No address',
                      style: const TextStyle(color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToRestaurantFoods(restaurantId, restaurantData);
                      },
                      icon: const Icon(Icons.fastfood),
                      label: const Text('View Foods'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _getDirectionsToRestaurant(restaurantData);
                      },
                      icon: const Icon(Icons.directions),
                      label: const Text('Directions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _navigateToRestaurantFoods(String restaurantId, Map<String, dynamic> restaurantData) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      print('Navigating to restaurant: $restaurantId');

      final restaurantDoc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurantId)
          .get();

      if (!restaurantDoc.exists) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restaurant not found')),
        );
        return;
      }

      final completeRestaurantData = restaurantDoc.data() as Map<String, dynamic>;

      completeRestaurantData['id'] = restaurantId;

      Navigator.pop(context);

      print('Restaurant data keys: ${completeRestaurantData.keys.toList()}');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RestaurantFoodPage(
            restaurant: completeRestaurantData,
          ),
        ),
      );

    } catch (e) {
      Navigator.pop(context);
      print('Error navigating to restaurant foods: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _getDirectionsToRestaurant(Map<String, dynamic> restaurantData) async {
    try {
      final location = restaurantData['location'] as GeoPoint?;
      if (location == null) return;

      final restaurantLat = location.latitude;
      final restaurantLng = location.longitude;

      String googleMapsUrl;

      if (_currentPosition != null) {
        googleMapsUrl = 'https://www.google.com/maps/dir/?api=1'
            '&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
            '&destination=$restaurantLat,$restaurantLng'
            '&travelmode=driving';
      } else {
        googleMapsUrl = 'https://www.google.com/maps/search/?api=1'
            '&query=$restaurantLat,$restaurantLng';
      }

      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Google Maps.'),
          ),
        );
      }
    } catch (e) {
      print('Error opening directions: $e');
    }
  }

  void _goToCurrentLocation() async {
    if (_currentPosition != null) {
      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: _defaultZoom,
          ),
        ),
      );
    } else {
      await _getCurrentLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialCameraPosition == null && _isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Nearby Restaurants'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _goToCurrentLocation,
            tooltip: 'Go to my location',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCameraPosition ??
                const CameraPosition(target: _defaultLocation, zoom: _defaultZoom),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
          ),

          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _goToCurrentLocation,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),

          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}