// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:peace_india_test_series_app/colors.dart';
// import 'package:peace_india_test_series_app/global/utils.dart';
// import 'package:peace_india_test_series_app/screen/auth/login_notifier.dart';
// import 'package:peace_india_test_series_app/screen/dashboard/dashbard_screen.dart';

// import '../../prefs/PreferencesKey.dart';
// import '../../prefs/app_preference.dart';

// class LoginScreen extends ConsumerStatefulWidget {
//   LoginScreen({super.key});

//   @override
//   ConsumerState<LoginScreen> createState() => _LoginScreenState();
// }

// class _LoginScreenState extends ConsumerState<LoginScreen> {
//   final TextEditingController usernameController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();

//   bool _isPasswordHidden = true;

//   @override
//   Widget build(BuildContext context) {
//     final loginState = ref.watch(loginProvider);
// // usernameController.text = "250774919";
// // passwordController.text = "Q&MBPGJYF";
//     return Scaffold(
//       backgroundColor: kprimaryColor,
//       body: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(height: 40),

//           /// HEADER
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 30),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Image.asset("assets/images/logo.jpg", height: 50),
//                   SizedBox(height: 10),
//                   Text(
//                     "Login In",
//                     style: TextStyle(
//                       fontSize: 28,
//                       fontWeight: FontWeight.bold,
//                       color: kWhite,
//                     ),
//                   ),
//                   SizedBox(height: 5),
//                   Text(
//                     "Sign in to access MCQs, study notes, and all your learning information in one place",
//                     style: TextStyle(color: kWhite),
//                   ),
//                 ],
//               ),
//             ),
//           ),

//           SizedBox(height: 70),

//           /// MAIN WHITE CONTAINER
//           Expanded(
//             child: Container(
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.only(
//                   topLeft: Radius.circular(40),
//                   topRight: Radius.circular(40),
//                 ),
//               ),

//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   /// USERNAME
//                   TextField(
//                     controller: usernameController,
//                     decoration: InputDecoration(
//                       hintText: "Username",
//                       filled: true,
//                       fillColor: Color(0xFFF6F6F6),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15),
//                         borderSide: BorderSide.none,
//                       ),
//                     ),
//                   ),

//                   SizedBox(height: 15),

//                   /// PASSWORD WITH EYE ICON
//                   TextField(
//                     controller: passwordController,
//                     obscureText: _isPasswordHidden,
//                     decoration: InputDecoration(
//                       hintText: "Password",
//                       filled: true,
//                       fillColor: Color(0xFFF6F6F6),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(15),
//                         borderSide: BorderSide.none,
//                       ),

//                       /// 👁‍🗨 EYE ICON FOR SHOW/HIDE
//                       suffixIcon: IconButton(
//                         icon: Icon(
//                           _isPasswordHidden
//                               ? Icons.visibility_off
//                               : Icons.visibility,
//                           color: Colors.grey,
//                         ),
//                         onPressed: () {
//                           setState(() {
//                             _isPasswordHidden = !_isPasswordHidden;
//                           });
//                         },
//                       ),
//                     ),
//                   ),

//                   SizedBox(height: 10),

//                   // Align(
//                   //   alignment: Alignment.centerRight,
//                   //   child: Text(
//                   //     "Forgot Password?",
//                   //     style: TextStyle(color: Colors.black54),
//                   //   ),
//                   // ),

//                   SizedBox(height: 20),

//                   /// LOGIN BUTTON
//                   Material(
//                     borderRadius: BorderRadius.circular(15),
//                     elevation: 5,
//                     child: InkWell(
//                       onTap: () async {
//                         final stId = usernameController.text;
//                         final password = passwordController.text;

//                         if (stId.isEmpty) {
//                           Utils().showTopSnackBar(
//                               context, "Please Enter Student Id", Colors.red);
//                           return;
//                         }
//                         if (password.isEmpty) {
//                           Utils().showTopSnackBar(
//                               context, "Please Enter Password", Colors.red);
//                           return;
//                         }

//                         await ref
//                             .read(loginProvider.notifier)
//                             .login(stId, password, context);

//                         final loginResult = ref.read(loginProvider);

//                         loginResult.when(
//                           data: (_) {
//                             usernameController.clear();
//                             passwordController.clear();
//                           },
//                           loading: () {},
//                           error: (error, stackTrace) {
//                             Utils().showToastMessage(error.toString());
//                           },
//                         );
//                       },

//                       child: Container(
//                         alignment: Alignment.center,
//                         height: 55,
//                         decoration: BoxDecoration(
//                           color: kprimaryColor,
//                           borderRadius: BorderRadius.circular(15),
//                         ),

//                         child: loginState.maybeWhen(
//                           loading: () => CircularProgressIndicator(
//                             color: Colors.white,
//                           ),
//                           orElse: () => Text(
//                             "Login",
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.w700,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),

//                   SizedBox(height: 20),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }


//   Widget loginOptionButton(String text, IconData icon) {
//     return OutlinedButton(
//       style: OutlinedButton.styleFrom(
//         padding: const EdgeInsets.symmetric(vertical: 12),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
//         side: const BorderSide(color: Colors.white),
//       ),
//       onPressed: () {},
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Icon(icon, color: kprimaryColor),
//           Text(text, style: TextStyle(color: kWhite, fontSize: 18)),
//           const Icon(Icons.arrow_forward, color: Colors.black),
//         ],
//       ),
//     );
//   }
// }

// class TopHeaderSection extends StatelessWidget {
//   const TopHeaderSection({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
//       decoration: BoxDecoration(
//         color: kprimaryColor, // Light green color
//         borderRadius: BorderRadius.circular(30),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Row with Menu icon and profile image
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Icon(Icons.menu, color: Colors.white),
//               const CircleAvatar(
//                 radius: 18,
//                 backgroundImage: AssetImage(
//                   'assets/profile.jpg',
//                 ), // Replace with your image
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),

//           // Greeting Text
//           const Text(
//             "Hello,",
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const Text(
//             "good Morning",
//             style: TextStyle(color: Colors.white70, fontSize: 14),
//           ),
//           const SizedBox(height: 20),

//           // Search bar with dropdown
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Row(
//               children: [
//                 const Icon(Icons.search, color: Colors.grey),
//                 const SizedBox(width: 10),
//                 const Expanded(
//                   child: TextField(
//                     decoration: InputDecoration(
//                       hintText: "Search",
//                       border: InputBorder.none,
//                     ),
//                   ),
//                 ),
//                 DropdownButton<String>(
//                   value: "All",
//                   items: const [
//                     DropdownMenuItem(value: "All", child: Text("All")),
//                   ],
//                   onChanged: (value) {},
//                   underline: const SizedBox(),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
