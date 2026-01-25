import 'package:flutter/material.dart';
import 'package:trogo_app/location_permission_screen.dart';

//import 'location_permission_screen.dart';

class OtpScreen extends StatelessWidget {
  const OtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              const Text(
                "Enter OTP Verification",
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

              const Text(
                "Enter the code from the sms we sent to +8801774280874",
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),

              const SizedBox(height: 50),

              // ✅ OTP INPUT (SINGLE FIELD – iOS STYLE)
              Center(
                child: SizedBox(
                  width: 220,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, letterSpacing: 22),
                    decoration: const InputDecoration(
                      counterText: "",
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

              const Center(
                child: Text(
                  "Didn't receive code? Resend in 11s",
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
                      // ✅ Navigate to Location Permission Screen
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LocationPermissionScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Verify OTP",
                      style: TextStyle(color: Colors.white, fontSize: 16),
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
