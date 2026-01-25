import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayDemoScreen extends StatefulWidget {
  @override
  State<RazorpayDemoScreen> createState() => _RazorpayDemoScreenState();
}

class _RazorpayDemoScreenState extends State<RazorpayDemoScreen> {
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();

    _razorpay = Razorpay();

    _razorpay.on(
        Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(
        Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(
        Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void openCheckout() {
    var options = {
      'key': 'rzp_test_RvkSLd55D0e5sj', // 🔴 तुमचा TEST KEY इथे टाका
      'amount': 10000, // ₹100 = 10000 paise
      'name': 'Test App',
      'description': 'Razorpay Test Payment',
      'prefill': {
        'contact': '9876543210',
        'email': 'test@gmail.com'
      },
      'theme': {
        'color': '#3399cc'
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            "Payment Success\nPayment ID: ${response.paymentId}"),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            "Payment Failed\n${response.code} | ${response.message}"),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text("Wallet Used: ${response.walletName}"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Razorpay Sandbox Demo"),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: openCheckout,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
                horizontal: 30, vertical: 15),
          ),
          child: const Text(
            "Pay ₹100",
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
