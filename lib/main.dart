import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:trogo_app/Phone%20Number%20Screen.dart';
import 'package:trogo_app/location_permission_screen.dart';
import 'package:trogo_app/prefs/app_preference.dart';
import 'package:trogo_app/splash_screen.dart';


void main() {
     WidgetsFlutterBinding.ensureInitialized();
   AppPreference().initialAppPreference();
  runApp(
    ProviderScope(
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
