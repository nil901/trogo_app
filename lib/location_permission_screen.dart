import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:trogo_app/api_service/urls.dart';
import 'package:trogo_app/main_bottom_nav.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = false;
  String _errorMessage = '';
  SelectedLocation? _selectedLocation;
  bool _autoNavigating = false;
  
  // API Configuration
  // static const String _baseUrl = "https://trogo-app-backend.onrender.com";

String? tokens = AppPreference().getString(PreferencesKey.authToken);
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
    
    // Load user data and auto-fetch location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Load user data from local storage
  Future<void> _loadUserData() async {
    try {
      _autoFetchLocation();
    } catch (e) {
      print("Error loading user data: $e");
      _autoFetchLocation();
    }
  }

  Future<void> _autoFetchLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final permission = await Permission.location.status;
      
      if (permission.isGranted) {
        await _fetchCurrentLocation();
      } else if (permission.isDenied) {
        setState(() {
          _isLoading = false;
        });
      } else if (permission.isPermanentlyDenied) {
        setState(() {
          _errorMessage = 'Location permission is required. Please enable it from app settings.';
          _isLoading = false;
        });
      } else if (permission.isRestricted) {
        setState(() {
          _errorMessage = 'Location access is restricted on your device.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to check location permission: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled. Please enable them.';
          _isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      String address = await _getAddressFromLatLng(
        position.latitude,
        position.longitude,
      );

      // Store the current location with address
      setState(() {
        _selectedLocation = SelectedLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          address: address,
        );
      });

      // Send location to API
      final bool apiSuccess = await _sendLocationToAPI(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (apiSuccess) {
        // Auto navigate after getting location and successful API call
        await Future.delayed(const Duration(milliseconds: 1500));
        _navigateToMainScreen();
      } else {
        setState(() {
          _errorMessage = 'Failed to update location on server. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get location: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  Future<bool> _sendLocationToAPI({
    required double latitude,
    required double longitude,
  }) async {
    try {
      print("Sending location to API: $latitude, $longitude");
      final response = await http.post(
        Uri.parse('${baseUrl}passenger/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokens', 
        },
        body: json.encode({
          "latitude": latitude,
          "longitude": longitude,
        }),
      );
      print("API Response Status: ${response.statusCode}");
      print("API Response Body: ${response.body}");
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        print("Location updated successfully: $responseData");
        return true;
      } else {
        print("API Error: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error sending location to API: $e");
      return false;
    }
  }

  Future<void> _checkAndRequestLocationPermission() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final permission = await Permission.location.request();

      if (permission.isGranted) {
        await _fetchCurrentLocation();
      } else if (permission.isDenied) {
        setState(() {
          _errorMessage =
              'Location permission is required to find nearby vehicles.';
          _isLoading = false;
        });
      } else if (permission.isPermanentlyDenied) {
        setState(() {
          _errorMessage =
              'Location permission permanently denied. Please enable it from app settings.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get location: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<String> _getAddressFromLatLng(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = '';
        if (place.street != null && place.street!.isNotEmpty) {
          address = place.street!;
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += place.locality!;
        }

        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += place.administrativeArea!;
        }
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          if (address.isNotEmpty) address += ' - ';
          address += place.postalCode!;
        }
        if (place.country != null && place.country!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += place.country!;
        }

        return address.isNotEmpty ? address : 'Address not available';
      }
      return 'Address not found';
    } catch (e) {
      print('Error getting address: $e');
      return 'Unable to fetch address';
    }
  }

  // Navigate to main screen with location data
  void _navigateToMainScreen() {
    if (_autoNavigating || _selectedLocation == null) return;
    
    setState(() {
      _autoNavigating = true;
    });
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MainBottomNav(selectedLocation: _selectedLocation!),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Widget _buildLocationInfo() {
    if (_selectedLocation == null) return const SizedBox();
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Selected Location:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Latitude: ${_selectedLocation!.latitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'Longitude: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'Address: ${_selectedLocation!.address ?? "Fetching..."}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Location sent to server',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.5),
                  end: Offset.zero,
                ).animate(_fadeAnimation),
                child: SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: Image.asset(
                    "assets/images/welcome.png",
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              FadeTransition(
                opacity: _fadeAnimation,
                child: const Text(
                  "Welcome",
                  style: TextStyle(
                    fontFamily: 'Inria Serif',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              FadeTransition(
                opacity: _fadeAnimation,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    "Choose your location to start find\nvehicle around you.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ),

              if (_errorMessage.isNotEmpty)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 10,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red[800], fontSize: 12),
                      ),
                    ),
                  ),
                ),
              
              _buildLocationInfo(),
              
              const SizedBox(height: 20),
              
              FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Image.asset(
                                  "assets/images/Path.png",
                                  height: 20,
                                  width: 20,
                                  color: Colors.white,
                                ),
                          label: _isLoading
                              ? const Text("Fetching location...")
                              : const Text("Use current location"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed:
                              _isLoading ? null : _checkAndRequestLocationPermission,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Manual Location Input (Optional)
                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.search, size: 20),
                          label: const Text("Enter location manually"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: const BorderSide(color: Colors.blue),
                          ),
                          onPressed: () {
                            _showManualLocationDialog();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualLocationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String manualLatitude = '';
        String manualLongitude = '';
        String manualAddress = '';
        
        return AlertDialog(
          title: const Text("Enter Location Manually"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: 'e.g., 19.0760',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => manualLatitude = value,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  hintText: 'e.g., 72.8777',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => manualLongitude = value,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Address (Optional)',
                  hintText: 'e.g., Mumbai, Maharashtra',
                ),
                onChanged: (value) => manualAddress = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (manualLatitude.isNotEmpty && manualLongitude.isNotEmpty) {
                  try {
                    final double lat = double.parse(manualLatitude);
                    final double lng = double.parse(manualLongitude);
                    
                    Navigator.pop(context);
                    
                    setState(() {
                      _isLoading = true;
                      _errorMessage = '';
                    });
                    
                    // Send manual location to API
                    final bool apiSuccess = await _sendLocationToAPI(
                      latitude: lat,
                      longitude: lng,
                    );
                    
                    if (apiSuccess) {
                      setState(() {
                        _selectedLocation = SelectedLocation(
                          latitude: lat,
                          longitude: lng,
                          address: manualAddress.isNotEmpty 
                              ? manualAddress 
                              : 'Manual Location',
                        );
                        _isLoading = false;
                      });
                      
                      await Future.delayed(const Duration(milliseconds: 1500));
                      _navigateToMainScreen();
                    } else {
                      setState(() {
                        _errorMessage = 'Failed to update location on server.';
                        _isLoading = false;
                      });
                    }
                  } catch (e) {
                    setState(() {
                      _errorMessage = 'Invalid coordinates. Please enter valid numbers.';
                      _isLoading = false;
                    });
                  }
                }
              },
              child: const Text('Save & Continue'),
            ),
          ],
        );
      },
    );
  }
}

// location_model.dart
class SelectedLocation {
  final double latitude;
  final double longitude;
  final String? address;

  SelectedLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  Map<String, dynamic> toMap() {
    return {'latitude': latitude, 'longitude': longitude, 'address': address};
  }

  static SelectedLocation fromMap(Map<String, dynamic> map) {
    return SelectedLocation(
      latitude: map['latitude'],
      longitude: map['longitude'],
      address: map['address'],
    );
  }
}