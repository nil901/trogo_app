// import 'package:flutter/material.dart';
// import 'package:peace_india_test_series_app/colors.dart';
// import 'package:peace_india_test_series_app/screen/auth/splash_service.dart';

// import '../../api_service/splash_service.dart';

// class SplashScreen extends StatefulWidget {
//   const SplashScreen({Key? key}) : super(key: key);

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _scaleAnimation;
//   late Animation<double> _fadeAnimation;

//   @override
//   void initState() {
//     super.initState();

//     _controller = AnimationController(
//       duration: const Duration(seconds: 2),
//       vsync: this,
//     );

//     _scaleAnimation = Tween<double>(
//       begin: 0.8,
//       end: 1.0,
//     ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

//     _fadeAnimation = Tween<double>(
//       begin: 0.0,
//       end: 1.0,
//     ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

//     _controller.forward();

//     _controller.addStatusListener((status) {
//       if (status == AnimationStatus.completed) {
//         SplashServices().checkAuthentication(context);
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: kprimaryColor,
//       body: Stack(
//         children: [
//           Center(
//             child: FadeTransition(
//               opacity: _fadeAnimation,
//               child: ScaleTransition(
//                 scale: _scaleAnimation,
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     // Glowing circular logo
//                     Image.asset(
//                       'assets/images/logo.jpg',
//                       width: 100,
//                       height: 100,
//                     ),

//                     const SizedBox(height: 20),
//                     FittedBox(
//                       fit: BoxFit.scaleDown,
//                       child: Text(
//                         'Peace India\'s Digital study Platform',
//                         style: TextStyle(
//                           fontSize: 20,
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold,
//                           letterSpacing: 1.2,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),

//           // Bottom tagline
//           Positioned(
//             bottom: 30,
//             left: 0,
//             right: 0,
//             child: Center(
//               child: Text(
//                 '"Change Your Life With Moxe..."',
//                 style: TextStyle(
//                   fontSize: 14,
//                   color: Colors.white.withOpacity(0.9),
//                   fontStyle: FontStyle.italic,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
