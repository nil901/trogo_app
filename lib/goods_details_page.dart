// goods_details_page.dart
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
import 'package:trogo_app/prefs/app_preference.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/transportergoods/tracking_screen.dart';

class GoodsDetailsPage extends StatefulWidget {
  final String pickupLocation;
  final String deliveryLocation;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final int selectedVehicle;
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
  String goodsWeight = "";
  String weightUnit = "KG";
  List<String> weightUnits = ["KG", "TON", "QUINTLE", "NOS"];
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
    _calculateFare();
    _fareTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _calculateFare();
    });
  }

  @override
  void dispose() {
    _fareTimer?.cancel();
    super.dispose();
  }

  void _calculateFare() {
    double baseFare = 100.0;
    double weightValue = double.tryParse(goodsWeight) ?? 0;
    double weightMultiplier = weightValue * 5;
    double vehicleMultiplier = (widget.selectedVehicle + 1) * 50.0;

    setState(() {
      _estimatedFare = baseFare + weightMultiplier + vehicleMultiplier;
    });
  }

  Future<void> pickImagesFromCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Please allow camera permission")));
      return;
    }

    final List<XFile>? images = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1080,
    );

    if (images != null && images.isNotEmpty) {
      setState(() {
        pickedImages.addAll(images.map((xfile) => File(xfile.path)).toList());
        if (pickedImages.length > 3) {
          pickedImages = pickedImages.sublist(0, 3);
        }
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

      final vehicleTypeId = await _getVehicleTypeId(widget.selectedVehicle);
      final authToken = AppPreference().getString(PreferencesKey.authToken);

      if (authToken == null || authToken.isEmpty) {
        throw Exception("Authentication failed");
      }

      // Multipart request
      final request = http.MultipartRequest('POST', apiUrl);
      request.headers['Authorization'] = 'Bearer $authToken';

      // Required fields
      request.fields.addAll({
        'bookingType': 'goods',
        'vehicleTypeId': vehicleTypeId,
        'scheduleDate': formattedDate,
        'scheduleTime': formattedTime,
        'paymentBy': payer,
        'paymentType': paymentType,
        'drop[address]': widget.deliveryLocation,
        'goods[name]': goodsName,
        'goods[weightKg]': _convertToKg(goodsWeight, weightUnit).toString(),
        'receiver[name]': receiverName,
        'receiver[phone]': receiverPhone,
        'estimatedFare': _estimatedFare.toStringAsFixed(2),
      });

      // Drop coordinates
      final dropLng = widget.deliveryPosition?.longitude ?? 0.0;
      final dropLat = widget.deliveryPosition?.latitude ?? 0.0;
      request.fields['drop[coordinates][0]'] = dropLng.toString();
      request.fields['drop[coordinates][1]'] = dropLat.toString();

      // Pickup coordinates
      if (widget.pickupPosition != null) {
        request.fields['pickup[address]'] = widget.pickupLocation;
        request.fields['pickup[coordinates][0]'] =
            widget.pickupPosition!.longitude.toString();
        request.fields['pickup[coordinates][1]'] =
            widget.pickupPosition!.latitude.toString();
      }

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
          Future.delayed(Duration(seconds: 1), () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder:
                    (_) => GoodsTrackingPage(
                      bookingId: bookingId,
                      bookingData: bookingData,
                    ),
              ),
              (route) => false,
            );
          });
        } else {
          throw Exception("Booking failed - no booking data received");
        }
      } else {
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

  String _getVehicleName(int index) {
    final vehicles = ["Mini Truck", "Truck", "Large Truck"];
    if (index >= 0 && index < vehicles.length) {
      return vehicles[index];
    }
    return "Vehicle ${index + 1}";
  }

  @override
  Widget build(BuildContext context) {
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

                // Goods Name
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

                // Weight
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Weight *",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 8),
                          TextFormField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: "Enter weight",
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              setState(() => goodsWeight = value);
                              _calculateFare();
                            },
                            validator:
                                (value) =>
                                    value?.isEmpty == true ? "Required" : null,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Unit",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: weightUnit,
                            items:
                                weightUnits.map((unit) {
                                  return DropdownMenuItem(
                                    value: unit,
                                    child: Text(unit),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setState(() => weightUnit = value!);
                              _calculateFare();
                            },
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Payer Selection
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
                        onChanged: (value) => setState(() => payer = value!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        title: Text("Sender (Me)"),
                        value: "sender",
                        groupValue: payer,
                        onChanged: (value) => setState(() => payer = value!),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Payment Type
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
                  onChanged: (value) => setState(() => paymentType = value!),
                  decoration: InputDecoration(border: OutlineInputBorder()),
                ),
                SizedBox(height: 16),

                // Receiver Details
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

                // Package Images
                Text(
                  "Package Photos * (${pickedImages.length}/3)",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                if (pickedImages.isEmpty)
                  GestureDetector(
                    onTap: pickImagesFromCamera,
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 40, color: Colors.blue),
                          Text(
                            "Take Photos",
                            style: TextStyle(color: Colors.blue),
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
                                Image.file(
                                  pickedImages[index],
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: IconButton(
                                    icon: Icon(Icons.close, size: 20),
                                    onPressed: () => _removeImage(index),
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return GestureDetector(
                              onTap: pickImagesFromCamera,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.blue),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.add, color: Colors.blue),
                              ),
                            );
                          }
                        },
                      ),
                      SizedBox(height: 8),
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
                    ),
                    child:
                        isSubmitting
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                              "Confirm Booking - ₹${_estimatedFare.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
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
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
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
                      "${DateFormat('dd MMM yyyy').format(widget.selectedDate ?? DateTime.now())} • "
                      "${widget.selectedTime?.format(context) ?? 'Now'}",
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
                    Text(widget.pickupLocation, maxLines: 2),
                    SizedBox(height: 16),
                    Text(
                      "Delivery",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(widget.deliveryLocation, maxLines: 2),
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
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Booking Summary",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          _buildSummaryRow("Service", "Goods Delivery"),
          _buildSummaryRow("Vehicle", _getVehicleName(widget.selectedVehicle)),
          _buildSummaryRow("Pickup", widget.pickupLocation),
          _buildSummaryRow("Delivery", widget.deliveryLocation),
          _buildSummaryRow("Goods", goodsName.isNotEmpty ? goodsName : "-"),
          _buildSummaryRow(
            "Weight",
            goodsWeight.isNotEmpty ? "$goodsWeight $weightUnit" : "-",
          ),
          _buildSummaryRow(
            "Receiver",
            receiverName.isNotEmpty ? receiverName : "-",
          ),
          _buildSummaryRow(
            "Payment by",
            payer == "recipient" ? "Recipient" : "Sender",
          ),
          _buildSummaryRow("Payment type", paymentType.toUpperCase()),
          Divider(),
          _buildSummaryRow(
            "Estimated Fare",
            "₹${_estimatedFare.toStringAsFixed(0)}",
            isBold: true,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
