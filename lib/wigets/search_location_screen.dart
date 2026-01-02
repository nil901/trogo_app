import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationSearchPage extends StatefulWidget {
  final String initialQuery;
  final String title;
  final Position? currentPosition; // Add this parameter

  const LocationSearchPage({
    super.key,
    required this.initialQuery,
    required this.title,
    this.currentPosition,
  });

  @override
  State<LocationSearchPage> createState() => _LocationSearchPageState();
}

class _LocationSearchPageState extends State<LocationSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _nearbyPlaces = [];
  bool _isLoading = false;
  bool _isLoadingCurrent = true;
  Position? _currentPosition;
  String _currentAddress = "";

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _getCurrentLocationAndNearbyPlaces();
  }

  Future<void> _getCurrentLocationAndNearbyPlaces() async {
    try {
      // Use provided currentPosition or get new one
      if (widget.currentPosition != null) {
        _currentPosition = widget.currentPosition;
        
        // Get address from coordinates
        List<Placemark> placemarks = await placemarkFromCoordinates(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          _currentAddress = "${place.street}, ${place.locality}";
        }
        
        // Fetch nearby places
        await _fetchNearbyPlaces();
      } else {
        // Get current location if not provided
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          setState(() => _isLoadingCurrent = false);
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever ||
            permission == LocationPermission.denied) {
          setState(() => _isLoadingCurrent = false);
          return;
        }

        _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );

        // Get address from coordinates
        if (_currentPosition != null) {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          );

          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            _currentAddress = "${place.street}, ${place.locality}";
          }
        }

        // Fetch nearby places
        await _fetchNearbyPlaces();
      }
    } catch (e) {
      print("Error getting location: $e");
    } finally {
      setState(() => _isLoadingCurrent = false);
    }
  }

  Future<void> _fetchNearbyPlaces() async {
    if (_currentPosition == null) return;

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
        'location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
        '&radius=2000'
        '&type=establishment'
        '&key=$GOOGLE_PLACES_API_KEY',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _nearbyPlaces = List<Map<String, dynamic>>.from(data['results']
                .map((place) => {
                      'name': place['name'],
                      'address': place['vicinity'],
                      'types': List<String>.from(place['types'] ?? []),
                      'geometry': place['geometry'] ?? {},
                    })
                .take(5));
          });
        }
      }
    } catch (e) {
      print("Error fetching nearby places: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search address, place, landmark...",
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: Icon(Icons.search, color: Colors.blue.shade700),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey.shade600),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchResults.clear());
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  if (value.length > 2) {
                    _searchPlaces(value);
                  } else {
                    setState(() => _searchResults.clear());
                  }
                },
              ),
            ),
          ),

          /// CURRENT LOCATION CARD
          if (_currentPosition != null && !_isLoadingCurrent)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context, {
                    'address': _currentAddress,
                    'lat': _currentPosition!.latitude,
                    'lng': _currentPosition!.longitude,
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100, width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.my_location,
                            color: Colors.blue.shade700, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Use Current Location",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentAddress,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          color: Colors.blue.shade700, size: 16),
                    ],
                  ),
                ),
              ),
            ),

          /// NEARBY PLACES SECTION
          if (_nearbyPlaces.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                "Nearby Places",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),

          /// NEARBY PLACES LIST
          if (_nearbyPlaces.isNotEmpty)
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: _nearbyPlaces.length,
                itemBuilder: (context, index) {
                  final place = _nearbyPlaces[index];
                  return _buildPlaceItem(
                    icon: _getPlaceIcon(place['types']),
                    title: place['name'],
                    subtitle: place['address'],
                    onTap: () {
                      Navigator.pop(context, {
                        'address': "${place['name']}, ${place['address']}",
                        'lat': place['geometry']['location']['lat'] ?? 
                              (_currentPosition?.latitude ?? 0.0),
                        'lng': place['geometry']['location']['lng'] ?? 
                              (_currentPosition?.longitude ?? 0.0),
                      });
                    },
                  );
                },
              ),
            ),

          /// SEARCH RESULTS
          if (_searchResults.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      "Search Results",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final place = _searchResults[index];
                        return _buildPlaceItem(
                          icon: Icons.location_on,
                          title: place['description'] ?? '',
                          subtitle: "",
                          showDivider: index != _searchResults.length - 1,
                          onTap: () async {
                            // Get coordinates from place_id
                            final location = await _getPlaceDetails(place['place_id']);
                            if (location != null) {
                              Navigator.pop(context, {
                                'address': place['description'],
                                'lat': location['lat'],
                                'lng': location['lng'],
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          /// LOADING INDICATORS
          if (_isLoadingCurrent)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text(
                      "Finding nearby places...",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

          if (_searchResults.isEmpty && _nearbyPlaces.isEmpty && !_isLoadingCurrent)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.explore, size: 60, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      "Search for a location or use your current location",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          /// MANUAL ENTRY OPTION
          if (_searchController.text.isNotEmpty && _searchResults.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Try to geocode the entered text
                  try {
                    List<Location> locations = await locationFromAddress(_searchController.text);
                    if (locations.isNotEmpty) {
                      Navigator.pop(context, {
                        'address': _searchController.text,
                        'lat': locations.first.latitude,
                        'lng': locations.first.longitude,
                      });
                    } else {
                      // If geocoding fails, use current position
                      Navigator.pop(context, {
                        'address': _searchController.text,
                        'lat': _currentPosition?.latitude ?? 0.0,
                        'lng': _currentPosition?.longitude ?? 0.0,
                      });
                    }
                  } catch (e) {
                    Navigator.pop(context, {
                      'address': _searchController.text,
                      'lat': _currentPosition?.latitude ?? 0.0,
                      'lng': _currentPosition?.longitude ?? 0.0,
                    });
                  }
                },
                icon: const Icon(Icons.add_location_alt, size: 20),
                label: const Text("Use Custom Location"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceItem({
    required IconData icon,
    required String title,
    required String subtitle,
    bool showDivider = true,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blue.shade700, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: subtitle.isNotEmpty
              ? Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: Icon(Icons.arrow_forward_ios,
              color: Colors.grey.shade500, size: 16),
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 70),
            child: Divider(
              height: 1,
              color: Colors.grey.shade200,
            ),
          ),
      ],
    );
  }

  IconData _getPlaceIcon(List<dynamic> types) {
    if (types.contains('restaurant') || types.contains('food')) {
      return Icons.restaurant;
    } else if (types.contains('cafe')) {
      return Icons.local_cafe;
    } else if (types.contains('store') || types.contains('shopping_mall')) {
      return Icons.shopping_bag;
    } else if (types.contains('hospital') || types.contains('health')) {
      return Icons.local_hospital;
    } else if (types.contains('gas_station')) {
      return Icons.local_gas_station;
    } else if (types.contains('park')) {
      return Icons.park;
    }
    return Icons.place;
  }

  /// ---------- GOOGLE PLACES API CALL ----------
  static const String GOOGLE_PLACES_API_KEY = "AIzaSyBGv9znbx4hAdCp_6YK0-HO2XVKI4ZXALk";

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?'
        'input=$query'
        '&key=$GOOGLE_PLACES_API_KEY'
        '&location=${_currentPosition?.latitude ?? 19.0760},${_currentPosition?.longitude ?? 72.8777}'
        '&radius=10000'
        '&components=country:IN',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _searchResults = List<Map<String, dynamic>>.from(data['predictions']);
          });
        } else {
          setState(() => _searchResults = []);
        }
      }
    } catch (e) {
      print("Error fetching places: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, double>?> _getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?'
        'place_id=$placeId'
        '&key=$GOOGLE_PLACES_API_KEY',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          return {
            'lat': location['lat'],
            'lng': location['lng'],
          };
        }
      }
    } catch (e) {
      print("Error fetching place details: $e");
    }
    return null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}