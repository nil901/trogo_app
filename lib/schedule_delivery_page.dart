import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:trogo_app/goods_details_page.dart';

class ScheduleDeliveryPage extends StatefulWidget {
  const ScheduleDeliveryPage({super.key});

  @override
  State<ScheduleDeliveryPage> createState() => _ScheduleDeliveryPageState();
}

class _ScheduleDeliveryPageState extends State<ScheduleDeliveryPage> {
  int selectedVehicle = 0;
  String pickupLocation = "32 Samwell Sq, Chevron";
  String deliveryLocation = "";
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
@override
void initState() {
  super.initState();
  _setCurrentPickupLocation();
}

Future<void> _setCurrentPickupLocation() async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => pickupLocation = "Turn on location services");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => pickupLocation = "Location permission denied");
      return;
    }

    setState(() => pickupLocation = "Fetching current location...");

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    List<Placemark> placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);

    if (placemarks.isNotEmpty) {
      final p = placemarks.first;
      setState(() {
        pickupLocation =
            "${p.street ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}";
      });
    }
  } catch (e) {
    print("❌ Error: $e");
    setState(() => pickupLocation = "Tap to select location");
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: Stack(
        children: [
          /// BACKGROUND MAP
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.green.shade100,
            child: Icon(Icons.map, size: 200, color: Colors.green.shade400),
          ),

          /// BACK BUTTON
          Positioned(
            top: 50,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                child: Icon(Icons.arrow_back, color: Colors.black),
              ),
            ),
          ),

          /// BOTTOM SHEET
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// HANDLE
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(height: 18),

                    Text(
                      "Schedule Delivery",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    SizedBox(height: 18),

                    /// PICKUP - CLICKABLE
               /// PICKUP - CLICKABLE
Text("Pickup Location", style: _labelTextStyle()),
SizedBox(height: 6),
GestureDetector(
  onTap: () async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationSearchPage(
          initialQuery: pickupLocation.contains("Fetching") 
              ? "" 
              : pickupLocation,
          title: "Search Pickup Location",
        ),
      ),
    );
    if (result != null) {
      setState(() {
        pickupLocation = result;
      });
    }
  },
  child: Container(
    height: 48,
    padding: EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        // Add animation while fetching
        if (pickupLocation.contains("Fetching"))
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(Icons.location_on, size: 18, color: Colors.red),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            pickupLocation.isEmpty 
                ? "Getting current location..." 
                : pickupLocation,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: pickupLocation.contains("Error") 
                  ? Colors.orange.shade700 
                  : Colors.black,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ],
    ),
  ),
),
                    SizedBox(height: 18),

                    /// DELIVERY - CLICKABLE
                    Text("Delivery Location", style: _labelTextStyle()),
                    SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LocationSearchPage(
                              initialQuery: deliveryLocation,
                              title: "Search Delivery Location",
                            ),
                          ),
                        );
                        if (result != null) {
                          setState(() {
                            deliveryLocation = result;
                          });
                        }
                      },
                      child: _locationBox(
                        Icons.location_on,
                        Colors.green,
                        deliveryLocation,
                      ),
                    ),

                    SizedBox(height: 18),

                    /// DATE + TIME - CLICKABLE
                    Row(
                      children: [
                        /// DATE PICKER
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Date", style: _labelTextStyle()),
                              SizedBox(height: 6),
                              GestureDetector(
                                onTap: _pickDate,
                                child: _inputBox(
                                  selectedDate != null
                                      ? DateFormat('dd/MM/yyyy').format(selectedDate!)
                                      : "DD/MM/YYYY",
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),

                        /// TIME PICKER
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Time", style: _labelTextStyle()),
                              SizedBox(height: 6),
                              GestureDetector(
                                onTap: _pickTime,
                                child: _inputBox(
                                  selectedTime != null
                                      ? selectedTime!.format(context)
                                      : "HH:MM",
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 22),

                    /// VEHICLE TYPE
                    Text("Vehicle Type", style: _labelTextStyle()),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _vehicleBox(0, "assets/images/Group.png"),
                        _vehicleBox(1, "assets/images/Group.png"),
                        _vehicleBox(2, "assets/images/van.png"),
                      ],
                    ),

                    SizedBox(height: 26),

                    /// NEXT BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () {
                          if (pickupLocation.isEmpty || deliveryLocation.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Please select pickup and delivery locations"),
                              ),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GoodsDetailsPage(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "Next",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ---------- DATE/TIME PICKERS ----------
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != selectedTime) {
      setState(() => selectedTime = picked);
    }
  }

  /// ---------- REUSABLE WIDGETS ----------
  TextStyle _labelTextStyle() {
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    );
  }

  Widget _locationBox(IconData icon, Color color, String text) {
    return Container(
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _inputBox(String hint) {
    return Container(
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          hint,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
      ),
    );
  }

  Widget _vehicleBox(int index, String iconPath) {
    bool isSelected = selectedVehicle == index;
    return GestureDetector(
      onTap: () => setState(() => selectedVehicle = index),
      child: Container(
        height: 80,
        width: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(child: Image.asset(iconPath, height: 40)),
      ),
    );
  }
}



class LocationSearchPage extends StatefulWidget {
  final String initialQuery;
  final String title;

  const LocationSearchPage({
    super.key,
    required this.initialQuery,
    required this.title,
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
      // Get current location
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

      // Fetch nearby places (restaurants, cafes, etc.)
      await _fetchNearbyPlaces();
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
        '&radius=2000' // 2km radius
        '&type=establishment' // You can change to: restaurant, cafe, etc.
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
                    })
                .take(5)); // Show only top 5
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
                  Navigator.pop(context, _currentAddress);
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
                      Navigator.pop(context, "${place['name']}, ${place['address']}");
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
                          onTap: () {
                            Navigator.pop(context, place['description']);
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
                onPressed: () {
                  Navigator.pop(context, _searchController.text);
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
        '&location=${_currentPosition?.latitude ?? 19.0760},${_currentPosition?.longitude ?? 72.8777}' // Mumbai default
        '&radius=10000' // 10km radius
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}