import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trogo_app/auth/login_notifier.dart';
import 'package:trogo_app/location_permission_screen.dart';
import 'package:trogo_app/models/estimateurl_model.dart';

class ChooseRideUI extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final Function(String, String, int) onSelect;
  final SelectedLocation? pickupLocation;
  final SelectedLocation? destinationLocation;
  final bool isLoading;
  final bool isGoodsTransport;


  const ChooseRideUI({
    super.key,
    required this.onBack,
    required this.onSelect,
    this.pickupLocation,
    this.destinationLocation,
    this.isLoading = false,
    this.isGoodsTransport = true,
  });

  @override
  ConsumerState<ChooseRideUI> createState() => _ChooseRideUIState();
}

class _ChooseRideUIState extends ConsumerState<ChooseRideUI> {
  String? selectedVehicleId;
  String? selectedVehicleName;
  int? price;
  bool _isLoadingFare = true;
  Timer? _loadingTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _printLocationDetails();
    _fetchFareEstimates();
  }

  @override
  void didUpdateWidget(covariant ChooseRideUI oldWidget) {
    super.didUpdateWidget(oldWidget);

    final pickupChanged =
        oldWidget.pickupLocation?.latitude != widget.pickupLocation?.latitude ||
        oldWidget.pickupLocation?.longitude !=
            widget.pickupLocation?.longitude ||
        oldWidget.pickupLocation?.address != widget.pickupLocation?.address;
    final dropChanged =
        oldWidget.destinationLocation?.latitude !=
            widget.destinationLocation?.latitude ||
        oldWidget.destinationLocation?.longitude !=
            widget.destinationLocation?.longitude ||
        oldWidget.destinationLocation?.address !=
            widget.destinationLocation?.address;

    if (pickupChanged || dropChanged) {
      _fetchFareEstimates();
    }
  }

  Future<void> _fetchFareEstimates() async {
    final pickup = widget.pickupLocation;
    final drop = widget.destinationLocation;

    _loadingTimer?.cancel();
    if (mounted) {
      setState(() {
        _isLoadingFare = true;
        selectedVehicleId = null;
        selectedVehicleName = null;
        price = null;
      });
    }

    if (pickup == null || drop == null) {
      if (mounted) {
        setState(() {
          _isLoadingFare = false;
        });
      }
      return;
    }

    try {
      await fareEstimateApi(
        category: widget.isGoodsTransport ? "goods" : "passenger",
        ref: ref,
        vehicleTypeId: '',
        pickupAddress: pickup.address.toString(),
        pickupCoordinates: [pickup.longitude, pickup.latitude],
        dropAddress: drop.address.toString(),
        dropCoordinates: [drop.latitude, drop.longitude],
      );
    } finally {
      _startLoadingSimulation();
    }
  }

  void _startLoadingSimulation() {
    _loadingTimer?.cancel();
    _loadingTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isLoadingFare = false;
        });
      }
    });
  }

  void _printLocationDetails() {
    print('📍 ChooseRideUI Location Details:');
    print('   Pickup: ${widget.pickupLocation?.address}');
    print('   Pickup Coordinates: ${widget.pickupLocation?.latitude}, ${widget.pickupLocation?.longitude}');
    print('   Destination: ${widget.destinationLocation?.address}');
    print('   Destination Coordinates: ${widget.destinationLocation?.latitude}, ${widget.destinationLocation?.longitude}');
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectionButton() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  double? _directTripDistanceKm() {
    final pickup = widget.pickupLocation;
    final drop = widget.destinationLocation;
    if (pickup == null || drop == null) return null;

    final meters = Geolocator.distanceBetween(
      pickup.latitude,
      pickup.longitude,
      drop.latitude,
      drop.longitude,
    );
    return meters / 1000;
  }

  bool _shouldNormalizeApiValues(FareEstimate fareEstimate) {
    final directKm = _directTripDistanceKm();
    if (directKm == null) {
      return fareEstimate.distanceKm >= 1000 || fareEstimate.etaMinutes >= 5000;
    }

    final rawDistance = fareEstimate.distanceKm;
    final scaledDistance = rawDistance / 1000;
    final rawDifference = (rawDistance - directKm).abs();
    final scaledDifference = (scaledDistance - directKm).abs();
    final rawClearlyWrong =
        rawDistance > math.max(50, directKm * 20) ||
        fareEstimate.etaMinutes > 5000;
    final scaledClearlyBetter =
        scaledDifference < rawDifference &&
        scaledDifference <= math.max(2, directKm * 3);

    return rawClearlyWrong && scaledClearlyBetter;
  }

  double _displayDistanceKm(FareEstimate fareEstimate, bool normalizeValues) {
    return normalizeValues ? fareEstimate.distanceKm / 1000 : fareEstimate.distanceKm;
  }

  int _displayEtaMinutes(FareEstimate fareEstimate, bool normalizeValues) {
    final eta = normalizeValues
        ? fareEstimate.etaMinutes / 1000
        : fareEstimate.etaMinutes.toDouble();
    return math.max(1, eta.round());
  }

  int _displayFare(FareEstimate fareEstimate, bool normalizeValues) {
    final fare = normalizeValues
        ? fareEstimate.estimatedFare / 1000
        : fareEstimate.estimatedFare.toDouble();
    return math.max(1, fare.round());
  }

  @override
  Widget build(BuildContext context) {
    final fareEstimates = ref.watch(fareEstimateProvider);
    final topSpacing = MediaQuery.of(context).padding.top > 24 ? 12.0 : 4.0;
    final shouldNormalizeValues =
        fareEstimates.isNotEmpty && _shouldNormalizeApiValues(fareEstimates.first);

    // Check if we should show loading
    final bool showLoading = _isLoadingFare || widget.isLoading;

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topSpacing),
          /// HEADER
          Row(
            children: [
              GestureDetector(
                onTap: widget.onBack,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.black, size: 20),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Choose your ride",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: Colors.green),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.pickupLocation?.address ?? "Pickup location",
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
                        Expanded(
                          child: Text(
                            widget.destinationLocation?.address ?? "Destination",
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          /// SHIMMER LOADING EFFECT
          if (showLoading)
            _buildLoadingShimmer()
          else if (fareEstimates.isNotEmpty)
            Column(
              children: [
                /// TRIP SUMMARY
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Trip Distance",
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "${_displayDistanceKm(fareEstimates.first, shouldNormalizeValues).toStringAsFixed(1)} km",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "Estimated Time",
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "${_displayEtaMinutes(fareEstimates.first, shouldNormalizeValues)} min",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                /// VEHICLE LIST
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: fareEstimates.length,
                  itemBuilder: (context, index) {
                    final fareEstimate = fareEstimates[index];
                    final isSelected = selectedVehicleId == fareEstimate.vehicleTypeId;
                    final displayFare = _displayFare(
                      fareEstimate,
                      shouldNormalizeValues,
                    );
                    final displayDistance = _displayDistanceKm(
                      fareEstimate,
                      shouldNormalizeValues,
                    );
                    final displayEta = _displayEtaMinutes(
                      fareEstimate,
                      shouldNormalizeValues,
                    );
                    final displayFareText = '${String.fromCharCode(0x20B9)}$displayFare';

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedVehicleId = fareEstimate.vehicleTypeId;
                          selectedVehicleName = fareEstimate.name;
                          price = displayFare;
                        });
                        _scrollToSelectionButton();
                        print('Selected Vehicle: ${fareEstimate.name}');
                        print('   Fare: ${displayFareText}');
                      },
                      child: Container(
                        margin: EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? Colors.green : Colors.grey.shade300,
                            width: isSelected ? 1.7 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            /// VEHICLE IMAGE
                            Container(
                              width: 60,
                              height: 43,
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(10),
                                image: DecorationImage(
                                  image: NetworkImage(fareEstimate.image),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),

                            SizedBox(width: 12),

                            /// VEHICLE DETAILS
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        fareEstimate.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      // if (fareEstimate.bestFor != null)
                                      //   Container(
                                      //     padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      //     decoration: BoxDecoration(
                                      //       color: Colors.orange[100],
                                      //       borderRadius: BorderRadius.circular(4),
                                      //     ),
                                      //     child: Text(
                                      //       fareEstimate.bestFor!,
                                      //       style: TextStyle(
                                      //         color: Colors.orange[800],
                                      //         fontSize: 8,
                                      //       ),
                                      //     ),
                                      //   ),
                                    ],
                                  ),

                                  SizedBox(height: 6),

                                  Text(
                                    "Best for: ${fareEstimate.bestFor ?? 'Comfortable ride'}",
                                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                  ),

                                  SizedBox(height: 8),

                                  Row(
                                    children: [
                                      Icon(Icons.speed, size: 12, color: Colors.grey[600]),
                                      SizedBox(width: 4),
                                      Text(
                                        "${displayDistance.toStringAsFixed(1)} km",
                                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                      ),
                                      SizedBox(width: 12),
                                      Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                                      SizedBox(width: 4),
                                      Text(
                                        "$displayEta min",
                                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            /// PRICE AND SELECTION
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  displayFareText,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? Colors.green : Colors.grey,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Container(
                                          margin: EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.green,
                                          ),
                                        )
                                      : SizedBox(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            )
          else
            _buildEmptyState(),

          SizedBox(height: 20),

          /// SELECT BUTTON
          if (!showLoading && fareEstimates.isNotEmpty && selectedVehicleName != null)
            ElevatedButton(
              onPressed: () {
                print('🎯 Final selection: $selectedVehicleName');
                print('   ID: $selectedVehicleId');
                
                widget.onSelect(
                  selectedVehicleName!,
                  selectedVehicleId!,
                  price!,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize: Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "Select $selectedVehicleName",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),

          SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Column(
      children: [
        // Trip summary loading
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 12,
                    color: Colors.grey[300],
                    margin: EdgeInsets.only(bottom: 8),
                  ),
                  Container(
                    width: 40,
                    height: 16,
                    color: Colors.grey[300],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 60,
                    height: 12,
                    color: Colors.grey[300],
                    margin: EdgeInsets.only(bottom: 8),
                  ),
                  Container(
                    width: 40,
                    height: 16,
                    color: Colors.grey[300],
                  ),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: 20),

        // Vehicle list loading (3 items)
        for (int i = 0; i < 3; i++)
          Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                // Vehicle image loading
                Container(
                  width: 60,
                  height: 43,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                SizedBox(width: 12),

                // Vehicle details loading
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80,
                        height: 14,
                        color: Colors.grey[200],
                        margin: EdgeInsets.only(bottom: 8),
                      ),
                      Container(
                        width: 120,
                        height: 12,
                        color: Colors.grey[200],
                        margin: EdgeInsets.only(bottom: 12),
                      ),
                      Container(
                        width: 100,
                        height: 10,
                        color: Colors.grey[200],
                      ),
                    ],
                  ),
                ),

                // Price loading
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 50,
                      height: 16,
                      color: Colors.grey[200],
                      margin: EdgeInsets.only(bottom: 8),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.directions_car, size: 50, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No vehicles available',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              'Please try again later',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchFareEstimates,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}  

//rider screen
