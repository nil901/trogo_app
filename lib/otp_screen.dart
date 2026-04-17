import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trogo_app/auth/login_notifier.dart';
import 'package:trogo_app/localization/app_strings.dart';
import 'package:trogo_app/location_permission_screen.dart';

//import 'location_permission_screen.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String mobile;

  const OtpScreen({
    super.key,
    required this.mobile,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔙 BACK BUTTON
              IconButton(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              ),

              const SizedBox(height: 8),

              // 📝 TITLE + BLUE LINE
              Text(
                AppStrings.t('enterOtpVerification'),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
              ),

              const SizedBox(height: 4),

              Container(
                height: 3,
                width: 65,
                decoration: BoxDecoration(
                  color: Color(0xFF1C56A9),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                AppStrings.t('enterCodeSentToMobile'),
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),

              const SizedBox(height: 6),

              Text(
                widget.mobile,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 50),

              // ✅ OTP INPUT (SINGLE FIELD – iOS STYLE)
              Center(
                child: SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters:  [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      counterText: "",
                      filled: false,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFBDBDBD)),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFBDBDBD)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Color(0xFF1C56A9),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Center(
                child: Text(
                  AppStrings.t('didNotReceiveCode'),
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),

              const Spacer(),

              // ✅ VERIFY OTP BUTTON
              Padding(
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 20,
                ),
                child: SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      final otp = _otpController.text.trim();
                      if (otp.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppStrings.t('pleaseEnterOtp'))),
                        );
                        return;
                      }
                      if (otp.length != 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppStrings.t('pleaseEnterSixDigitOtp')),
                          ),
                        );
                        return;
                      }

                      ref.read(loginProvider.notifier).verifyOtp(
                            mobile: widget.mobile,
                            otp: otp,
                            context: context,
                          );
                    },
                    child: loginState.maybeWhen(
                      loading: () => const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      orElse: () => Text(
                        AppStrings.t('verifyOtp'),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
