import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:trogo_app/models/vehicle_type_model.dart';
import 'package:trogo_app/prefs/app_preference.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/transportergoods/tracking_screen.dart';

class GoodsDetailsPage extends StatefulWidget {
  final String pickupLocation;
  final String deliveryLocation;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final VehicleType selectedVehicle;
  final Position? pickupPosition;
  final Position? deliveryPosition;
  final Function(String, Map<String, dynamic>)? onBookingCreated;

  const GoodsDetailsPage({
    Key? key,
    required this.pickupLocation,
    required this.deliveryLocation,
    this.selectedDate,
    this.selectedTime,
    required this.selectedVehicle,
    this.pickupPosition,
    this.deliveryPosition,
    this.onBookingCreated,
  }) : super(key: key);

  @override
  State<GoodsDetailsPage> createState() => _GoodsDetailsPageState();
}

class _GoodsDetailsPageState extends State<GoodsDetailsPage> {
  // Form fields
  String payer = "recipient";
  String paymentType = "cash";
  String goodsName = "";

  // Weight fields - ONLY for PER_KM
  String goodsWeight = "";
  String weightUnit = "KG";
  List<String> weightUnits = ["KG", "TON", "QUINTLE", "NOS"];

  // PER_HOUR field
  double? _hours;

  // PER_KM fields
  double? _distanceKm;
  bool _isCalculatingDistance = false;

  String receiverName = "";
  String receiverPhone = "";

  // Images
  List<File> pickedImages = [];
  final ImagePicker _picker = ImagePicker();

  // Form and state
  final _formKey = GlobalKey<FormState>();
  bool isSubmitting = false;
  String? _bookingId;

  // Fare calculation
  double _estimatedFare = 0.0;
  Timer? _fareTimer;

  @override
  void initState() {
    super.initState();
    _initializePricingFields();
    _calculateFare();
    _fareTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _calculateFare();
    });
  }

  void _initializePricingFields() {
    final pricingType = widget.selectedVehicle.pricingType ?? 'PER_KM';

    if (pricingType == 'PER_HOUR') {
      // PER_HOUR साठी default 1 hour
      _hours = 1.0;
    } else {
      // PER_KM साठी distance calculate करा
      _calculateDistance();
    }
  }

  Future<void> _calculateDistance() async {
    if (widget.pickupPosition != null && widget.deliveryPosition != null) {
      setState(() => _isCalculatingDistance = true);

      try {
        final distanceInMeters = await Geolocator.distanceBetween(
          widget.pickupPosition!.latitude,
          widget.pickupPosition!.longitude,
          widget.deliveryPosition!.latitude,
          widget.deliveryPosition!.longitude,
        );

        setState(() {
          _distanceKm = distanceInMeters / 1000;
          _isCalculatingDistance = false;
        });
      } catch (e) {
        print('Error calculating distance: $e');
        setState(() {
          _distanceKm = 10.0; // default distance
          _isCalculatingDistance = false;
        });
      }
    } else {
      print('Pickup or delivery position is null');
      setState(() {
        _distanceKm = 10.0; // default distance
      });
    }
  }

  @override
  void dispose() {
    _fareTimer?.cancel();
    super.dispose();
  }

  void _calculateFare() {
    try {
      double baseFare = 100.0;
      // Ensure vehicleRate is double
      double vehicleRate = (widget.selectedVehicle.rate ?? 0.0).toDouble();
      final pricingType = widget.selectedVehicle.pricingType ?? 'PER_KM';

      double estimatedFare = baseFare;

      // pricingType नुसार calculation
      if (pricingType == 'PER_HOUR') {
        // PER_HOUR साठी: rate * hours
        if (_hours != null && _hours! > 0) {
          estimatedFare += vehicleRate * _hours!;
        } else {
          estimatedFare += vehicleRate * 1; // default 1 hour
        }
      } else {
        // PER_KM साठी: rate * distance + weight charges
        double weightValue = double.tryParse(goodsWeight) ?? 0.0;
        double weightMultiplier = weightValue * 5.0;

        if (_distanceKm != null && _distanceKm! > 0) {
          estimatedFare += (vehicleRate * _distanceKm!) + weightMultiplier;
        } else {
          estimatedFare +=
              (vehicleRate * 10.0) + weightMultiplier; // default 10 km
        }
      }

      setState(() {
        _estimatedFare = estimatedFare;
      });
    } catch (e) {
      print('Error calculating fare: $e');
      print('Vehicle rate: ${widget.selectedVehicle.rate}');
      print('Rate type: ${widget.selectedVehicle.rate.runtimeType}');
      setState(() {
        _estimatedFare = 100.0; // minimum fare
      });
    }
  }

  Future<void> _showImageSourceDialog() async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Select Image Source"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.camera_alt, color: Colors.blue),
                  title: Text("Camera"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library, color: Colors.green),
                  title: Text("Gallery"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Please allow camera permission")));
      return;
    }

    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1080,
    );

    if (image != null) {
      if (pickedImages.length < 3) {
        setState(() {
          pickedImages.add(File(image.path));
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Maximum 3 photos allowed")));
      }
    }
  }

 Future<void> _pickImageFromGallery() async {

  PermissionStatus status;

  if (Platform.isAndroid) {

    status = await Permission.storage.request();

    // Android 13+
    if (!status.isGranted) {
      status = await Permission.photos.request();
    }

  } else {
    status = await Permission.photos.request();
  }

  if (!status.isGranted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Gallery permission denied")),
    );
    return;
  }

  final List<XFile>? images = await _picker.pickMultiImage(
    imageQuality: 85,
  );

  if (images != null) {
    setState(() {
      pickedImages.addAll(
        images.take(3 - pickedImages.length)
              .map((e) => File(e.path)));
    });
  }
}

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    final pricingType = widget.selectedVehicle.pricingType ?? 'PER_KM';

    // PER_HOUR validation
    if (pricingType == 'PER_HOUR') {
      if (_hours == null || _hours! <= 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Please enter valid hours")));
        return;
      }
    }
    // PER_KM validation - weight required
    else {
      if (goodsWeight.isEmpty || double.tryParse(goodsWeight) == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Please enter valid weight")));
        return;
      }
    }

    if (pickedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please take at least one picture of the package"),
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final apiUrl = Uri.parse(
        'https://trogo-app-backend.onrender.com/api/bookings/bookings',
      );

      final formattedDate = DateFormat(
        'yyyy-MM-dd',
      ).format(widget.selectedDate ?? DateTime.now());
      final formattedTime =
          widget.selectedTime != null
              ? '${widget.selectedTime!.hour.toString().padLeft(2, '0')}:${widget.selectedTime!.minute.toString().padLeft(2, '0')}'
              : DateFormat('HH:mm').format(DateTime.now());

      // final vehicleTypeId = await _getVehicleTypeId(widget.selectedVehicle.id);
      final vehicleTypeId = widget.selectedVehicle.id.toString();
      final authToken = AppPreference().getString(PreferencesKey.authToken);

      if (authToken == null || authToken.isEmpty) {
        throw Exception("Authentication failed");
      }

      // Multipart request
      final request = http.MultipartRequest('POST', apiUrl);
      request.headers['Authorization'] = 'Bearer $authToken';

      // Common required fields
      request.fields.addAll({
        'bookingType': 'goods',
        'vehicleTypeId': vehicleTypeId,
        'scheduleDate': formattedDate,
        'scheduleTime': formattedTime,
        'paymentBy': payer,
        'paymentType': paymentType,
        'drop[address]': widget.deliveryLocation,
        'goods[name]': goodsName,
        'receiver[name]': receiverName,
        'receiver[phone]': receiverPhone,
        'estimatedFare': _estimatedFare.toStringAsFixed(2),
      });

      final pricingType = widget.selectedVehicle.pricingType ?? 'PER_KM';

      // PER_HOUR specific
      if (pricingType == 'PER_HOUR') {
        request.fields['hours'] = (_hours ?? 1).toString();
        // PER_HOUR साठी weight required नाही
      }
      // PER_KM specific
      else {
        request.fields['goods[weightKg]'] =
            _convertToKg(goodsWeight, weightUnit).toString();
        if (_distanceKm != null) {
          request.fields['distanceKm'] = _distanceKm!.toStringAsFixed(2);
        }
      }

      // Drop coordinates - safe null handling
      final dropLng = widget.deliveryPosition?.longitude ?? 0.0;
      final dropLat = widget.deliveryPosition?.latitude ?? 0.0;
      request.fields['drop[coordinates][0]'] = dropLng.toString();
      request.fields['drop[coordinates][1]'] = dropLat.toString();

      // Pickup coordinates - safe null handling
      if (widget.pickupPosition != null) {
        request.fields['pickup[address]'] = widget.pickupLocation;
        request.fields['pickup[coordinates][0]'] =
            widget.pickupPosition!.longitude.toString();
        request.fields['pickup[coordinates][1]'] =
            widget.pickupPosition!.latitude.toString();
      }

      // Debug - show what parameters are being sent
      print('=== API REQUEST PARAMETERS ===');
      print('Vehicle Name: ${widget.selectedVehicle.name}');
      print('Vehicle Pricing Type: $pricingType');
      final vehicleRate = (widget.selectedVehicle.rate ?? 0.0).toDouble();
      print('Vehicle Rate: $vehicleRate');

      if (pricingType == 'PER_HOUR') {
        print('Hours: $_hours');
        print('Total Fare Calculation: 100 + ($vehicleRate × ${_hours ?? 1})');
      } else {
        print('Weight: $goodsWeight $weightUnit');
        print('Distance (km): $_distanceKm');
        print(
          'Total Fare Calculation: 100 + ($vehicleRate × ${_distanceKm ?? 10}) + ($goodsWeight × 5)',
        );
      }
      print('Estimated Fare: $_estimatedFare');
      print('==============================');

      // Images
      for (int i = 0; i < pickedImages.length; i++) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'packageImage',
            pickedImages[i].path,
            filename: 'package_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
          ),
        );
      }

      final response = await request.send().timeout(Duration(seconds: 60));
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(responseBody);

        if (jsonResponse['booking'] != null) {
          final bookingId = jsonResponse['booking']['_id'];
          final bookingData = jsonResponse['booking'];

          _showSuccess("Booking created successfully!");

          // Navigate back with booking data
          if (widget.onBookingCreated != null) {
            widget.onBookingCreated!(bookingId, bookingData);
          }

          // Delay navigation to show success message
          // Future.delayed(Duration(seconds: 1), () {
          //   Navigator.pushAndRemoveUntil(
          //     context,
          //     MaterialPageRoute(
          //       builder:
          //           (_) => GoodsTrackingPage(
          //             bookingId: bookingId,
          //             bookingData: bookingData,
          //           ),
          //     ),
          //     (route) => false,
          //   );
          // });
          Navigator.pop(context);
          Navigator.pop(context);
        } else {
          throw Exception("Booking failed - no booking data received");
        }
      } else {
        print('Server Error Response: $responseBody');
        throw Exception("Server error: ${response.statusCode}");
      }
    } on TimeoutException {
      _showError("Request timeout. Please try again.");
    } catch (e) {
      _showError("Error: $e");
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  Future<String> _getVehicleTypeId(int selectedIndex) async {
    // These should come from your API
    final vehicleIds = [
      "69492240c7935ef1fa6dadf5", // Mini Truck
      "69492240c7935ef1fa6dadf6", // Truck
      "69492240c7935ef1fa6dadf7", // Large Truck
    ];

    if (selectedIndex >= 0 && selectedIndex < vehicleIds.length) {
      return vehicleIds[selectedIndex];
    }
    return vehicleIds[0];
  }

  double _convertToKg(String weight, String unit) {
    final weightValue = double.tryParse(weight) ?? 0;

    switch (unit) {
      case "KG":
        return weightValue;
      case "TON":
        return weightValue * 1000;
      case "QUINTLE":
        return weightValue * 100;
      case "NOS":
        return weightValue;
      default:
        return weightValue;
    }
  }

  void _removeImage(int index) {
    setState(() {
      pickedImages.removeAt(index);
    });
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // PER_HOUR साठी hours input
  Widget _buildHoursInput() {
    final vehicleRate = (widget.selectedVehicle.rate ?? 0.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          "Estimated Hours Required *",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        TextFormField(
          initialValue: _hours?.toStringAsFixed(1),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: "e.g., 2.5 hours",
            border: OutlineInputBorder(),
            suffixText: "hours",
          ),
          onChanged: (value) {
            final hours = double.tryParse(value) ?? 0.0;
            setState(() => _hours = hours);
            _calculateFare();
          },
          validator: (value) {
            final hours = double.tryParse(value ?? '');
            if (hours == null || hours <= 0) {
              return "Please enter valid hours";
            }
            return null;
          },
        ),
        SizedBox(height: 8),
        Text(
          "Rate: ₹$vehicleRate/hour",
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // PER_KM साठी weight आणि distance
  Widget _buildWeightAndDistanceInput() {
    final vehicleRate = (widget.selectedVehicle.rate ?? 0.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        // Weight Section
        Text("Weight *", style: TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: "Enter weight",
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() => goodsWeight = value);
                  _calculateFare();
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Required";
                  }
                  if (double.tryParse(value) == null) {
                    return "Enter valid number";
                  }
                  return null;
                },
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: weightUnit,
                items:
                    weightUnits.map((unit) {
                      return DropdownMenuItem(value: unit, child: Text(unit));
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => weightUnit = value);
                    _calculateFare();
                  }
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Unit",
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),

        // Distance Section
        Text("Distance", style: TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.directions_car, color: Colors.blue),
              SizedBox(width: 10),
              Expanded(
                child:
                    _isCalculatingDistance
                        ? Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text("Calculating distance..."),
                          ],
                        )
                        : Text(
                          _distanceKm != null
                              ? "${_distanceKm!.toStringAsFixed(2)} km"
                              : "Distance not available",
                          style: TextStyle(fontSize: 16),
                        ),
              ),
              Text(
                "Rate: ₹$vehicleRate/km",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Text(
          "Note: Fare includes ₹100 base + (₹$vehicleRate × distance) + (weight × ₹5)",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pricingType = widget.selectedVehicle.pricingType ?? 'PER_KM';
    final isPerHour = pricingType == 'PER_HOUR';
    final vehicleRate = (widget.selectedVehicle.rate ?? 0.0).toDouble();
    final vehicleName = widget.selectedVehicle.name ?? 'Vehicle';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Package Details",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location Summary
                _buildLocationSummary(),
                SizedBox(height: 20),

                // Pricing Type Info Banner
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isPerHour ? Colors.orange.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isPerHour
                              ? Colors.orange.shade200
                              : Colors.blue.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPerHour ? Icons.access_time : Icons.directions_car,
                        color: isPerHour ? Colors.orange : Colors.blue,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPerHour ? "PER HOUR VEHICLE" : "PER KM VEHICLE",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color:
                                    isPerHour
                                        ? Colors.orange.shade800
                                        : Colors.blue.shade800,
                              ),
                            ),
                            Text(
                              isPerHour
                                  ? "Charges based on time usage"
                                  : "Charges based on distance and weight",
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        isPerHour ? "₹$vehicleRate/hour" : "₹$vehicleRate/km",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              isPerHour
                                  ? Colors.orange.shade800
                                  : Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Goods Name (Common for both)
                Text(
                  "Goods Name *",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                TextFormField(
                  decoration: InputDecoration(
                    hintText: "e.g., Electronics, Furniture, Boxes",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => goodsName = value),
                  validator:
                      (value) => value?.isEmpty == true ? "Required" : null,
                ),
                SizedBox(height: 16),

                // Conditional Input Fields
                if (isPerHour)
                  _buildHoursInput()
                else
                  _buildWeightAndDistanceInput(),

                SizedBox(height: 16),

                // Payer Selection (Common for both)
                Text(
                  "Who pays? *",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile(
                        title: Text("Recipient"),
                        value: "recipient",
                        groupValue: payer,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => payer = value);
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        title: Text("Sender (Me)"),
                        value: "sender",
                        groupValue: payer,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => payer = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Payment Type (Common for both)
                Text(
                  "Payment Type *",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: paymentType,
                  items: [
                    DropdownMenuItem(value: "cash", child: Text("Cash")),
                    DropdownMenuItem(value: "online", child: Text("Online")),
                    DropdownMenuItem(value: "card", child: Text("Card")),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => paymentType = value);
                    }
                  },
                  decoration: InputDecoration(border: OutlineInputBorder()),
                ),
                SizedBox(height: 16),

                // Receiver Details (Common for both)
                Text(
                  "Receiver Details *",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                TextFormField(
                  decoration: InputDecoration(
                    hintText: "Receiver Name",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => receiverName = value),
                  validator:
                      (value) => value?.isEmpty == true ? "Required" : null,
                ),
                SizedBox(height: 8),
                TextFormField(
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: "Receiver Phone",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => receiverPhone = value),
                  validator:
                      (value) => value?.isEmpty == true ? "Required" : null,
                ),
                SizedBox(height: 16),

                // Package Images (Common for both)
                Text(
                  "Package Photos * (${pickedImages.length}/3)",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                if (pickedImages.isEmpty)
                  GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 50,
                            color: Colors.blue,
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Add Photos",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            "Tap to add from Camera or Gallery",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount:
                            pickedImages.length +
                            (pickedImages.length < 3 ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < pickedImages.length) {
                            return Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      pickedImages[index],
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return GestureDetector(
                              onTap: _showImageSourceDialog,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.blue,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add,
                                        color: Colors.blue,
                                        size: 30,
                                      ),
                                      SizedBox(height: 5),
                                      Text(
                                        "Add More",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: _showImageSourceDialog,
                            icon: Icon(
                              Icons.add_photo_alternate,
                              color: Colors.blue,
                            ),
                            label: Text(
                              "Add More Photos",
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "Minimum 1, Maximum 3 photos",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                SizedBox(height: 20),

                // Booking Summary
                _buildBookingSummary(),
                SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : _submitBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child:
                        isSubmitting
                            ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(
                              "Confirm Booking - ₹${_estimatedFare.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
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
    );
  }

  Widget _buildLocationSummary() {
    final selectedDate = widget.selectedDate ?? DateTime.now();
    final selectedTime = widget.selectedTime;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Delivery Schedule",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      "${DateFormat('dd MMM yyyy').format(selectedDate)} • "
                      "${selectedTime?.format(context) ?? 'Now'}",
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(Icons.circle, color: Colors.red, size: 16),
                  Container(width: 2, height: 40, color: Colors.grey),
                  Icon(Icons.flag, color: Colors.green, size: 16),
                ],
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pickup",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      widget.pickupLocation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Delivery",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      widget.deliveryLocation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingSummary() {
    final pricingType = widget.selectedVehicle.pricingType ?? 'PER_KM';
    final isPerHour = pricingType == 'PER_HOUR';
    final vehicleRate = (widget.selectedVehicle.rate ?? 0.0).toDouble();
    final vehicleName = widget.selectedVehicle.name ?? 'Vehicle';

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                "Booking Summary",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Vehicle Information
          _buildSummaryRow(
            "Vehicle",
            "$vehicleName (${isPerHour ? 'PER HOUR' : 'PER KM'})",
          ),
          _buildSummaryRow(
            "Rate",
            isPerHour ? '₹$vehicleRate/hour' : '₹$vehicleRate/km',
          ),

          // Conditional Fields
          if (isPerHour && _hours != null)
            _buildSummaryRow(
              "Estimated Hours",
              "${_hours!.toStringAsFixed(1)} hours",
            ),

          if (!isPerHour && goodsWeight.isNotEmpty)
            _buildSummaryRow("Weight", "$goodsWeight $weightUnit"),

          if (!isPerHour && _distanceKm != null)
            _buildSummaryRow(
              "Distance",
              "${_distanceKm!.toStringAsFixed(2)} km",
            ),

          _buildSummaryRow("Goods", goodsName.isNotEmpty ? goodsName : "-"),
          _buildSummaryRow("Pickup", widget.pickupLocation),
          _buildSummaryRow("Delivery", widget.deliveryLocation),
          _buildSummaryRow(
            "Receiver",
            receiverName.isNotEmpty ? receiverName : "-",
          ),
          _buildSummaryRow(
            "Payment by",
            payer == "recipient" ? "Recipient" : "Sender",
          ),
          _buildSummaryRow("Payment type", paymentType.toUpperCase()),

          Divider(color: Colors.grey.shade300),

          // Fare Breakdown
          Text(
            "Fare Breakdown",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 10),

          _buildSummaryRow("Base Fare", "₹100"),

          if (isPerHour && _hours != null)
            _buildSummaryRow(
              "Time Charges",
              "₹${(vehicleRate * _hours!).toStringAsFixed(0)}",
              subText: "($vehicleRate/hr × ${_hours!.toStringAsFixed(1)}hrs)",
            ),

          if (!isPerHour && _distanceKm != null)
            _buildSummaryRow(
              "Distance Charges",
              "₹${(vehicleRate * _distanceKm!).toStringAsFixed(0)}",
              subText:
                  "($vehicleRate/km × ${_distanceKm!.toStringAsFixed(2)}km)",
            ),

          if (!isPerHour && goodsWeight.isNotEmpty)
            _buildSummaryRow(
              "Weight Charges",
              "₹${((double.tryParse(goodsWeight) ?? 0) * 5).toStringAsFixed(0)}",
              subText: "($goodsWeight $weightUnit × ₹5)",
            ),

          Divider(color: Colors.grey.shade300),

          _buildSummaryRow(
            "Total Estimated Fare",
            "₹${_estimatedFare.toStringAsFixed(0)}",
            isBold: true,
            color: Colors.green.shade700,
          ),

          SizedBox(height: 8),
          Text(
            "*Final fare may vary based on actual distance and time",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    String? subText,
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Label
              Expanded(
                flex: 5,
                child: Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                ),
              ),

              // Right Value
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight:
                            isBold ? FontWeight.bold : FontWeight.normal,
                        color: color ?? Colors.black,
                        fontSize: isBold ? 15 : 14,
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subText != null)
                      Text(
                        subText,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                        textAlign: TextAlign.right,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
