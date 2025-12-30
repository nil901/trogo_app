
// import 'package:flutter/material.dart';
// // import 'package:myyvo_delivery_boy_app/color/color.dart';


// class LeaderboardScreen extends StatefulWidget {
//   @override
//   _LeaderboardScreenState createState() => _LeaderboardScreenState();
// }

// class _LeaderboardScreenState extends State<LeaderboardScreen> {
//   ScrollController _scrollController = ScrollController();
//   bool _showTopUsers = true;
//   bool _isLoading = true; // Track loading state

//   @override
//   void initState() {
//     super.initState();

//     // Simulate loading for 2 seconds
//     Future.delayed(Duration(seconds: 2), () {
//       setState(() {
//         _isLoading = false;
//       });
//     });

//     _scrollController.addListener(() {
//       if (_scrollController.offset > 50 && _showTopUsers) {
//         setState(() {
//           _showTopUsers = false;
//         });
//       } else if (_scrollController.offset <= 50 && !_showTopUsers) {
//         setState(() {
//           _showTopUsers = true;
//         });
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.purple.shade800,
//       appBar: AppBar(
//         title: Text("Leaderboard"),
//         backgroundColor: Colors.purple.shade900,
//         leading: Icon(Icons.arrow_back),
//         actions: [Icon(Icons.more_vert)],
//       ),
//       body: Column(
//         children: [
//           // AnimatedContainer(
//           //   duration: Duration(milliseconds: 300),
//           //   height: _showTopUsers ? 180 : 0,
//           //   child: _showTopUsers
//           //       ? (_isLoading ? _buildShimmerTopUsers() : _buildTopUsers())
//           //       : SizedBox.shrink(),
//           // ),
//           Expanded(
//             child: Container(
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.only(
//                   topLeft: Radius.circular(20),
//                   topRight: Radius.circular(20),
//                 ),
//               ),
//               child: Column(
//                 children: [
//                   SizedBox(height: 10),
//                   _buildTabBar(),
//                   // Expanded(
//                   //   child: _isLoading
//                   //       ? _buildShimmerLeaderboardList()
//                   //       : _buildLeaderboardList(),
//                   // ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   /// **Shimmer Effect for Top Users**
//   // Widget _buildShimmerTopUsers() {
//   //   return Shimmer.fromColors(
//   //     baseColor: Colors.grey.shade300,
//   //     highlightColor: Colors.white,
//   //     child: Row(
//   //       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//   //       children: List.generate(
//   //           3,
//   //           (index) => CircleAvatar(
//   //               radius: 35, backgroundColor: Colors.grey.shade300)),
//   //     ),
//   //   );
//   // }

//   /// **Shimmer Effect for Leaderboard List**
//   // Widget _buildShimmerLeaderboardList() {
//   //   return ListView.builder(
//   //     itemCount: 6,
//   //     itemBuilder: (context, index) {
//   //       return Shimmer.fromColors(
//   //         baseColor: Colors.grey.shade300,
//   //         highlightColor: Colors.white,
//   //         child: Card(
//   //           child: ListTile(
//   //             leading: CircleAvatar(backgroundColor: Colors.grey.shade300),
//   //             title: Container(
//   //                 height: 10, width: 100, color: Colors.grey.shade300),
//   //             subtitle:
//   //                 Container(height: 10, width: 60, color: Colors.grey.shade300),
//   //             trailing:
//   //                 Container(height: 10, width: 50, color: Colors.grey.shade300),
//   //           ),
//   //         ),
//   //       );
//   //     },
//   //   );
//   // }

//   /// **Existing Leaderboard List**
//   Widget _buildLeaderboardList() {
//     final List<Map<String, String>> users = [
//       {
//         "rank": "4",
//         "user": "User02",
//         "cricks": "4",
//         "winnings": "\u20B9 10,000"
//       },
//       {
//         "rank": "5",
//         "user": "User03",
//         "cricks": "4",
//         "winnings": "\u20B9 10,000"
//       },
//       {
//         "rank": "6",
//         "user": "User04",
//         "cricks": "4",
//         "winnings": "\u20B9 5,000"
//       },
//       {
//         "rank": "7",
//         "user": "User05",
//         "cricks": "3",
//         "winnings": "\u20B9 2,000"
//       },
//       {
//         "rank": "8",
//         "user": "User06",
//         "cricks": "2",
//         "winnings": "\u20B9 1,000"
//       },
//       {"rank": "9", "user": "User07", "cricks": "2", "winnings": "\u20B9 500"},
//       {"rank": "9", "user": "User07", "cricks": "2", "winnings": "\u20B9 500"},
//       {"rank": "9", "user": "User07", "cricks": "2", "winnings": "\u20B9 500"},
//       {"rank": "9", "user": "User07", "cricks": "2", "winnings": "\u20B9 500"},
//       {"rank": "9", "user": "User07", "cricks": "2", "winnings": "\u20B9 500"},
//       {"rank": "9", "user": "User07", "cricks": "2", "winnings": "\u20B9 500"},
//       {"rank": "9", "user": "User07", "cricks": "2", "winnings": "\u20B9 500"},
//       {"rank": "9", "user": "User07", "cricks": "2", "winnings": "\u20B9 500"},
//       {"rank": "9", "user": "User07", "cricks": "2", "winnings": "\u20B9 500"},
//       {"rank": "9", "user": "User07", "cricks": "2", "winnings": "\u20B9 500"},
//       {"rank": "9", "user": "User07", "cricks": "2", "winnings": "\u20B9 500"},
//       {"rank": "9", "user": "User07", "cricks": "2", "winnings": "\u20B9 500"},
//     ];

//     return ListView(
//       controller: _scrollController,
//       children: users
//           .map((user) => Card(
//                 color: Colors.white,
//                 child: ListTile(
//                   leading: CircleAvatar(
//                     backgroundColor: Colors.purple,
//                     child: Text(user['rank']!,
//                         style: TextStyle(
//                             color: Colors.white, fontWeight: FontWeight.bold)),
//                   ),
//                   title: Text(user['user']!),
//                   subtitle: Text("Cricks: ${user['cricks']}"),
//                   trailing: Text(user['winnings']!,
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                 ),
//               ))
//           .toList(),
//     );
//   }

//   /// **Existing Top Users**
//   Widget _buildTopUsers() {
//     return Stack(
//       alignment: Alignment.center,
//       children: [
//         Positioned(
//           left: 50,
//           top: 30,
//           child: _topUser(
//             "Profile1",
//             "108",
//             "\u20B9 25,000",
//             rank: 2,
//             gradient: LinearGradient(
//               colors: [
//                 Color(0xFFDCDCDA), // #DCDCDA
//                 Color(0xFF5B5B5A), // #5B5B5A
//                 Color(0xFFE8E9E5), // #E8E9E5
//                 Color(0xFF686868), // #686868
//               ],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//         Positioned(
//           top: 0,
//           child: _topUser(
//             "John Doe",
//             "120",
//             "\u20B9 1,00,000",
//             rank: 1,
//             isFirst: true,
//             gradient: LinearGradient(
//               colors: [
//                 Color(0xFFEEC745), // #EEC745
//                 Color(0xFFFFF986), // #FFF986
//                 Color(0xFFD9A535), // #D9A535
//                 Color(0xFFF2DA3D), // #F2DA3D
//               ],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//         Positioned(
//           right: 50,
//           top: 30,
//           child: _topUser(
//             "User123",
//             "80",
//             "\u20B9 50,000",
//             rank: 3,
//             gradient: LinearGradient(
//               colors: [
//                 Color(0xFFBC581C), // #BC581C
//                 Color(0xFFFCD196), // #FCD196
//                 Color(0xFFCE6B2F), // #CE6B2F
//                 Color(0xFFFCD194), // #FCD194
//               ],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   /// **Existing Tab Bar**
//   Widget _buildTabBar() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text("Men's Big Bash",
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//           Row(
//             children: [
//               _tabButton("Leaderboard", isActive: true),
//               _tabButton("Winnings"),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   /// **Single User Profile in the Top Section**
//   Widget _topUser(String name, String cricks, String winnings,
//       {int rank = 1, bool isFirst = false, required Gradient gradient}) {
//     return Column(
//       children: [
//         Stack(
//           alignment: Alignment.topRight,
//           children: [
//             Container(
//               width: isFirst ? 90 : 70,
//               height: isFirst ? 90 : 70,
//               decoration: BoxDecoration(
//                   // border: Border.all(color: Colors.black,width: 2),
//                   shape: BoxShape.circle,
//                   gradient: gradient),
//               child: Padding(
//                 padding: const EdgeInsets.all(3.0),
//                 child: Container(
//                   width: isFirst ? 85 : 65,
//                   height: isFirst ? 85 : 65,
//                   decoration: BoxDecoration(
//                     //   border: Border.all(color: Colors.white,width: 1),
//                     shape: BoxShape.circle,
//                     color: Colors.purple,
//                   ),
//                   child: Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: Container(
//                       width: isFirst ? 50 : 10,
//                       height: isFirst ? 65 : 10,
//                       decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           color: Colors.grey,
//                           border: Border.all(color: kwhite, width: 2)),
//                       child: Icon(Icons.person,
//                           size: isFirst ? 35 : 30, color: Colors.white),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//             Container(
//               width: 24,
//               height: 24,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: Colors.amber,
//               ),
//               child: Center(
//                 child: Text(
//                   "$rank",
//                   style: TextStyle(
//                       fontWeight: FontWeight.bold, color: Colors.black),
//                 ),
//               ),
//             ),
//           ],
//         ),
//         SizedBox(height: 5),
//         Text(name,
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//         Text("Cricks: $cricks", style: TextStyle(color: Colors.white70)),
//         Container(
//           margin: EdgeInsets.only(top: 5),
//           padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [
//                 Colors.pinkAccent,
//                 Colors.blueAccent
//               ], // Multiple colors for gradient
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//           child: Text(winnings,
//               style:
//                   TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//         )
//       ],
//     );
//   }

//   /// **Existing Tab Button**
//   Widget _tabButton(String text, {bool isActive = false}) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       decoration: BoxDecoration(
//         color: isActive ? Colors.purple : Colors.grey.shade300,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Text(
//         text,
//         style: TextStyle(
//           color: isActive ? Colors.white : Colors.black,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );
//   }
// }
