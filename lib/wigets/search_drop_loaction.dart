import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:trogo_app/location_permission_screen.dart';
import 'package:trogo_app/wigets/drop_provider.dart';
import 'package:uuid/uuid.dart';

class SearchDestinationUI extends ConsumerStatefulWidget {
  final SelectedLocation? currentLocation;
  final VoidCallback onSearchTap;
  final Function(Map<String, dynamic>)? onNext;
  final Function(Map<String, dynamic>)? onDestinationSelected;
  final String mode;
  final String? initialValue;

  const SearchDestinationUI({
    Key? key,
    required this.currentLocation,
    required this.onSearchTap,
    required this.onNext,
    this.onDestinationSelected,
    this.mode = 'dropoff',
    this.initialValue,
  }) : super(key: key);

  @override
  ConsumerState<SearchDestinationUI> createState() =>
      _SearchDestinationUIState();
}

class _SearchDestinationUIState
    extends ConsumerState<SearchDestinationUI> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String? _selectedDestination;
  String? _selectedAddress;
  Map<String, dynamic>? _selectedLocationData;

  List<Map<String, dynamic>> _predictions = [];
  bool _isLoading = false;
  bool _isFetchingCurrentLocation = false;
  bool _showRecentLocations = true;

  final String _apiKey = 'AIzaSyBGv9znbx4hAdCp_6YK0-HO2XVKI4ZXALk';
  final String _baseUrl = 'https://maps.googleapis.com/maps/api/place';
  final String _sessionToken = Uuid().v4();

  // Recent locations storage
  final List<Map<String, dynamic>> _recentLocations = [
    {
      "description": "Mumbai Central Station, Mumbai",
      "place_id": "ChIJK1TdLJvE5zsRrQ9W7Qq7L6M",
      "formatted_address": "Mumbai Central, Mumbai, Maharashtra, India",
    },
    {
      "description": "Chhatrapati Shivaji Maharaj International Airport",
      "place_id": "ChIJVVVVVYxO5zsR6e6M",
      "formatted_address": "Mumbai, Maharashtra, India",
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
    
    // Set initial value if editing
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchController.text = widget.initialValue!;
        setState(() {
          _selectedDestination = widget.initialValue;
          _showRecentLocations = false;
        });
      });
    }
  }

  @override
  void didUpdateWidget(covariant SearchDestinationUI oldWidget) {
    super.didUpdateWidget(oldWidget);

    final isUsingCurrentLocation =
        _selectedLocationData?['place_id'] == '${widget.mode}_current_location';
    final currentLocationChanged =
        oldWidget.currentLocation?.latitude != widget.currentLocation?.latitude ||
        oldWidget.currentLocation?.longitude != widget.currentLocation?.longitude ||
        oldWidget.currentLocation?.address != widget.currentLocation?.address;

    if (isUsingCurrentLocation &&
        currentLocationChanged &&
        widget.currentLocation != null) {
      _applyCurrentLocation(widget.currentLocation!);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_searchFocusNode.hasFocus) {
      setState(() {
        _showRecentLocations = true;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _predictions.clear();
        _showRecentLocations = true;
      });
      return;
    }

    if (query.length < 3) return;

    _fetchPlacePredictions(query);
  }

  Future<void> _fetchPlacePredictions(String input) async {
    if (_apiKey == 'YOUR_GOOGLE_PLACES_API_KEY_HERE') {
      print(
        '⚠️ API Key not configured. Please add your Google Places API Key.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _showRecentLocations = false;
    });

    try {
      final url = Uri.parse(
        '$_baseUrl/autocomplete/json?input=$input&key=$_apiKey&sessiontoken=$_sessionToken&components=country:in',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;

          setState(() {
            _predictions = predictions.map<Map<String, dynamic>>((pred) {
              return {
                'description': pred['description'],
                'place_id': pred['place_id'],
                'structured_formatting': pred['structured_formatting'],
              };
            }).toList();
          });
        } else {
          print('API Error: ${data['status']} - ${data['error_message']}');
          setState(() {
            _predictions.clear();
          });
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
        setState(() {
          _predictions.clear();
        });
      }
    } catch (e) {
      print('Error fetching predictions: $e');
      setState(() {
        _predictions.clear();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getPlaceDetails(String placeId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse(
        '$_baseUrl/details/json?place_id=$placeId&key=$_apiKey&sessiontoken=$_sessionToken',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final result = data['result'];
          final location = result['geometry']['location'];

          setState(() {
            _selectedLocationData = {
              'description': result['name'] ?? result['formatted_address'],
              'address': result['formatted_address'],
              'latitude': location['lat'],
              'longitude': location['lng'],
              'place_id': placeId,
            };
            _selectedDestination = result['name'] ?? result['formatted_address'];
            _selectedAddress = result['formatted_address'];
          });

          // Save to recent locations
          _addToRecentLocations({
            'description': result['name'] ?? result['formatted_address'],
            'place_id': placeId,
            'formatted_address': result['formatted_address'],
          });

          // Callback to parent
          widget.onDestinationSelected?.call(_selectedLocationData!);
          
          // Print for debugging
          print('✅ Place selected: $_selectedDestination');
          print('📍 Address: $_selectedAddress');
          print('🗺️ Lat: ${location['lat']}, Lng: ${location['lng']}');
        }
      }
    } catch (e) {
      print('Error fetching place details: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addToRecentLocations(Map<String, dynamic> location) {
    // Remove if already exists
    _recentLocations.removeWhere(
      (loc) => loc['place_id'] == location['place_id'],
    );

    // Add to beginning
    _recentLocations.insert(0, location);

    // Keep only last 5
    if (_recentLocations.length > 5) {
      _recentLocations.removeLast();
    }
  }

  void _selectRecentLocation(Map<String, dynamic> location) {
    setState(() {
      _selectedDestination = location['description'];
      _selectedAddress = location['formatted_address'];
      _selectedLocationData = location;
    });

    _searchController.clear();
    _searchFocusNode.unfocus();

    widget.onDestinationSelected?.call(location);
    
    // Print for debugging
    print('📌 Recent location selected: ${location['description']}');
  }

  void _clearSelection() {
    setState(() {
      _selectedDestination = null;
      _selectedAddress = null;
      _selectedLocationData = null;
    });
  }

  void _applyCurrentLocation(SelectedLocation location) {
    final locationLabel =
        widget.mode == 'pickup' ? 'Current Pickup Location' : 'Current Location';
    final currentLocData = {
      'description': locationLabel,
      'address': location.address,
      'formatted_address': location.address,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'place_id': '${widget.mode}_current_location',
    };

    setState(() {
      _selectedDestination = locationLabel;
      _selectedAddress = location.address;
      _selectedLocationData = currentLocData;
      _showRecentLocations = false;
      _predictions.clear();
    });

    widget.onDestinationSelected?.call(currentLocData);
  }

  Future<String> _getAddressFromLatLng(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return 'Current Location';

      final place = placemarks.first;
      final parts = [
        place.street,
        place.subLocality,
        place.locality,
        place.administrativeArea,
      ]
          .where((part) => part != null && part!.trim().isNotEmpty)
          .cast<String>()
          .toList();

      return parts.isNotEmpty ? parts.join(', ') : 'Current Location';
    } catch (e) {
      print('Error getting address from coordinates: $e');
      return 'Current Location';
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_isFetchingCurrentLocation) return;

    setState(() {
      _isFetchingCurrentLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is not granted');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final address = await _getAddressFromLatLng(
        position.latitude,
        position.longitude,
      );

      _applyCurrentLocation(
        SelectedLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          address: address,
        ),
      );
    } catch (e) {
      print('Error fetching latest current location: $e');
      if (widget.currentLocation != null) {
        _applyCurrentLocation(widget.currentLocation!);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingCurrentLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentDrops = ref.watch(recentDropProvider);
    final hasSelectedDropoff =
        widget.mode == 'dropoff' && _selectedDestination != null;
    final recentLocationsToShow =
        widget.mode == 'pickup' ? _recentLocations : const <Map<String, dynamic>>[];
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER WITH BACK BUTTON
          Row(
            children: [
           
              Expanded(
                child: Text(
                  widget.mode == 'pickup' 
                    ? "Edit Pickup Location"
                    : "Select Destination",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
      
          SizedBox(height: 20),
      
          /// TITLE
          Text(
            widget.mode == 'pickup'
              ? "Where would you like to be picked up?"
              : "Where are you going today?",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
      
          SizedBox(height: 18),
      
          /// CURRENT LOCATION DISPLAY
          if (widget.currentLocation != null)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Current Location:",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          widget.currentLocation!.address ?? "Unknown address",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green[700],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      
          SizedBox(height: widget.currentLocation != null ? 18 : 0),
      
          /// SEARCH BOX
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Color(0xffF2F4F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  widget.mode == 'pickup' ? Icons.location_on : Icons.search,
                  color: widget.mode == 'pickup' ? Colors.blue : Colors.black54,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: widget.mode == 'pickup'
                        ? "Search pickup location"
                        : "Search destinations",
                      hintStyle: TextStyle(color: Colors.black54, fontSize: 12),
                      border: InputBorder.none,
                    ),
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _predictions.clear();
                        _showRecentLocations = true;
                        _selectedDestination = null;
                        _selectedLocationData = null;
                      });
                    },
                    child: Icon(Icons.close, color: Colors.black54, size: 20),
                  ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onSearchTap,
                  child: Icon(
                    Icons.map_outlined,
                    color: Colors.black54,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
      
          SizedBox(height: 12),
      
          /// MODE INDICATOR
          if (widget.mode == 'pickup')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                "Search for a pickup location or select from recent",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
      
          SizedBox(height: 18),
      
          /// LOADING INDICATOR
          if (_isLoading || _isFetchingCurrentLocation)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
      
          /// SELECTED LOCATION DISPLAY
          if (_selectedDestination != null)
            Builder(
              builder: (context) {
                final accentColor =
                    widget.mode == 'pickup'
                        ? const Color(0xFF1677FF)
                        : const Color(0xFFF97316);
                final softColor =
                    widget.mode == 'pickup'
                        ? const Color(0xFFEAF3FF)
                        : const Color(0xFFFFF1E8);
                final iconData =
                    widget.mode == 'pickup' ? Icons.location_on : Icons.flag;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [softColor, Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: accentColor.withOpacity(0.22)),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(iconData, color: accentColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                widget.mode == 'pickup'
                                    ? "Selected Pickup"
                                    : "Selected Destination",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _selectedDestination!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_selectedAddress != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _selectedAddress!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _clearSelection,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accentColor.withOpacity(0.18),
                            ),
                          ),
                          child: Icon(
                            Icons.close,
                            color: accentColor,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      
          SizedBox(height: _selectedDestination != null ? 18 : 0),
          SizedBox(height: hasSelectedDropoff ? 8 : 22),
      
          /// SEARCH RESULTS / RECENT LOCATIONS
          if (!hasSelectedDropoff &&
              _searchController.text.isNotEmpty &&
              _predictions.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _predictions.length,
              itemBuilder: (context, index) {
                final prediction = _predictions[index];
                return _predictionTile(prediction);
              },
            )
          else if (!hasSelectedDropoff &&
              _searchController.text.isNotEmpty &&
              _predictions.isEmpty &&
              !_isLoading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  "No locations found",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            )
      else if (!hasSelectedDropoff &&
          _showRecentLocations &&
          widget.mode == 'pickup' &&
          recentLocationsToShow.isNotEmpty)
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "Recent Pickup Locations",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),

      ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount:
            recentLocationsToShow.length > 5 ? 5 : recentLocationsToShow.length,
        itemBuilder: (context, index) {
          final location = recentLocationsToShow[index];
          return _recentLocationTile(location);
        },
      ),
    ],
  )
      else if (!hasSelectedDropoff &&
          _showRecentLocations &&
          widget.mode == 'dropoff' &&
          recentDrops.isNotEmpty)
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "Recent Locations",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),

      // const SizedBox(height: 10),

      ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount:
            recentDrops.length > 5 ? 5 : recentDrops.length,
        itemBuilder: (context, index) {
          final drop = recentDrops[index];

          return InkWell(
            onTap: () {
              final location = {
                "description": drop.drop.address,
                "formatted_address": drop.drop.address,
                "latitude": drop.drop.lat,
                "longitude": drop.drop.lng,
                "place_id": drop.id,
              };

              _selectRecentLocation(location);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 6,
                horizontal: 4,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 80, 79, 77).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.black,
                      size: 18,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      drop.drop.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  ),
      
          SizedBox(height: 20),
      
         
          if (widget.mode == 'dropoff' && _selectedDestination != null)
            ElevatedButton(
              onPressed: () {
                // Print selected data
                print('🚖 NEXT BUTTON PRESSED 🚖');
                print('Selected Destination: $_selectedDestination');
                print('Selected Address: $_selectedAddress');
                print('Location Data: $_selectedLocationData');
                
                // Call onNext with data
                if (_selectedLocationData != null) {
                  widget.onNext?.call(_selectedLocationData!);
                } else {
                  // If no location data but destination is selected
                  widget.onNext?.call({
                    'description': _selectedDestination,
                    'address': _selectedAddress,
                    'latitude': 0.0,
                    'longitude': 0.0,
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize: Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "Next",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,color: Colors.white),
              ),
            ),
      
          /// USE CURRENT LOCATION BUTTON
          if (widget.currentLocation != null && _selectedLocationData == null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ElevatedButton.icon(
                onPressed: _isFetchingCurrentLocation ? null : () {
                  
                  print('📍 Using Current Location');
                  
                  _useCurrentLocation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(Icons.my_location, size: 20),
                label: Text(
                  widget.mode == 'pickup'
                      ? "Use Current Location"
                      : "Set Drop To Current Location",
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _predictionTile(Map<String, dynamic> prediction) {
    final mainText = prediction['structured_formatting']?['main_text'] ?? '';
    final secondaryText =
        prediction['structured_formatting']?['secondary_text'] ?? '';

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.location_on_outlined, color: Colors.black87),
          title: Text(
            mainText.isNotEmpty ? mainText : prediction['description'] ?? '',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          subtitle: secondaryText.isNotEmpty
              ? Text(
                  secondaryText,
                  style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                )
              : null,
          onTap: () {
            _getPlaceDetails(prediction['place_id']);
            _searchController.text = prediction['description'] ?? '';
            _searchFocusNode.unfocus();
          },
        ),
        Divider(height: 5),
      ],
    );
  }

  Widget _recentLocationTile(Map<String, dynamic> location) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.history, color: Colors.grey[600]),
          title: Text(
            location['description'] ?? '',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          subtitle: location['formatted_address'] != null
              ? Text(
                  location['formatted_address']!,
                  style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                )
              : null,
          onTap: () {
            _selectRecentLocation(location);
          },
        ),
        Divider(height: 5),
      ],
    );
  }
}
