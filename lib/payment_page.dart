import 'package:flutter/material.dart';

class PaymentPage extends StatelessWidget {
  const PaymentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ---------------- APP BAR ----------------
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: Text(
          "Select payment method",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        actions: [
          Icon(Icons.edit_outlined, color: Colors.black, size: 22),
          SizedBox(width: 16),
        ],
      ),

      // ---------------- BODY ----------------
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          // ---------------- CARDS ----------------
          Text(
            "Cards",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          SizedBox(height: 14),

          _menuTile(
            icon: Icons.credit_card,
            title: "Add new card",
            onTap: () {},
          ),

          SizedBox(height: 25),

          // ---------------- UPI ----------------
          Text(
            "UPI",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          SizedBox(height: 14),

          _menuTile(
            icon: Icons.qr_code_rounded,
            title: "QR code Scanner",
            onTap: () {},
          ),

          SizedBox(height: 12),

          _menuTileWithImage(
            imagePath: "assets/images/phonepe.png",
            title: "PhonePe",
            onTap: () {},
          ),

          SizedBox(height: 12),

          _menuTileWithImage(
            imagePath: "assets/images/gpay.png",
            title: "GPay",
            onTap: () {},
          ),

          SizedBox(height: 25),

          // ---------------- NETBANKING ----------------
          Text(
            "Netbanking",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          SizedBox(height: 14),

          _menuTile(
            icon: Icons.account_balance_outlined,
            title: "Netbanking",
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // ---------- GENERIC MENU TILE (ICON + TEXT + ARROW) ----------
  Widget _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: Colors.black87, size: 26),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  // ---------- MENU TILE WITH IMAGE (PHONEPE + GPAY) ----------
  Widget _menuTileWithImage({
    required String imagePath,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Image.asset(imagePath, height: 30, width: 30),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}
