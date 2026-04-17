import 'package:flutter/material.dart';
import 'package:trogo_app/Phone%20Number%20Screen.dart';
import 'package:trogo_app/localization/app_strings.dart';


class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),

              Text(
                AppStrings.t('welcome'),
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Text(
                AppStrings.t('loginOrSignupToContinue'),
                style: TextStyle(color: Colors.grey),
              ),

              const Spacer(),

              // ✅ Continue with Mobile Number
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PhoneNumberScreen(),
                      ),
                    );
                  },
                  child: Text(
                    AppStrings.t('continueWithMobileNumber'),
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
