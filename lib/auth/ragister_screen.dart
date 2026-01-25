import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:trogo_app/Phone%20Number%20Screen.dart';
import 'package:trogo_app/api_service/urls.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ================= Controllers =================
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final mobileCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();

  // ================= Variables =================
  File? profileImage;
  final ImagePicker picker = ImagePicker();
  bool loading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;
  String? selectedGender;

  // ================= Image Picker =================
  Future<void> pickImage() async {
    final XFile? img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() {
        profileImage = File(img.path);
      });
    }
  }

  // ================= Register API =================
  Future<void> registerApi() async {
    if (nameCtrl.text.isEmpty ||
        emailCtrl.text.isEmpty ||
        passCtrl.text.isEmpty ||
        mobileCtrl.text.isEmpty ||
        confirmPassCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("All fields are required")));
      return;
    }

    if (passCtrl.text != confirmPassCtrl.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    if (profileImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select profile image")),
      );
      return;
    }

    if (selectedGender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select gender")));
      return;
    }

    setState(() => loading = true);

    try {
      FormData data = FormData.fromMap({
        "name": nameCtrl.text.trim(),
        "email": emailCtrl.text.trim(),
        "password": passCtrl.text.trim(),
        "confirmPassword": passCtrl.text.trim(),
        "mobile": mobileCtrl.text.trim(),
        "type": "user",
        "gender": selectedGender,
        "profileImage": await MultipartFile.fromFile(
          profileImage!.path,
          filename: profileImage!.path.split('/').last,
        ),
      });

      final response = await Dio().post(
        "${signup}",
        data: data,
        options: Options(headers: {"Content-Type": "multipart/form-data"}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registration Successful!"),
            backgroundColor: Colors.green,
          ),
        );
         Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const PhoneNumberScreen()),
                  );
        // Clear form
        nameCtrl.clear();
        emailCtrl.clear();
        passCtrl.clear();
        mobileCtrl.clear();
        confirmPassCtrl.clear();
        setState(() {
          profileImage = null;
          selectedGender = null;
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Registration failed")));
      }
    } catch (e) {
      debugPrint("Register Error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Create Account",
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= Welcome Text =================
            const Text(
              "Let's get started!",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              "Create an account to continue",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // ================= Profile Image =================
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 3),
                      color: Colors.grey.shade100,
                    ),
                    child:
                        profileImage != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(60),
                              child: Image.file(
                                profileImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                            : const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey,
                            ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                "Add Profile Photo",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 30),

            // ================= Form Fields =================
            buildTextField("Full Name", Icons.person_outline, nameCtrl),
            const SizedBox(height: 16),
            buildTextField(
              "Email Address",
              Icons.email_outlined,
              emailCtrl,
              keyboard: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            buildTextField(
              "Phone Number",
              Icons.phone_outlined,
              mobileCtrl,
              keyboard: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            // ================= Gender Selection =================
            const Text(
              "Gender",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: buildGenderOption("male", "Male")),
                const SizedBox(width: 12),
                Expanded(child: buildGenderOption("female", "Female")),
                const SizedBox(width: 12),
                Expanded(child: buildGenderOption("other", "Other")),
              ],
            ),
            const SizedBox(height: 16),

            // ================= Password Fields =================
            buildPasswordField("Password", passCtrl, showPassword, () {
              setState(() => showPassword = !showPassword);
            }),
            const SizedBox(height: 16),
            buildPasswordField(
              "Confirm Password",
              confirmPassCtrl,
              showConfirmPassword,
              () {
                setState(() => showConfirmPassword = !showConfirmPassword);
              },
            ),
            const SizedBox(height: 30),

            // ================= Terms and Conditions =================
            Row(
              children: [
                Checkbox(
                  value: true,
                  onChanged: (val) {},
                  activeColor: Colors.black,
                ),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                      children: [
                        TextSpan(text: "I agree to the "),
                        TextSpan(
                          text: "Terms & Conditions",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(text: " and "),
                        TextSpan(
                          text: "Privacy Policy",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: loading ? null : registerApi,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child:
                    loading
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text(
                          "CREATE ACCOUNT",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
              ),
            ),
            const SizedBox(height: 20),

            // ================= Login Link =================
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PhoneNumberScreen()),
                  );
                },
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(color: Colors.grey),
                    children: [
                      TextSpan(text: "Already have an account? "),
                      TextSpan(
                        text: "Sign In",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ================= Reusable TextField =================
  Widget buildTextField(
    String hint,
    IconData prefixIcon,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          border: InputBorder.none,
          prefixIcon: Icon(prefixIcon, color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  // ================= Password Field =================
  Widget buildPasswordField(
    String hint,
    TextEditingController controller,
    bool isVisible,
    VoidCallback onToggle,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        obscureText: !isVisible,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
          suffixIcon: IconButton(
            icon: Icon(
              isVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey,
            ),
            onPressed: onToggle,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  // ================= Gender Option =================
  Widget buildGenderOption(String value, String label) {
    bool isSelected = selectedGender == value;
    return GestureDetector(
      onTap: () => setState(() => selectedGender = value),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
