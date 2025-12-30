import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:trogo_app/courier_tracking_page.dart';


class GoodsDetailsPage extends StatefulWidget {
  const GoodsDetailsPage({super.key});

  @override
  State<GoodsDetailsPage> createState() => _GoodsDetailsPageState();
}

class _GoodsDetailsPageState extends State<GoodsDetailsPage> {
  String payer = "Me";
  String? paymentType;

  File? pickedImage;
  final ImagePicker _picker = ImagePicker();

  /// 📸 CAMERA + PERMISSION
  Future<void> pickImageFromCamera() async {
    final status = await Permission.camera.request();

    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please allow camera permission")),
      );
      return;
    }

    final XFile? image = await _picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() {
        pickedImage = File(image.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 🔙 BACK
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back, size: 28),
              ),

              const SizedBox(height: 20),

              const Text(
                "Details",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 20),

              const Text("Select Goods"),
              const SizedBox(height: 6),
              _inputBox(initialValue: "Vegetables"),

              const SizedBox(height: 14),

              const Text("Select in KG / NOS / QUINTLE / TON"),
              const SizedBox(height: 6),
              _inputBox(initialValue: "5 KG"),

              const SizedBox(height: 20),

              const Text("Select who pays"),
              const SizedBox(height: 8),

              Row(
                children: [
                  Radio(
                    value: "Me",
                    groupValue: payer,
                    onChanged: (value) => setState(() => payer = value!),
                  ),
                  const Text("Me"),
                  const SizedBox(width: 30),
                  Radio(
                    value: "Recipient",
                    groupValue: payer,
                    onChanged: (value) => setState(() => payer = value!),
                  ),
                  const Text("Recipient"),
                ],
              ),

              const SizedBox(height: 14),

              /// 💳 PAYMENT TYPE
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xffF1F5F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: paymentType,
                    hint: const Text("Payment type"),
                    isExpanded: true,
                    items: const ["Cash", "Online", "Card"]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) {
                      setState(() => paymentType = value);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text("Recipient Name"),
              const SizedBox(height: 6),
              _inputBox(initialValue: "Donald Duck"),

              const SizedBox(height: 14),

              const Text("Recipient contact number"),
              const SizedBox(height: 6),
              _inputBox(initialValue: "08123456789"),

              const SizedBox(height: 20),

              /// 📸 CAMERA BOX
              GestureDetector(
                onTap: pickImageFromCamera,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal, width: 1.3),
                  ),
                  child: Center(
                    child: pickedImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt,
                                size: 34,
                                color: Colors.teal.shade700,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Take a picture of the package",
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              pickedImage!,
                              width: double.infinity,
                              height: 150,
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              /// ✅ CONTINUE BUTTON (ROOT NAVIGATOR FIX)
              GestureDetector(
                onTap: () {
                  if (pickedImage == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please upload package image"),
                      ),
                    );
                    return;
                  }

                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => const CourierTrackingPage(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 55,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Continue",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  /// INPUT BOX UI
  Widget _inputBox({String? initialValue}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xffF1F5F7),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        initialValue ?? "",
        style: const TextStyle(color: Colors.black87, fontSize: 14),
      ),
    );
  }
}
