import 'package:flutter/material.dart';
import 'package:trogo_app/api_service/splash_service.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool startSlide = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => startSlide = true);
      });

      Future.delayed(const Duration(seconds: 2), () {
        // if (mounted) {
        //   Navigator.pushReplacement(
        //     context,
        //     MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        //   );
        // }
        SplashServices().checkAuthentication(context);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
          transform: Matrix4.translationValues(startSlide ? width : 0, 0, 0),
          child: Image.asset("assets/images/trogo.png", width: 200),
        ),
      ),
    );
  }
}
