import 'dart:math';

import 'package:flutter/material.dart';
import 'package:trogo_app/location_permission_screen.dart';
import 'package:trogo_app/wigets/search_drop_loaction.dart';

class TransprterPickupDropUI extends StatefulWidget {
  final SelectedLocation? currentLocation;
  final SelectedLocation? destinationLocation;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final Function(Map<String, dynamic>)? onPickupUpdated;
  final Function(Map<String, dynamic>)? onDropoffUpdated;
  final VoidCallback onEditPickup;
  final VoidCallback onEditDropoff;

  const TransprterPickupDropUI({
    super.key,
    required this.currentLocation,
    required this.destinationLocation,
    required this.onBack,
    required this.onNext,
    this.onPickupUpdated,
    this.onDropoffUpdated,
    required this.onEditPickup,
    required this.onEditDropoff,
  });

  @override
  _TransprterPickupDropUIState createState() => _TransprterPickupDropUIState();
}

class _TransprterPickupDropUIState extends State<TransprterPickupDropUI> {
  bool _isPromoApplied = false;
  String? _promoCode;
  final TextEditingController _promoController = TextEditingController();
  bool _showPromoField = false;
  SelectedLocation? _tempPickupLocation;
  SelectedLocation? _tempDropoffLocation;
  String _distance = '-- km';
  String _duration = '-- min';
  String _fare = '₹--';
  bool _isCalculating = false;

  @override
  void initState() {
    super.initState();
    _tempPickupLocation = widget.currentLocation;
    _tempDropoffLocation = widget.destinationLocation;
    _calculateRouteIfBothLocationsExist();
    // Print initial values for debugging
    print('🔄 TransprterPickupDropUI Initialized:');
    print('   Current Location: ${widget.currentLocation?.address}');
    print('   Destination Location: ${widget.destinationLocation?.address}');
    print('   Dest Latitude: ${widget.destinationLocation?.latitude}');
    print('   Dest Longitude: ${widget.destinationLocation?.longitude}');
  }

  @override
  void didUpdateWidget(TransprterPickupDropUI oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.destinationLocation != oldWidget.destinationLocation) {
      setState(() => _tempDropoffLocation = widget.destinationLocation);
    }
    if (widget.currentLocation != oldWidget.currentLocation) {
      setState(() => _tempPickupLocation = widget.currentLocation);
    }

    _calculateRouteIfBothLocationsExist();
  }

  void _calculateRouteIfBothLocationsExist() {
    if (_tempPickupLocation != null && _tempDropoffLocation != null) {
      _calculateRoute();
    }
  }

  Future<void> _calculateRoute() async {
    setState(() => _isCalculating = true);

    // Simulated calculation - Replace with actual Google Maps API call
    await Future.delayed(Duration(seconds: 1));

    if (_tempPickupLocation != null && _tempDropoffLocation != null) {
      // Calculate distance using Haversine formula
      final distanceKm = _calculateDistance(
        _tempPickupLocation!.latitude,
        _tempPickupLocation!.longitude,
        _tempDropoffLocation!.latitude,
        _tempDropoffLocation!.longitude,
      );

      // Calculate fare (₹50 base + ₹12 per km)
      final calculatedFare = 50 + (distanceKm * 12).round();
      final estimatedTime = (distanceKm * 3).round(); // 3 minutes per km

      setState(() {
        _distance = '${distanceKm.toStringAsFixed(1)} km';
        _duration = '${estimatedTime}-${estimatedTime + 5} min';
        _fare = '₹$calculatedFare';
        _isCalculating = false;
      });
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371.0; // Earth's radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  // @override
  // void didUpdateWidget(TransprterPickupDropUI oldWidget) {
  //   super.didUpdateWidget(oldWidget);

  //   // Debug prints
  //   print('📝 TransprterPickupDropUI didUpdateWidget:');
  //   print('   Old Dest: ${oldWidget.destinationLocation?.address}');
  //   print('   New Dest: ${widget.destinationLocation?.address}');
  //   print('   Old Current: ${oldWidget.currentLocation?.address}');
  //   print('   New Current: ${widget.currentLocation?.address}');

  //   if (widget.destinationLocation != oldWidget.destinationLocation) {
  //     setState(() {
  //       _tempDropoffLocation = widget.destinationLocation;
  //     });
  //     print('✅ Destination location updated');
  //   }
  //   if (widget.currentLocation != oldWidget.currentLocation) {
  //     setState(() {
  //       _tempPickupLocation = widget.currentLocation;
  //     });
  //     print('✅ Pickup location updated');
  //   }
  // }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _editPickupLocation() async {
    print('📍 Editing pickup location...');

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SearchDestinationUI(
                    currentLocation: _tempPickupLocation,
                    onSearchTap: () {
                      print('🗺️ Opening map for pickup location');
                    },
                    onNext: (selectedData) {
                      // This won't be called in pickup mode
                      print('Next pressed in pickup edit mode');
                    },
                    mode: 'pickup',
                    initialValue: _tempPickupLocation?.address,
                    onDestinationSelected: (locationData) {
                      print('🎯 New pickup location selected:');
                      print('   Description: ${locationData['description']}');
                      print('   Address: ${locationData['address']}');
                      print('   Latitude: ${locationData['latitude']}');
                      print('   Longitude: ${locationData['longitude']}');

                      setState(() {
                        _tempPickupLocation = SelectedLocation(
                          latitude:
                              locationData['latitude'] is double
                                  ? locationData['latitude'] as double
                                  : double.tryParse(
                                        locationData['latitude'].toString(),
                                      ) ??
                                      0.0,
                          longitude:
                              locationData['longitude'] is double
                                  ? locationData['longitude'] as double
                                  : double.tryParse(
                                        locationData['longitude'].toString(),
                                      ) ??
                                      0.0,
                          address:
                              locationData['description'] ??
                              locationData['address'],
                        );
                      });

                      // Call callback if provided
                      widget.onPickupUpdated?.call(locationData);

                      // Go back after selecting
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ),
      ),
    );
  }

  Future<void> _editDropoffLocation() async {
    print('🎯 Editing dropoff location...');

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SearchDestinationUI(
                    currentLocation: _tempPickupLocation,
                    onSearchTap: () {
                      print('🗺️ Opening map for dropoff location');
                    },
                    onNext: (selectedData) {
                      print('✅ Dropoff location selected via Next button:');
                      print('   Data: $selectedData');

                      // Update dropoff location
                      if (selectedData != null && selectedData.isNotEmpty) {
                        _updateDropoffLocation(selectedData);
                        Navigator.pop(context);
                      }
                    },
                    mode: 'dropoff',
                    initialValue: _tempDropoffLocation?.address,
                    onDestinationSelected: (locationData) {
                      print('🎯 Dropoff location selected via search:');
                      print('   Description: ${locationData['description']}');
                      print('   Address: ${locationData['address']}');

                      // Update dropoff location
                      _updateDropoffLocation(locationData);

                      // Don't pop immediately - let user press Next button
                      // Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ),
      ),
    );
  }

  void _updateDropoffLocation(Map<String, dynamic> locationData) {
    print('🔄 Updating dropoff location with:');
    print('   Description: ${locationData['description']}');
    print('   Address: ${locationData['address']}');
    print('   Latitude: ${locationData['latitude']}');
    print('   Longitude: ${locationData['longitude']}');

    setState(() {
      _tempDropoffLocation = SelectedLocation(
        latitude:
            locationData['latitude'] is double
                ? locationData['latitude'] as double
                : double.tryParse(locationData['latitude'].toString()) ?? 0.0,
        longitude:
            locationData['longitude'] is double
                ? locationData['longitude'] as double
                : double.tryParse(locationData['longitude'].toString()) ?? 0.0,
        address: locationData['description'] ?? locationData['address'],
      );
    });

    // Call callback if provided
    widget.onDropoffUpdated?.call(locationData);
  }

  void _applyPromoCode() {
    final code = _promoController.text.trim();
    if (code.isNotEmpty) {
      setState(() {
        _promoCode = code;
        _isPromoApplied = true;
        _showPromoField = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Promo code $code applied successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _removePromoCode() {
    setState(() {
      _promoCode = null;
      _isPromoApplied = false;
      _promoController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Promo code removed'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _togglePromoField() {
    setState(() {
      _showPromoField = !_showPromoField;
      if (!_showPromoField) {
        _promoController.clear();
      }
    });
  }

  void _goNowBooking() {
    print('🚕 Go Now booking initiated');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Finding nearest available driver...'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildLocationSection({
    required String title,
    required String? address,
    required Color iconColor,
    required bool isPickup,
    bool showCoordinates = true,
  }) {
    final location = isPickup ? _tempPickupLocation : _tempDropoffLocation;

    return GestureDetector(
      onTap: isPickup ? _editPickupLocation : _editDropoffLocation,
      child: Container(
        padding: EdgeInsets.only(bottom: isPickup ? 12 : 0),
        decoration:
            isPickup
                ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                )
                : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Spacer(),
                Icon(Icons.edit, size: 14, color: Colors.grey.shade500),
              ],
            ),
            SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon for pickup/dropoff
                Container(
                  margin: EdgeInsets.only(top: 2),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isPickup ? Colors.green.shade50 : Colors.red.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isPickup ? Colors.green : Colors.red,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isPickup ? Icons.location_on : Icons.flag,
                    size: 10,
                    color: isPickup ? Colors.green : Colors.red,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address ??
                            (isPickup
                                ? "My current location"
                                : "Search destination"),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              address != null
                                  ? Colors.black
                                  : Colors.grey.shade500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showCoordinates &&
                          location != null &&
                          location.address != null) ...[
                        SizedBox(height: 4),
                        Text(
                          "Lat: ${location.latitude.toStringAsFixed(6)}, Lng: ${location.longitude.toStringAsFixed(6)}",
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                      // Display mode for debugging
                      if (isPickup && _tempPickupLocation != null)
                        Text(
                          "Mode: Pickup | Lat: ${_tempPickupLocation!.latitude}, Lng: ${_tempPickupLocation!.longitude}",
                          style: TextStyle(fontSize: 8, color: Colors.grey),
                        ),
                      if (!isPickup && _tempDropoffLocation != null)
                        Text(
                          "Mode: Dropoff | Lat: ${_tempDropoffLocation!.latitude}, Lng: ${_tempDropoffLocation!.longitude}",
                          style: TextStyle(fontSize: 8, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ Building TransprterPickupDropUI');
    print('   _tempDropoffLocation: ${_tempDropoffLocation?.address}');
    print('   _tempPickupLocation: ${_tempPickupLocation?.address}');
    print('   Destination exists: ${_tempDropoffLocation != null}');

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// -------- HEADER --------
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    print('🔙 Back button pressed');
                    widget.onBack();
                  },
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Confirm your trip details",
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

            /// -------- PICKUP + DROPOFF BOX --------
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xffF7F9FB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Green timeline with icons
                  Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.green.shade300,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 40,
                        color: Colors.green.shade200,
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.red.shade300,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.flag,
                          size: 16,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(width: 14),

                  /// Address details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// PICKUP SECTION
                        _buildLocationSection(
                          title: "Pick-up",
                          address: _tempPickupLocation?.address,
                          iconColor: Colors.green,
                          isPickup: true,
                        ),

                        SizedBox(height: 16),

                        _buildLocationSection(
                          title:
                              widget.destinationLocation != null
                                  ? "Drop off"
                                  : "Drop off (optional)",
                          address: widget.destinationLocation?.address,
                          iconColor: Colors.red,
                          isPickup: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),
            if (_showPromoField)
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_offer, size: 16, color: Colors.orange),
                        SizedBox(width: 6),
                        Text(
                          "Enter Promo Code",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _promoController,
                            decoration: InputDecoration(
                              hintText: "e.g., WELCOME50, TRIP25",
                              hintStyle: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.blue.shade400,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _applyPromoCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            "Apply",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Apply promo code to get discounts on your ride",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            if (_isPromoApplied && _promoCode != null)
              Container(
                margin: EdgeInsets.only(top: 10),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check, size: 14, color: Colors.white),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Promo Applied",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _promoCode!,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _removePromoCode,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 20),
            // Row(children: [SizedBox(width: 12)]),
            // SizedBox(height: 22),
            // if (_tempDropoffLocation != null)
            //   Container(
            //     padding: EdgeInsets.all(16),
            //     decoration: BoxDecoration(
            //       color: Colors.white,
            //       borderRadius: BorderRadius.circular(14),
            //       border: Border.all(color: Colors.grey.shade300),
            //       boxShadow: [
            //         BoxShadow(
            //           color: Colors.black.withOpacity(0.05),
            //           blurRadius: 6,
            //           offset: Offset(0, 3),
            //         ),
            //       ],
            //     ),
            //     child: Column(
            //       children: [
            //         Row(
            //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //           children: [
            //             Row(
            //               children: [
            //                 Icon(
            //                   Icons.dangerous_rounded,
            //                   size: 14,
            //                   color: Colors.blue.shade600,
            //                 ),
            //                 SizedBox(width: 6),
            //                 Text(
            //                   "Estimated Distance",
            //                   style: TextStyle(
            //                     fontSize: 12,
            //                     color: Colors.grey.shade600,
            //                   ),
            //                 ),
            //               ],
            //             ),
            //             Text(
            //               "${_distance}",
            //               style: TextStyle(
            //                 fontSize: 13,
            //                 fontWeight: FontWeight.w700,
            //                 color: Colors.black87,
            //               ),
            //             ),
            //           ],
            //         ),
            //         SizedBox(height: 12),
            //         Divider(height: 1, color: Colors.grey.shade200),
            //         SizedBox(height: 12),
            //         // Row(
            //         //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //         //   children: [
            //         //     Row(
            //         //       children: [
            //         //         Icon(
            //         //           Icons.timer,
            //         //           size: 14,
            //         //           color: Colors.orange.shade600,
            //         //         ),
            //         //         SizedBox(width: 6),
            //         //         Text(
            //         //           "Estimated Time",
            //         //           style: TextStyle(
            //         //             fontSize: 12,
            //         //             color: Colors.grey.shade600,
            //         //           ),
            //         //         ),
            //         //       ],
            //         //     ),
            //         //     Text(
            //         //       "${_duration}",
            //         //       style: TextStyle(
            //         //         fontSize: 13,
            //         //         fontWeight: FontWeight.w700,
            //         //         color: Colors.black87,
            //         //       ),
            //         //     ),
            //         //   ],
            //         // ),
            //         SizedBox(height: 12),
            //         Divider(height: 1, color: Colors.grey.shade200),
            //         SizedBox(height: 12),
            //         Row(
            //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //           children: [
            //             // Row(
            //             //   children: [
            //             //     Icon(
            //             //       Icons.currency_rupee,
            //             //       size: 14,
            //             //       color: Colors.green.shade600,
            //             //     ),
            //             //     SizedBox(width: 6),
            //             //     Text(
            //             //       "Estimated Fare",
            //             //       style: TextStyle(
            //             //         fontSize: 12,
            //             //         color: Colors.grey.shade600,
            //             //       ),
            //             //     ),
            //             //   ],
            //             // ),
            //             // Column(
            //             //   crossAxisAlignment: CrossAxisAlignment.end,
            //             //   children: [
            //             //     if (_isPromoApplied)
            //             //       Text(
            //             //         "₹295",
            //             //         style: TextStyle(
            //             //           fontSize: 11,
            //             //           color: Colors.grey.shade500,
            //             //           decoration: TextDecoration.lineThrough,
            //             //         ),
            //             //       ),
            //             //     Text(
            //             //       _isPromoApplied ? "₹245" : "₹295",
            //             //       style: TextStyle(
            //             //         fontSize: 16,
            //             //         fontWeight: FontWeight.w800,
            //             //         color: _isPromoApplied
            //             //             ? Colors.green.shade700
            //             //             : Colors.black87,
            //             //       ),
            //             //     ),
            //             //   ],
            //             // ),
            //           ],
            //         ),
            //         if (_isPromoApplied) ...[
            //           SizedBox(height: 12),
            //           Divider(height: 1, color: Colors.grey.shade200),
            //           SizedBox(height: 12),
            //           Row(
            //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //             children: [
            //               Row(
            //                 children: [
            //                   Icon(
            //                     Icons.discount,
            //                     size: 14,
            //                     color: Colors.green.shade600,
            //                   ),
            //                   SizedBox(width: 6),
            //                   Text(
            //                     "Discount Applied",
            //                     style: TextStyle(
            //                       fontSize: 12,
            //                       color: Colors.green.shade600,
            //                     ),
            //                   ),
            //                 ],
            //               ),
            //               Text(
            //                 "-₹50",
            //                 style: TextStyle(
            //                   fontSize: 13,
            //                   fontWeight: FontWeight.w700,
            //                   color: Colors.green.shade700,
            //                 ),
            //               ),
            //             ],
            //           ),
            //         ],
            //       ],
            //     ),
            //   ),

            // SizedBox(height: 22),

            /// -------- NEXT BUTTON --------
            ElevatedButton(
              onPressed:
                  _tempDropoffLocation != null
                      ? () {
                        print('🚀 Continue to Choose Ride button pressed');
                        print(
                          '   Dropoff Location: ${_tempDropoffLocation?.address}',
                        );
                        print(
                          '   Dropoff Lat: ${_tempDropoffLocation?.latitude}',
                        );
                        print(
                          '   Dropoff Lng: ${_tempDropoffLocation?.longitude}',
                        );
                        widget.onNext();
                      }
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _tempDropoffLocation != null
                        ? Colors.black
                        : Colors.grey.shade400,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Continue to Choose Ride",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),

            SizedBox(height: 14),

            /// -------- SAFETY MESSAGE --------
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield,
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Safety First",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "All drivers are verified, rides are tracked in real-time, and you can share your trip status with trusted contacts.",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
