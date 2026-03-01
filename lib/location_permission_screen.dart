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
  late Animation<double> _slideAnimation;
  bool _isLoading = false;
  String _errorMessage = '';
  SelectedLocation? _selectedLocation;
  bool _autoNavigating = false;
  int _currentStep = 1; // 1: Permission, 2: Fetching, 3: Success
  
  String? tokens = AppPreference().getString(PreferencesKey.authToken);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );
    _animationController.forward();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoFetchLocation();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _autoFetchLocation() async {
    setState(() {
      _currentStep = 1;
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final permission = await Permission.location.status;
      
      if (permission.isGranted) {
        setState(() => _currentStep = 2);
        await _fetchCurrentLocation();
      } else if (permission.isDenied) {
        // Prompt the user to grant permission instead of silently stopping.
        await _checkAndRequestLocationPermission();
      } else if (permission.isPermanentlyDenied) {
        setState(() {
          _errorMessage = 'Location permission is required. Please enable it from app settings.';
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
      // Ensure Geolocator permissions are available
      LocationPermission geoPermission = await Geolocator.checkPermission();
      if (geoPermission == LocationPermission.denied ||
          geoPermission == LocationPermission.deniedForever) {
        geoPermission = await Geolocator.requestPermission();
      }

      if (geoPermission == LocationPermission.denied ||
          geoPermission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permission is required. Please enable it.';
          _isLoading = false;
          _currentStep = 1;
        });
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled. Please enable them.';
          _isLoading = false;
          _currentStep = 1;
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
        _currentStep = 3;
        _isLoading = false;
      });
      // Send location to API (skip server call if no auth token)
      final bool apiSuccess = await _sendLocationToAPI(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (apiSuccess) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) _navigateToMainScreen();
      } else {
        // If API failed but there is no token, still navigate as a fallback
        if (tokens == null || tokens!.trim().isEmpty) {
          if (mounted) _navigateToMainScreen();
          return;
        }

        setState(() {
          _errorMessage = 'Failed to update location on server. Please try again.';
          _isLoading = false;
          _currentStep = 1;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get location: ${e.toString()}';
        _isLoading = false;
        _currentStep = 1;
      });
    }
  }

  Future<bool> _sendLocationToAPI({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Read token fresh in case it was updated after widget init
      final String? token = AppPreference().getString(PreferencesKey.authToken);

      // If there's no auth token, skip server update and return success
      if (token == null || token.trim().isEmpty) return true;

      final response = await http.post(
        Uri.parse('${baseUrl}passenger/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          "latitude": latitude,
          "longitude": longitude,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<void> _checkAndRequestLocationPermission() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _currentStep = 1;
    });

    try {
      final permission = await Permission.location.request();

      if (permission.isGranted) {
        setState(() => _currentStep = 2);
        await _fetchCurrentLocation();
      } else if (permission.isDenied) {
        setState(() {
          _errorMessage = 'Location permission is required to find nearby vehicles.';
          _isLoading = false;
          _currentStep = 1;
        });
      } else if (permission.isPermanentlyDenied) {
        setState(() {
          _errorMessage = 'Location permission permanently denied. Please enable it from app settings.';
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

        return address.isNotEmpty ? address : 'Address not available';
      }
      return 'Address not found';
    } catch (e) {
      return 'Unable to fetch address';
    }
  }

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
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepCircle(1, "Permission"),
          Container(
            height: 2,
            width: 40,
            color: _currentStep >= 2 ? Colors.black : Colors.grey.shade300,
          ),
          _buildStepCircle(2, "Fetching"),
          Container(
            height: 2,
            width: 40,
            color: _currentStep >= 3 ? Colors.black : Colors.grey.shade300,
          ),
          _buildStepCircle(3, "Success"),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label) {
    bool isActive = _currentStep >= step;
    bool isCurrent = _currentStep == step;
    
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.black : Colors.grey.shade300,
            border: isCurrent 
                ? Border.all(color: Colors.black, width: 3)
                : null,
          ),
          child: Center(
            child: isActive
                ? Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 20,
                  )
                : Text(
                    '$step',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? Colors.black : Colors.grey.shade500,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Pattern
          Positioned.fill(
            child: CustomPaint(
              painter: _LocationBackgroundPainter(),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Top Section - Scrollable
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated Location Icon
                        ScaleTransition(
                          scale: _slideAnimation,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.05),
                              border: Border.all(
                                color: Colors.black.withOpacity(0.1),
                                width: 2,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 70,
                                  color: Colors.black,
                                ),
                                if (_currentStep == 2)
                                  Positioned.fill(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.black,
                                    ),
                                  ),
                                if (_currentStep == 3)
                                  Positioned(
                                    bottom: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Title
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Text(
                            _currentStep == 3 
                                ? "Location Found!"
                                : "Location Access",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Description
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Text(
                            _currentStep == 1
                                ? "We need your location to show vehicles\naround you and provide accurate services."
                                : _currentStep == 2
                                    ? "Fetching your current location...\nThis may take a few seconds."
                                    : "Great! We've found your location.\nRedirecting to main screen...",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                              height: 1.5,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Step Indicator
                        _buildStepIndicator(),
                        
                        const SizedBox(height: 30),
                        
                        // Error Message
                        if (_errorMessage.isNotEmpty)
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 20),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.red.shade100),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _errorMessage,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 13,
                                      ),
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
                
                // Bottom Button Section
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Main Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _checkAndRequestLocationPermission,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: _isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _currentStep == 2 
                                          ? "Fetching Location..." 
                                          : "Processing...",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  _currentStep == 3 
                                      ? "Continue to App"
                                      : "Allow Location Access",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Alternative Option
                      TextButton(
                        onPressed: () {
                          _showManualLocationDialog();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black,
                        ),
                        child: const Text(
                          "Enter location manually",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      
                      // Privacy Info
                      const SizedBox(height: 20),
                      Text(
                        "Your location data is used only to find nearby\nvehicles and is never shared with third parties.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showManualLocationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String manualAddress = '';
        
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.location_searching, color: Colors.black),
              SizedBox(width: 8),
              Text(
                "Manual Location",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Enter your location name to continue:",
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'e.g., Mumbai Central, Maharashtra',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: (value) => manualAddress = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (manualAddress.isNotEmpty) {
                  Navigator.pop(context);
                  
                  setState(() {
                    _selectedLocation = SelectedLocation(
                      latitude: 19.0760, // Default coordinates for Mumbai
                      longitude: 72.8777,
                      address: manualAddress,
                    );
                    _currentStep = 3;
                  });
                  
                  // Send to API
                  final bool apiSuccess = await _sendLocationToAPI(
                    latitude: 19.0760,
                    longitude: 72.8777,
                  );
                  
                  if (apiSuccess) {
                    await Future.delayed(const Duration(seconds: 1));
                    _navigateToMainScreen();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
              ),
              child: Text('Use This Location'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      },
    );
  }
}

// Custom Background Painter
class _LocationBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.02)
      ..style = PaintingStyle.fill;
    
    // Draw background circles
    for (int i = 0; i < 5; i++) {
      final radius = (i + 1) * 80.0;
      canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.3),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }

  static SelectedLocation fromMap(Map<String, dynamic> map) {
    return SelectedLocation(
      latitude: map['latitude'],
      longitude: map['longitude'],
      address: map['address'],
    );
  }
}