import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trogo_app/auth/login_notifier.dart';
import 'package:trogo_app/location_permission_screen.dart';

class ChooseRideUI extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final Function(String, String,int) onSelect;
  final VoidCallback? onEditPickup;
  final VoidCallback? onEditDropoff;
  final SelectedLocation? pickupLocation;
  final SelectedLocation? destinationLocation;
  final bool isLoading;
  final bool? isGoodsTransport;


  const ChooseRideUI({
    super.key, 
    required this.onBack, 
    required this.onSelect,
    this.onEditPickup,
    this.onEditDropoff,
    this.pickupLocation,
    this.destinationLocation,
    this.isLoading = false,
    this.isGoodsTransport = false,
   
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

  bool _hasValidCoordinates(SelectedLocation? location) {
    if (location == null) return false;
    if (!location.latitude.isFinite || !location.longitude.isFinite) {
      return false;
    }
    return !(location.latitude == 0.0 && location.longitude == 0.0);
  }

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

    if (!_hasValidCoordinates(pickup) || !_hasValidCoordinates(drop)) {
      if (mounted) {
        setState(() {
          _isLoadingFare = false;
        });
      }
      return;
    }

    final validPickup = pickup!;
    final validDrop = drop!;

    try {
      print("pickup lat: ${validPickup.latitude}, lng: ${validPickup.longitude}");
      print("drop lat: ${validDrop.latitude}, lng: ${validDrop.longitude}");
      print("pickup coords sent: ${[validPickup.latitude, validPickup.longitude]}");
      print("drop coords sent: ${[validDrop.latitude, validDrop.longitude]}");
      await fareEstimateApi(
        category: (widget.isGoodsTransport ?? false) ? "goods" : "passenger",
        ref: ref,
        vehicleTypeId: '',
        pickupAddress: validPickup.address ?? "Pickup Location",
        pickupCoordinates: [validPickup.longitude, validPickup.latitude],
        dropAddress: validDrop.address ?? "Destination",
        dropCoordinates: [validDrop.longitude, validDrop.latitude],
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

  @override
  Widget build(BuildContext context) {
    final fareEstimates = ref.watch(fareEstimateProvider);
    final topSpacing = MediaQuery.of(context).padding.top > 24 ? 12.0 : 4.0;

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
                    SizedBox(height: 8),
                    Row(
                      children: [
                        if (widget.onEditPickup != null)
                          TextButton.icon(
                            onPressed: widget.onEditPickup,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(
                              Icons.edit_location_alt_outlined,
                              size: 16,
                              color: Colors.green[700],
                            ),
                            label: Text(
                              "Change Pickup",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        SizedBox(width: 12),
                        if (widget.onEditDropoff != null)
                          TextButton.icon(
                            onPressed: widget.onEditDropoff,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(
                              Icons.edit_road_outlined,
                              size: 16,
                              color: Colors.orange[700],
                            ),
                            label: Text(
                              "Change Drop",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[700],
                              ),
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
                            "${fareEstimates.first.distanceKm?.toStringAsFixed(1) ?? '0.0'} km",
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
                            "${fareEstimates.first.etaMinutes ?? 0} min",
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

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedVehicleId = fareEstimate.vehicleTypeId;
                          selectedVehicleName = fareEstimate.name;
                          selectedVehicleName = fareEstimate.name;
                          price = fareEstimate.estimatedFare;
                        });
                        _scrollToSelectionButton();
                        print('✅ Selected Vehicle: ${fareEstimate.name}');
                        print('   Fare: ₹${fareEstimate.estimatedFare}');
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
                                        "${fareEstimate.distanceKm?.toStringAsFixed(1) ?? '0.0'} km",
                                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                      ),
                                      SizedBox(width: 12),
                                      Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                                      SizedBox(width: 4),
                                      Text(
                                        "${fareEstimate.etaMinutes ?? 0} min",
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
                                  "₹${fareEstimate.estimatedFare}",
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
                
                // Send ride request with location data
                widget.onSelect(selectedVehicleName!, selectedVehicleId!,price!);
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
              child: Text('Retry',style: TextStyle(color: Colors.white),),
            ),
          ],
        ),
      ),
    );
  }
}  

//rider screen
