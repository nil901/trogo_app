import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:trogo_app/location_permission_screen.dart';
import 'package:uuid/uuid.dart';

class TransprterSearchDestinationUI extends StatefulWidget {
  final SelectedLocation? currentLocation;
  final VoidCallback onSearchTap;
  final Function(Map<String, dynamic>)? onNext; // Changed
  final Function(Map<String, dynamic>)? onDestinationSelected;
  final String mode; // 'pickup' or 'dropoff'
  final String? initialValue; // Initial search text if editing

  const TransprterSearchDestinationUI({
    Key? key,
    required this.currentLocation,
    required this.onSearchTap,
    required this.onNext, // Required but accepts parameter
    this.onDestinationSelected,
    this.mode = 'dropoff', // Default is dropoff selection
    this.initialValue,
  }) : super(key: key);

  @override
  _TransprterSearchDestinationUIState createState() => _TransprterSearchDestinationUIState();
}

class _TransprterSearchDestinationUIState extends State<TransprterSearchDestinationUI> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String? _selectedDestination;
  String? _selectedAddress;
  Map<String, dynamic>? _selectedLocationData;

  List<Map<String, dynamic>> _predictions = [];
  bool _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
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
          if (_isLoading)
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
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.mode == 'pickup' ? Colors.blue[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: widget.mode == 'pickup' ? Colors.blue : Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.mode == 'pickup' ? Icons.location_on : Icons.flag,
                    color: widget.mode == 'pickup' ? Colors.blue : Colors.orange,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.mode == 'pickup' ? "Selected Pickup:" : "Selected Destination:",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: widget.mode == 'pickup' ? Colors.blue[800] : Colors.orange[800],
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          _selectedDestination!,
                          style: TextStyle(
                            fontSize: 10,
                            color: widget.mode == 'pickup' ? Colors.blue[700] : Colors.orange[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_selectedAddress != null)
                          Text(
                            _selectedAddress!,
                            style: TextStyle(
                              fontSize: 9,
                              color: widget.mode == 'pickup' ? Colors.blue[600] : Colors.orange[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearSelection,
                    child: Icon(
                      Icons.close,
                      color: widget.mode == 'pickup' ? Colors.blue : Colors.orange,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
      
          SizedBox(height: _selectedDestination != null ? 18 : 0),
      
         
          SizedBox(height: 22),
      
          /// SEARCH RESULTS / RECENT LOCATIONS
          if (_searchController.text.isNotEmpty && _predictions.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _predictions.length,
              itemBuilder: (context, index) {
                final prediction = _predictions[index];
                return _predictionTile(prediction);
              },
            )
          else if (_searchController.text.isNotEmpty &&
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
          else if (_showRecentLocations && _recentLocations.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.mode == 'pickup' ? "Recent Pickup Locations" : "Recent Locations",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 10),
                ..._recentLocations.map(
                  (location) => _recentLocationTile(location),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
      
          /// USE CURRENT LOCATION BUTTON (only for pickup mode)
          if (widget.mode == 'pickup' && widget.currentLocation != null && _selectedLocationData == null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ElevatedButton.icon(
                onPressed: () {
                  // Use current location as pickup
                  final currentLocData = {
                    'description': "Current Location",
                    'address': widget.currentLocation!.address,
                    'latitude': widget.currentLocation!.latitude,
                    'longitude': widget.currentLocation!.longitude,
                    'place_id': 'current_location',
                  };
                  
                  // Print for debugging
                  print('📍 Using Current Location');
                  print('Data: $currentLocData');
                  
                  Navigator.pop(context, currentLocData);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(Icons.my_location, size: 20),
                label: Text("Use Current Location"),
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