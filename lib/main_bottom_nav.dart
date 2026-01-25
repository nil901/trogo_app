import 'package:flutter/material.dart';
import 'package:trogo_app/Home_Screen.dart';
import 'package:trogo_app/MyRidesHistoryPage.dart';
import 'package:trogo_app/ProfilePage.dart';
import 'package:trogo_app/TransportPage.dart';
import 'package:trogo_app/location_permission_screen.dart';

class MainBottomNav extends StatefulWidget {
  const MainBottomNav({super.key, required this.selectedLocation});
  final SelectedLocation selectedLocation;

  @override
  State<MainBottomNav> createState() => _MainBottomNavState();
}

class _MainBottomNavState extends State<MainBottomNav> {
  int index = 0;
  late List<Widget> pages;

  @override
  void initState() {
    super.initState();

    pages = [
      HomeScreen(selectedLocation: widget.selectedLocation),
      GoodsTransportPage(selectedLocation: widget.selectedLocation),
      MyRidesHistoryPage(selectedLocation: widget.selectedLocation),
      ProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F6F6),
      body: pages[index],
      bottomNavigationBar: Container(
        height: 70,
        padding: const EdgeInsets.only(top: 6),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            navItem(Icons.home_outlined, "Home", 0),
            navItem(Icons.local_shipping_outlined, "Transport", 1),
            navItem(Icons.shopping_basket_outlined, "History", 2),
            navItem(Icons.person_outline, "Profile", 3),
          ],
        ),
      ),
    );
  }

  Widget navItem(IconData icon, String label, int i) {
    final isSelected = index == i;

    return InkWell(
      onTap: () => setState(() => index = i),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 26, color: isSelected ? Colors.black : Colors.grey),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.black : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
