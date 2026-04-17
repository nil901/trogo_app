import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:trogo_app/Phone%20Number%20Screen.dart';
import 'package:trogo_app/api_service/urls.dart';
import 'package:trogo_app/localization/app_strings.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  static const int _targetUploadBytes = 450 * 1024;

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
  bool _submitted = false;
  String? selectedGender;

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    mobileCtrl.dispose();
    confirmPassCtrl.dispose();
    super.dispose();
  }

  // ================= Image Picker =================
  Future<void> pickImage() async {
    final XFile? img = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40,
      maxWidth: 1080,
      maxHeight: 1080,
    );
    if (img != null) {
      final compressedImage = await _compressImage(File(img.path));
      setState(() {
        profileImage = compressedImage;
      });
    }
  }

  // ================= Register API =================
  Future<void> registerApi() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);

    if (!_formKey.currentState!.validate()) {
      _showSnackBar(AppStrings.t('pleaseFillAllRequiredFieldsCorrectly'));
      return;
    }

    if (profileImage == null) {
      _showSnackBar(AppStrings.t('pleaseSelectProfileImage'));
      return;
    }

    if (selectedGender == null) {
      _showSnackBar(AppStrings.t('pleaseSelectGender'));
      return;
    }

    setState(() => loading = true);

    try {
      profileImage = await _compressImage(profileImage!);

      final data = FormData.fromMap({
        "name": nameCtrl.text.trim(),
        "email": emailCtrl.text.trim(),
        "password": passCtrl.text.trim(),
        "mobile": mobileCtrl.text.trim(),
        "type": "user",
        "gender": selectedGender,
        "confirmPassword": confirmPassCtrl.text.trim(),
        "profileImage": await MultipartFile.fromFile(
          profileImage!.path,
          filename: profileImage!.uri.pathSegments.last,
        ),
      });

      final response = await Dio().post(
        signup,
        data: data,
        options: Options(headers: {"Content-Type": "multipart/form-data"}),
      );

      final successMessage =
          _extractApiMessage(response.data) ?? AppStrings.t('registrationSuccessful');
      _showSnackBar(successMessage, isError: false);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PhoneNumberScreen()),
      );

      nameCtrl.clear();
      emailCtrl.clear();
      passCtrl.clear();
      mobileCtrl.clear();
      confirmPassCtrl.clear();
      setState(() {
        profileImage = null;
        selectedGender = null;
        _submitted = false;
      });
    } on DioException catch (e) {
      debugPrint("Register Error: $e");
      if (e.response?.statusCode == 413) {
        _showSnackBar(
          _extractApiMessage(e.response?.data) ??
              "Image is still too large. Please choose a smaller image",
        );
        return;
      }
      _showSnackBar(
        _extractApiMessage(e.response?.data) ??
            _extractApiMessage(e.message) ??
            AppStrings.t('somethingWentWrong'),
      );
    } catch (e) {
      debugPrint("Register Error: $e");
      _showSnackBar(AppStrings.t('somethingWentWrong'));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
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
        title: Text(
          AppStrings.t('createAccount'),
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode:
            _submitted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.t('letsGetStarted'),
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.t('createAccountToContinue'),
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 30),
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
              Center(
                child: Text(
                  AppStrings.t('addProfilePhoto'),
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              if (_submitted && profileImage == null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    AppStrings.t('pleaseSelectProfileImage'),
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 30),
              buildTextField(
                AppStrings.t('fullName'),
                Icons.person_outline,
                nameCtrl,
                validator: _validateName,
              ),
              const SizedBox(height: 16),
              buildTextField(
                AppStrings.t('emailAddress'),
                Icons.email_outlined,
                emailCtrl,
                keyboard: TextInputType.emailAddress,
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              buildTextField(
                AppStrings.t('phoneNumber'),
                Icons.phone_outlined,
                mobileCtrl,
                keyboard: TextInputType.phone,
                validator: _validateMobile,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.t('gender'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: buildGenderOption("male", AppStrings.t('male'))),
                  const SizedBox(width: 12),
                  Expanded(child: buildGenderOption("female", AppStrings.t('female'))),
                  const SizedBox(width: 12),
                  Expanded(child: buildGenderOption("other", AppStrings.t('other'))),
                ],
              ),
              if (_submitted && selectedGender == null) ...[
                const SizedBox(height: 8),
                Text(
                  AppStrings.t('pleaseSelectGender'),
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              buildPasswordField(AppStrings.t('password'), passCtrl, showPassword, () {
                setState(() => showPassword = !showPassword);
              }),
              const SizedBox(height: 16),
              buildPasswordField(
                AppStrings.t('confirmPassword'),
                confirmPassCtrl,
                showConfirmPassword,
                () {
                  setState(() => showConfirmPassword = !showConfirmPassword);
                },
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Checkbox(
                    value: true,
                    onChanged: (val) {},
                    activeColor: Colors.black,
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                        children: [
                          TextSpan(text: AppStrings.t('iAgreeToThe')),
                          TextSpan(
                            text: AppStrings.t('termsAndConditions'),
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(text: AppStrings.t('and')),
                          TextSpan(
                            text: AppStrings.t('privacyPolicy'),
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
                          : Text(
                            AppStrings.t('createAccountUpper'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PhoneNumberScreen(),
                      ),
                    );
                  },
                  child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.grey),
                        children: [
                          TextSpan(text: AppStrings.t('alreadyHaveAccount')),
                          TextSpan(
                          text: AppStrings.t('loginIn'),
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
      ),
    );
  }

  Widget buildTextField(
    String hint,
    IconData prefixIcon,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.black),
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          border: InputBorder.none,
          prefixIcon: Icon(prefixIcon, color: Colors.grey),
          errorMaxLines: 2,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
      ),
    );
  }

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
      child: TextFormField(
        controller: controller,
        obscureText: !isVisible,
        style: const TextStyle(color: Colors.black),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) {
            return "$hint ${AppStrings.t('fieldIsRequired')}";
          }
          if (hint == AppStrings.t('password') && text.length < 6) {
            return AppStrings.t('passwordAtLeastSix');
          }
          if (hint == AppStrings.t('confirmPassword') && text != passCtrl.text.trim()) {
            return AppStrings.t('passwordsDoNotMatch');
          }
          return null;
        },
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
          errorMaxLines: 2,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
  }

  Future<File> _compressImage(File file) async {
    final originalBytes = await file.length();
    if (originalBytes <= _targetUploadBytes) {
      return file;
    }

    try {
      final originalImage = img.decodeImage(await file.readAsBytes());
      if (originalImage == null) {
        return file;
      }

      img.Image workingImage = originalImage;
      Uint8List bestBytes = Uint8List.fromList(img.encodeJpg(workingImage, quality: 85));
      int quality = 85;
      int maxSide = math.max(originalImage.width, originalImage.height);

      while (quality >= 20) {
        if (maxSide < math.max(originalImage.width, originalImage.height)) {
          workingImage = img.copyResize(
            originalImage,
            width: originalImage.width >= originalImage.height ? maxSide : null,
            height: originalImage.height > originalImage.width ? maxSide : null,
            interpolation: img.Interpolation.average,
          );
        }

        final jpgBytes = Uint8List.fromList(
          img.encodeJpg(workingImage, quality: quality),
        );
        bestBytes = jpgBytes;

        if (jpgBytes.lengthInBytes <= _targetUploadBytes) {
          break;
        }

        quality -= 15;
        maxSide = math.max(360, (maxSide * 0.8).round());
      }

      final targetPath =
          "${file.parent.path}/register_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final compressedFile = await File(targetPath).writeAsBytes(bestBytes, flush: true);
      return compressedFile;
    } catch (e) {
      debugPrint("Image compression failed: $e");
      return file;
    }
  }

  String? _extractApiMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final message = data["message"];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }

      final error = data["error"];
      if (error is String && error.trim().isNotEmpty) {
        return error.trim();
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    return null;
  }

  String? _validateName(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return AppStrings.t('fullNameRequired');
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) {
      return AppStrings.t('emailAddressRequired');
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return AppStrings.t('pleaseEnterValidEmail');
    }
    return null;
  }

  String? _validateMobile(String? value) {
    final mobile = (value ?? '').trim();
    if (mobile.isEmpty) {
      return AppStrings.t('phoneNumberRequired');
    }
    if (!RegExp(r'^\d{10}$').hasMatch(mobile)) {
      return AppStrings.t('validTenDigitPhone');
    }
    return null;
  }

  Widget buildGenderOption(String value, String label) {
    final isSelected = selectedGender == value;
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
