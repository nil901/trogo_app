import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:trogo_app/location_permission_screen.dart';
import 'package:path/path.dart' as path;
import 'package:trogo_app/api_service/urls.dart';
import 'package:trogo_app/main_bottom_nav.dart';
import 'package:trogo_app/models/estimateurl_model.dart';
import 'package:trogo_app/models/vehicle_type_model.dart';
import 'package:trogo_app/prefs/app_preference.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/transportergoods/tracking_screen.dart';
import 'package:image/image.dart' as img;

class GoodsDetailsPage extends StatefulWidget {
  final String pickupLocation;
  final String deliveryLocation;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final VehicleType selectedVehicle;
  final Position? pickupPosition;
  final Position? deliveryPosition;
  final FareEstimate? fareEstimate;
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
    this.fareEstimate,
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
  static const int _maxImageCount = 3;
  static const int _compressedImageWidth = 1280;
  static const int _compressedImageHeight = 1280;
  static const int _compressedImageQuality = 70;

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

    if (widget.fareEstimate != null) {
      _distanceKm = widget.fareEstimate!.distanceKm;
      _estimatedFare = widget.fareEstimate!.estimatedFare.toDouble();
    }

    if (pricingType == 'PER_HOUR') {
      _hours = 1.0;
    } else {
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
        final distanceKm = distanceInMeters / 1000;

        setState(() {
          _distanceKm = distanceKm > 0 ? distanceKm : 10.0;
          _isCalculatingDistance = false;
        });
        _calculateFare();
      } catch (e) {
        print('Error calculating distance: $e');
        setState(() {
          _distanceKm = 10.0;
          _isCalculatingDistance = false;
        });
        _calculateFare();
      }
    } else {
      print('Pickup or delivery position is null');
      setState(() {
        _distanceKm = 10.0;
      });
      _calculateFare();
    }
  }

  @override
  void dispose() {
    _fareTimer?.cancel();
    super.dispose();
  }

  void _calculateFare() {
    try {
      if (widget.fareEstimate != null) {
        setState(() {
          _estimatedFare = widget.fareEstimate!.estimatedFare.toDouble();
          _distanceKm ??= widget.fareEstimate!.distanceKm;
        });
        return;
      }

      double baseFare = 100.0;
      double vehicleRate = (widget.selectedVehicle.rate ?? 0.0).toDouble();
      final pricingType = widget.selectedVehicle.pricingType ?? 'PER_KM';

      double estimatedFare = baseFare;

      if (pricingType == 'PER_HOUR') {
        if (_hours != null && _hours! > 0) {
          estimatedFare += vehicleRate * _hours!;
        } else {
          estimatedFare += vehicleRate * 1;
        }
      } else {
        double weightValue = double.tryParse(goodsWeight) ?? 0.0;
        double weightMultiplier = weightValue * 5.0;

        if (_distanceKm != null && _distanceKm! > 0) {
          estimatedFare += (vehicleRate * _distanceKm!) + weightMultiplier;
        } else {
          estimatedFare += (vehicleRate * 10.0) + weightMultiplier;
        }
      }

      setState(() {
        _estimatedFare = estimatedFare;
      });
    } catch (e) {
      print('Error calculating fare: $e');
      setState(() {
        _estimatedFare = 100.0;
      });
    }
  }

  Future<void> _showImageSourceDialog() async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              "Select Image Source",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.camera_alt, color: Colors.black),
                  title: Text("Camera", style: TextStyle(color: Colors.grey[800])),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library, color: Colors.black),
                  title: Text("Gallery", style: TextStyle(color: Colors.grey[800])),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please allow camera permission"),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: _compressedImageQuality,
      maxWidth: 1920,
      maxHeight: 1080,
    );

    if (image != null) {
      if (pickedImages.length < _maxImageCount) {
        final compressedImage = await _compressImageFile(File(image.path));
        setState(() {
          pickedImages.add(compressedImage);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Maximum $_maxImageCount photos allowed"),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    PermissionStatus status;

    if (Platform.isAndroid) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        status = await Permission.photos.request();
      }
    } else {
      status = await Permission.photos.request();
    }

    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Gallery permission denied"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final List<XFile>? images = await _picker.pickMultiImage(
      imageQuality: _compressedImageQuality,
    );

    if (images != null && images.isNotEmpty) {
      final remainingSlots = _maxImageCount - pickedImages.length;
      final selectedImages = images.take(remainingSlots).toList();
      final compressedImages = <File>[];

      for (final image in selectedImages) {
        compressedImages.add(await _compressImageFile(File(image.path)));
      }

      setState(() {
        pickedImages.addAll(compressedImages);
      });

      if (images.length > remainingSlots) {
        _showError("Maximum $_maxImageCount photos allowed");
      }
    }
  }

  Future<File> _compressImageFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        final fallbackPath = path.join(
          Directory.systemTemp.path,
          'trogo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        return File(
          fallbackPath,
        ).writeAsBytes(await file.readAsBytes(), flush: true);
      }

      final resizedImage = img.copyResize(
        decodedImage,
        width: decodedImage.width > _compressedImageWidth
            ? _compressedImageWidth
            : decodedImage.width,
        height: decodedImage.height > _compressedImageHeight
            ? _compressedImageHeight
            : decodedImage.height,
      );

      final compressedBytes = img.encodeJpg(
        resizedImage,
        quality: _compressedImageQuality,
      );

      final compressedPath = path.join(
        Directory.systemTemp.path,
        'trogo_${DateTime.now().millisecondsSinceEpoch}_${path.basenameWithoutExtension(file.path)}.jpg',
      );

      return File(compressedPath).writeAsBytes(compressedBytes, flush: true);
    } catch (_) {
      return file;
    }
  }

  bool _validateBookingData() {
    if (!_formKey.currentState!.validate()) {
      _showError("Please fill all required fields");
      return false;
    }

    goodsName = goodsName.trim();
    receiverName = receiverName.trim();
    receiverPhone = receiverPhone.trim();

    if (goodsName.isEmpty) {
      _showError("Please enter goods name");
      return false;
    }

    if (receiverName.isEmpty) {
      _showError("Please enter receiver name");
      return false;
    }

    if (receiverPhone.isEmpty || receiverPhone.length < 8) {
      _showError("Please enter valid receiver phone");
      return false;
    }

    if (widget.pickupLocation.trim().isEmpty ||
        widget.deliveryLocation.trim().isEmpty) {
      _showError("Pickup and delivery locations are required");
      return false;
    }

    final pricingType = widget.selectedVehicle.pricingType ?? 'PER_KM';
    if (pricingType == 'PER_HOUR') {
      if (_hours == null || _hours! <= 0) {
        _showError("Please enter valid hours");
        return false;
      }
    } else {
      if (goodsWeight.trim().isEmpty || double.tryParse(goodsWeight) == null) {
        _showError("Please enter valid weight");
        return false;
      }
    }

    if (pickedImages.isEmpty) {
      _showError("Please take at least one picture of the package");
      return false;
    }

    return true;
  }

  Future<void> _submitBooking() async {
    if (!_validateBookingData()) {
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final apiUrl = Uri.parse(bookingCreateUrl);

      final formattedDate = DateFormat(
        'yyyy-MM-dd',
      ).format(widget.selectedDate ?? DateTime.now());
      final formattedTime =
          widget.selectedTime != null
              ? '${widget.selectedTime!.hour.toString().padLeft(2, '0')}:${widget.selectedTime!.minute.toString().padLeft(2, '0')}'
              : DateFormat('HH:mm').format(DateTime.now());

      final vehicleTypeId = widget.selectedVehicle.id.toString();
      final authToken = AppPreference().getString(PreferencesKey.authToken);

      if (authToken == null || authToken.isEmpty) {
        throw Exception("Authentication failed");
      }

      final request = http.MultipartRequest('POST', apiUrl);
      request.headers['Authorization'] = 'Bearer $authToken';

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

      if (pricingType == 'PER_HOUR') {
        request.fields['hours'] = (_hours ?? 1).toString();
      } else {
        request.fields['goods[weightKg]'] =
            _convertToKg(goodsWeight, weightUnit).toString();
        if (_distanceKm != null) {
          request.fields['distanceKm'] = _distanceKm!.toStringAsFixed(2);
        }
      }

      final dropLng = widget.deliveryPosition?.longitude ?? 0.0;
      final dropLat = widget.deliveryPosition?.latitude ?? 0.0;
      request.fields['drop[coordinates][0]'] = dropLng.toString();
      request.fields['drop[coordinates][1]'] = dropLat.toString();

      if (widget.pickupPosition != null) {
        request.fields['pickup[address]'] = widget.pickupLocation;
        request.fields['pickup[coordinates][0]'] =
            widget.pickupPosition!.longitude.toString();
        request.fields['pickup[coordinates][1]'] =
            widget.pickupPosition!.latitude.toString();
      }

      for (int i = 0; i < pickedImages.length; i++) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'packageImage',
            pickedImages[i].path,
            filename:
                'package_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
            contentType: MediaType('image', 'jpeg'),
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

          if (widget.onBookingCreated != null) {
            widget.onBookingCreated!(bookingId, bookingData);
          }

          final selectedLocation = SelectedLocation(
            latitude:
                widget.pickupPosition?.latitude ??
                widget.deliveryPosition?.latitude ??
                0.0,
            longitude:
                widget.pickupPosition?.longitude ??
                widget.deliveryPosition?.longitude ??
                0.0,
            address: widget.pickupLocation,
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder:
                  (_) => MainBottomNav(
                    selectedLocation: selectedLocation,
                    initialIndex: 1,
                  ),
            ),
            (route) => false,
          );
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
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildHoursInput() {
    final vehicleRate = (widget.selectedVehicle.rate ?? 0.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Text(
          "Estimated Hours Required *",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 15,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          initialValue: _hours?.toStringAsFixed(1),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: "e.g., 2.5 hours",
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.black, width: 2),
            ),
            suffixText: "hours",
            suffixStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
            filled: true,
            fillColor: Colors.grey[50],
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
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              SizedBox(width: 8),
              Text(
                "Rate: ₹$vehicleRate/hour",
                style: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeightAndDistanceInput() {
    final vehicleRate = (widget.selectedVehicle.rate ?? 0.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        // Weight Section
        Text(
          "Weight *",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 15,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: "Enter weight",
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
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
            SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: weightUnit,
                style: TextStyle(color: Colors.black),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(14),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.black87,
                ),
                items:
                    weightUnits.map((unit) {
                      return DropdownMenuItem(
                        value: unit,
                        child: Text(unit, style: TextStyle(color: Colors.black)),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => weightUnit = value);
                    _calculateFare();
                  }
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),

        // Distance Section
        Text(
          "Distance",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 15,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.directions_car, color: Colors.white, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child:
                    _isCalculatingDistance
                        ? Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Calculating distance...",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _distanceKm != null
                                  ? "${_distanceKm!.toStringAsFixed(2)} km"
                                  : "Distance not available",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Rate: ₹$vehicleRate/km",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Fare includes ₹100 base + (₹$vehicleRate × distance) + (weight × ₹5)",
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
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
                // Location Summary - Updated
                _buildLocationSummary(),
                SizedBox(height: 20),

                // Pricing Type Info Banner - Updated
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey[50]!, Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isPerHour ? Icons.access_time : Icons.directions_car,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicleName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              isPerHour
                                  ? "Hourly based pricing"
                                  : "Distance based pricing",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isPerHour ? "₹$vehicleRate/hr" : "₹$vehicleRate/km",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Goods Name
                Text(
                  "Goods Name *",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 8),
                TextFormField(
                  style: TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: "e.g., Electronics, Furniture, Boxes",
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: (value) => setState(() => goodsName = value),
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.isEmpty) return "Required";
                    if (name.length < 2) return "Enter valid goods name";
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // Conditional Input Fields
                if (isPerHour) _buildHoursInput() else _buildWeightAndDistanceInput(),

                SizedBox(height: 16),

                // Payer Selection
                Text(
                  "Who pays? *",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: RadioListTile(
                          title: Text(
                            "Recipient",
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                          value: "recipient",
                          groupValue: payer,
                          activeColor: Colors.black,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => payer = value);
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile(
                          title: Text(
                            "Sender (Me)",
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                          value: "sender",
                          groupValue: payer,
                          activeColor: Colors.black,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => payer = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Payment Type
                Text(
                  "Payment Type *",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: paymentType,
                  style: TextStyle(color: Colors.black),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.black87,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: "cash",
                      child: Text("Cash", style: TextStyle(color: Colors.black)),
                    ),
                    DropdownMenuItem(
                      value: "online",
                      child: Text("Online", style: TextStyle(color: Colors.black)),
                    ),
                    DropdownMenuItem(
                      value: "card",
                      child: Text("Card", style: TextStyle(color: Colors.black)),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => paymentType = value);
                    }
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                SizedBox(height: 16),

                // Receiver Details
                Text(
                  "Receiver Details *",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 8),
                TextFormField(
                  style: TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: "Receiver Name",
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: (value) => setState(() => receiverName = value),
                  validator: (value) => value?.isEmpty == true ? "Required" : null,
                ),
                SizedBox(height: 8),
                TextFormField(
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: "Receiver Phone",
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: (value) => setState(() => receiverPhone = value),
                  validator: (value) {
                    final phone = value?.trim() ?? '';
                    if (phone.isEmpty) return "Required";
                    if (phone.length < 8) return "Enter valid phone";
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // Package Images
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Package Photos",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        fontSize: 15,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${pickedImages.length}/$_maxImageCount",
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                if (pickedImages.isEmpty)
                  GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!, width: 2),
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey[50],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 50,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Add Photos",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            "Tap to add from Camera or Gallery",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
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
                            (pickedImages.length < _maxImageCount ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < pickedImages.length) {
                            return Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
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
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
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
                              onTap: _showImageSourceDialog,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey[50],
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add,
                                        color: Colors.grey[400],
                                        size: 30,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        "Add",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
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
                              color: Colors.grey[600],
                              size: 18,
                            ),
                            label: Text(
                              "Add More Photos",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "Minimum 1, Maximum $_maxImageCount photos",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
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
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child:
                        isSubmitting
                            ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(
                              "Confirm Booking - ₹${_estimatedFare.toStringAsFixed(0)}",
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
    );
  }

  Widget _buildLocationSummary() {
    final selectedDate = widget.selectedDate ?? DateTime.now();
    final selectedTime = widget.selectedTime;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[50]!, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.schedule, color: Colors.white, size: 18),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Delivery Schedule",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "${DateFormat('dd MMM yyyy').format(selectedDate)} • "
                      "${selectedTime?.format(context) ?? 'Now'}",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.circle, color: Colors.white, size: 8),
                  ),
                  Container(
                    width: 2,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.flag, color: Colors.white, size: 8),
                  ),
                ],
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Pickup",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.pickupLocation,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Delivery",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.deliveryLocation,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
    final hasApiFare = widget.fareEstimate != null;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_long, color: Colors.white, size: 18),
              ),
              SizedBox(width: 12),
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
          SizedBox(height: 16),

          // Vehicle Information
          _buildSummaryRow(
            "Vehicle",
            "$vehicleName (${isPerHour ? 'Hourly' : 'Distance'})",
          ),
          _buildSummaryRow(
            "Rate",
            isPerHour ? '₹$vehicleRate/hour' : '₹$vehicleRate/km',
          ),

          if (hasApiFare)
            _buildSummaryRow(
              "API Estimate",
              '₹${widget.fareEstimate!.estimatedFare}',
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

          Divider(color: Colors.grey[300], height: 24),

          // Fare Breakdown
          Text(
            "Fare Breakdown",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 12),

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

          Divider(color: Colors.grey[300], height: 24),

          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Estimated Fare",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  "₹${_estimatedFare.toStringAsFixed(0)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 8),
          Text(
            "*Final fare may vary based on actual distance and time",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    color: color ?? Colors.grey[800],
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subText != null)
                  Text(
                    subText,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.right,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
