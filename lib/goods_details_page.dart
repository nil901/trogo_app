import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trogo_app/api_service/urls.dart';
import 'package:trogo_app/courier_tracking_page.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';

class GoodsDetailsPage extends StatefulWidget {
  final String pickupLocation;
  final String deliveryLocation;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final int selectedVehicle;
  final Position? pickupPosition;
  final Position? deliveryPosition;

  const GoodsDetailsPage({
    Key? key,
    required this.pickupLocation,
    required this.deliveryLocation,
    this.selectedDate,
    this.selectedTime,
    required this.selectedVehicle,
    this.pickupPosition,
    this.deliveryPosition,
  }) : super(key: key);

  @override
  State<GoodsDetailsPage> createState() => _GoodsDetailsPageState();
}

class _GoodsDetailsPageState extends State<GoodsDetailsPage> {
  String payer = "recipient"; // Default to recipient
  String paymentType = "cash"; // Default to cash
  
  // Goods details
  String goodsName = "";
  String goodsWeight = "";
  String weightUnit = "KG";
  List<String> weightUnits = ["KG", "NOS", "QUINTLE", "TON"];
  
  // Receiver details
  String receiverName = "";
  String receiverPhone = "";
  
  // Image - Multiple images support
  List<File> pickedImages = [];
  final ImagePicker _picker = ImagePicker();
  
  // Form key
  final _formKey = GlobalKey<FormState>();
  
  // Loading state
  bool isSubmitting = false;

  /// 📸 CAMERA + PERMISSION - MULTIPLE IMAGES
  Future<void> pickImagesFromCamera() async {
    final status = await Permission.camera.request();

    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please allow camera permission")),
      );
      return;
    }

    // Allow multiple images
    final List<XFile>? images = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1080,
    );

    if (images != null && images.isNotEmpty) {
      setState(() {
        pickedImages.addAll(images.map((xfile) => File(xfile.path)).toList());
        // Limit to 3 images as per your curl command
        if (pickedImages.length > 3) {
          pickedImages = pickedImages.sublist(0, 3);
        }
      });
    }
  }

  /// 📤 SUBMIT BOOKING - UPDATED FOR YOUR API
  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    if (pickedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please take at least one picture of the package")),
      );
      return;
    }

    if (widget.deliveryPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Delivery location coordinates are required")),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      // Prepare API request
      final apiUrl = Uri.parse('$baseUrl/api/bookings/bookings');
      
      // Format date and time
      final formattedDate = DateFormat('yyyy-MM-dd').format(
        widget.selectedDate ?? DateTime.now()
      );
      final formattedTime = widget.selectedTime != null 
          ? widget.selectedTime!.format(context)
          : DateFormat('hh:mm a').format(DateTime.now());

      // Get vehicle type ID - आधीच्या स्क्रीन वरून येईल
      final vehicleTypeId = await _getVehicleTypeId(widget.selectedVehicle);

      // Get auth token
      final authToken = AppPreference().getString(PreferencesKey.authToken);
      if (authToken == null || authToken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication failed. Please login again")),
        );
        return;
      }

      // Create multipart request
      var request = http.MultipartRequest('POST', apiUrl);
      
      // Add headers
      request.headers['Authorization'] = 'Bearer $authToken';
      
      // Add fields - तुमच्या curl command प्रमाणे
      request.fields['bookingType'] = 'goods';
      request.fields['vehicleTypeId'] = vehicleTypeId;
      request.fields['scheduleDate'] = formattedDate;
      request.fields['scheduleTime'] = formattedTime;
      request.fields['paymentBy'] = payer;
      request.fields['paymentType'] = paymentType;
      request.fields['drop[address]'] = widget.deliveryLocation;
      
      // Add coordinates - REQUIRED by API
      if (widget.deliveryPosition != null) {
        request.fields['drop[coordinates][0]'] = widget.deliveryPosition!.longitude.toString();
        request.fields['drop[coordinates][1]'] = widget.deliveryPosition!.latitude.toString();
      } else {
        // Default coordinates if not available
        request.fields['drop[coordinates][0]'] = '73.7351';
        request.fields['drop[coordinates][1]'] = '19.9550';
      }
      
      // Add pickup information if available
      if (widget.pickupPosition != null) {
        request.fields['pickup[address]'] = widget.pickupLocation;
        request.fields['pickup[coordinates][0]'] = widget.pickupPosition!.longitude.toString();
        request.fields['pickup[coordinates][1]'] = widget.pickupPosition!.latitude.toString();
      }
      
      request.fields['goods[name]'] = goodsName;
      request.fields['goods[weightKg]'] = _convertToKg(goodsWeight, weightUnit).toString();
      request.fields['receiver[name]'] = receiverName;
      request.fields['receiver[phone]'] = receiverPhone;

      // Add multiple images - तुमच्या curl command प्रमाणे multiple images
      for (int i = 0; i < pickedImages.length; i++) {
        final image = pickedImages[i];
        request.files.add(
          await http.MultipartFile.fromPath(
            'packageImage', // तुमच्या API ला हेच field name लागेल
            image.path,
            filename: 'package_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
          ),
        );
      }

      // Debug print
      print("📤 API URL: $apiUrl");
      print("📤 Vehicle Type ID: $vehicleTypeId");
      print("📤 Images count: ${pickedImages.length}");

      // Send request with timeout
      final response = await request.send().timeout(Duration(seconds: 60));
      final responseData = await response.stream.bytesToString();
      
      print("📥 Response Status: ${response.statusCode}");
      print("📥 Response Body: $responseData");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(responseData);
        
        if (jsonResponse['success'] == true || 
            jsonResponse['status'] == 'success' ||
            jsonResponse['bookingId'] != null) {
          
          // Navigate to tracking page
          // Navigator.of(context, rootNavigator: true).pushReplacement(
          //   MaterialPageRoute(
          //     builder: (_) => CourierTrackingPage(
          //       bookingId: jsonResponse['data']?['_id'] ?? 
          //                  jsonResponse['bookingId'] ?? 
          //                  jsonResponse['id'] ?? 
          //                  'booking_${DateTime.now().millisecondsSinceEpoch}',
          //       pickupLocation: widget.pickupLocation,
          //       deliveryLocation: widget.deliveryLocation,
          //     ),
          //   ),
          // );
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Booking created successfully!"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          throw Exception(jsonResponse['message'] ?? 'Booking failed');
        }
      } else {
        final errorData = jsonDecode(responseData);
        final errorMessage = errorData['message'] ?? 
                           errorData['error'] ?? 
                           'Failed to create booking. Status: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Request timeout. Please try again."),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print("❌ Booking Error: $e");
      
      String errorMessage = "Booking failed";
      if (e.toString().contains("drop address")) {
        errorMessage = "Please select a valid delivery location";
      } else if (e.toString().contains("coordinates")) {
        errorMessage = "Location coordinates are required";
      } else if (e.toString().contains("vehicleTypeId")) {
        errorMessage = "Please select a valid vehicle type";
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  /// 🚗 GET VEHICLE TYPE ID - ACTUAL IMPLEMENTATION
  Future<String> _getVehicleTypeId(int selectedIndex) async {
    // येथे तुमच्या vehicle provider वरून actual IDs घ्या
    // Example vehicle IDs from your system:
    final vehicleIds = [
      "69492240c7935ef1fa6dadf5", // Vehicle 1
      "69492240c7935ef1fa6dadf6", // Vehicle 2  
      "69492240c7935ef1fa6dadf7", // Vehicle 3
    ];
    
    if (selectedIndex >= 0 && selectedIndex < vehicleIds.length) {
      return vehicleIds[selectedIndex];
    }
    
    return "69492240c7935ef1fa6dadf5"; // Default vehicle ID
  }

  /// ⚖️ CONVERT TO KG
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
        return weightValue * 1.0; // Adjust as per your business logic
      default:
        return weightValue;
    }
  }

  /// 🗑️ REMOVE IMAGE
  void _removeImage(int index) {
    setState(() {
      pickedImages.removeAt(index);
    });
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// LOCATION SUMMARY
                _buildLocationSummary(),

                const SizedBox(height: 20),

                /// GOODS NAME
                Text(
                  "Goods Name *",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  initialValue: goodsName,
                  decoration: InputDecoration(
                    hintText: "e.g., Boxes, Electronics, Furniture",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    suffixIcon: goodsName.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 20),
                            onPressed: () => setState(() => goodsName = ""),
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => goodsName = value),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter goods name';
                    }
                    if (value.length < 2) {
                      return 'Please enter a valid name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                /// WEIGHT INPUT
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Weight *",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            initialValue: goodsWeight,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: "e.g., 5",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              suffixText: weightUnit,
                            ),
                            onChanged: (value) => setState(() => goodsWeight = value),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter weight';
                              }
                              final weight = double.tryParse(value);
                              if (weight == null) {
                                return 'Please enter a valid number';
                              }
                              if (weight <= 0) {
                                return 'Weight must be greater than 0';
                              }
                              if (weight > 5000) { // Maximum weight limit
                                return 'Weight is too large';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Unit",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 52,
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: weightUnit,
                                isExpanded: true,
                                icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                                items: weightUnits.map((unit) {
                                  return DropdownMenuItem(
                                    value: unit,
                                    child: Text(unit),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() => weightUnit = value!);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                /// PAYER SELECTION
                Text(
                  "Select who pays *",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildPayerOption(
                        value: "recipient",
                        label: "Recipient",
                        icon: Icons.person_outline,
                        isSelected: payer == "recipient",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPayerOption(
                        value: "sender",
                        label: "Me (Sender)",
                        icon: Icons.person,
                        isSelected: payer == "sender",
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                /// PAYMENT TYPE
                Text(
                  "Payment Type *",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 52,
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: paymentType,
                      isExpanded: true,
                      icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                      items: const [
                        DropdownMenuItem(value: "cash", child: Text("Cash")),
                        DropdownMenuItem(value: "online", child: Text("Online")),
                        DropdownMenuItem(value: "card", child: Text("Card")),
                      ],
                      onChanged: (value) {
                        setState(() => paymentType = value!);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// RECEIVER DETAILS
                Text(
                  "Recipient Details *",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  initialValue: receiverName,
                  decoration: InputDecoration(
                    hintText: "Full name",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                  onChanged: (value) => setState(() => receiverName = value),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter recipient name';
                    }
                    if (value.length < 2) {
                      return 'Please enter a valid name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                TextFormField(
                  initialValue: receiverPhone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: "Phone number",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    prefixIcon: Icon(Icons.phone, size: 20),
                  ),
                  onChanged: (value) => setState(() => receiverPhone = value),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter phone number';
                    }
                    // Simple validation
                    final phoneRegex = RegExp(r'^[0-9]{10,}$');
                    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                    if (!phoneRegex.hasMatch(digitsOnly)) {
                      return 'Please enter a valid 10-digit phone number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                /// PACKAGE IMAGES (MULTIPLE)
                Row(
                  children: [
                    Text(
                      "Package Photos *",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      "(${pickedImages.length}/3)",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                
                if (pickedImages.isEmpty)
                  GestureDetector(
                    onTap: pickImagesFromCamera,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.shade400,
                          width: 1.5,
                        ),
                        color: Colors.blue.shade50,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 40,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Take package photos",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Up to 3 photos allowed",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                if (pickedImages.isNotEmpty)
                  Column(
                    children: [
                      // Image Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: pickedImages.length + (pickedImages.length < 3 ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < pickedImages.length) {
                            return Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
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
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      padding: EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return GestureDetector(
                              onTap: pickImagesFromCamera,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.shade300,
                                    width: 2,
                                  ),
                                  color: Colors.blue.shade50,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add,
                                        size: 24,
                                        color: Colors.blue.shade700,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        "Add More",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue.shade700,
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
                          Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                          SizedBox(width: 4),
                          Text(
                            "Minimum 1, Maximum 3 photos",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                const SizedBox(height: 30),

                /// BOOKING SUMMARY
                _buildBookingSummary(),

                const SizedBox(height: 20),

                /// SUBMIT BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : _submitBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      padding: EdgeInsets.zero,
                    ),
                    child: isSubmitting
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
                              SizedBox(width: 12),
                              Text(
                                "Creating Booking...",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Confirm Booking",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                  ),
                ),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.schedule, size: 18, color: Colors.blue.shade700),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Delivery Schedule",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "${DateFormat('dd MMM yyyy').format(widget.selectedDate ?? DateTime.now())} • "
                      "${widget.selectedTime?.format(context) ?? DateFormat('hh:mm a').format(DateTime.now())}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Divider(height: 1, color: Colors.blue.shade200),
          SizedBox(height: 12),
          _buildLocationRow(
            icon: Icons.location_on,
            color: Colors.red,
            text: widget.pickupLocation,
            label: "Pickup",
          ),
          SizedBox(height: 12),
          Container(
            height: 16,
            width: 1,
            color: Colors.grey.shade300,
            margin: EdgeInsets.only(left: 12),
          ),
          SizedBox(height: 12),
          _buildLocationRow(
            icon: Icons.flag,
            color: Colors.green,
            text: widget.deliveryLocation,
            label: "Delivery",
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color color,
    required String text,
    required String label,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPayerOption({
    required String value,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => setState(() => payer = value),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
              size: 28,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.blue.shade800 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingSummary() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, size: 18, color: Colors.grey.shade700),
              SizedBox(width: 8),
              Text(
                "Booking Summary",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildSummaryRow("Service", "Goods Delivery"),
          _buildSummaryRow("Vehicle", _getVehicleName(widget.selectedVehicle)),
          _buildSummaryRow("Pickup", widget.pickupLocation, maxLines: 1),
          _buildSummaryRow("Delivery", widget.deliveryLocation, maxLines: 1),
          _buildSummaryRow("Goods", goodsName.isNotEmpty ? goodsName : "-"),
          _buildSummaryRow("Weight", goodsWeight.isNotEmpty ? "$goodsWeight $weightUnit" : "-"),
          _buildSummaryRow("Payment by", payer == "recipient" ? "Recipient" : "Sender"),
          _buildSummaryRow("Payment type", paymentType.toUpperCase()),
          _buildSummaryRow("Photos", "${pickedImages.length} image(s)"),
          Divider(height: 20, color: Colors.grey.shade300),
          _buildSummaryRow(
            "Estimated Fare",
            "₹${_calculateFare()}",
            isBold: true,
            color: Colors.green.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {
    bool isBold = false,
    Color? color,
    int maxLines = 2,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
                color: color ?? Colors.black87,
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _getVehicleName(int index) {
    final vehicles = ["Mini Truck", "Truck", "Large Truck"];
    if (index >= 0 && index < vehicles.length) {
      return vehicles[index];
    }
    return "Vehicle ${index + 1}";
  }

  String _calculateFare() {
    // Implement your actual fare calculation logic
    double baseFare = 100.0;
    double weightMultiplier = double.tryParse(goodsWeight) ?? 0;
    double vehicleMultiplier = (widget.selectedVehicle + 1) * 50.0;
    
    double totalFare = baseFare + (weightMultiplier * 5) + vehicleMultiplier;
    return totalFare.toStringAsFixed(0);
  }
}