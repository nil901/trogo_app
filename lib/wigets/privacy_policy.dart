import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  bool accepted = false;
  bool isLoading = false;

  Future<void> saveAccept() async {
    setState(() {
      isLoading = true;
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("privacyAccepted", true);
    
    setState(() {
      isLoading = false;
    });
  }

  void onAccept() async {
    await saveAccept();

    if (mounted) {
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(
      //     builder: (context) => const BookingScreen(),
      //   ),
      // );
    }
  }

  @override
  Widget build(BuildContext context) {
  
    return Scaffold(
      backgroundColor: Colors.white,
    appBar: AppBar(
  title: const Text(
    "Privacy Policy",
    style: TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.black,
    ),
  ),
  backgroundColor: Colors.white,
  elevation: 0,

  iconTheme: const IconThemeData(
    color: Colors.black, // ← arrow black
  ),
),

      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Image/Icon
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.privacy_tip_outlined,
                        size: 40,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Last Updated
                  // Center(
                  //   child: Container(
                  //     padding: const EdgeInsets.symmetric(
                  //       horizontal: 12,
                  //       vertical: 6,
                  //     ),
                  //     decoration: BoxDecoration(
                  //       color: Colors.grey.shade100,
                  //       borderRadius: BorderRadius.circular(20),
                  //     ),
                  //     child: const Text(
                  //       "Last Updated: March 15, 2024",
                  //       style: TextStyle(
                  //         color: Colors.grey,
                  //         fontSize: 12,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  const SizedBox(height: 30),

                  // Introduction
                  _buildSection(
                    title: "Introduction",
                    icon: Icons.info_outline,
                    content:
                        "This Transport App (\"we,\" \"our,\" or \"us\") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.",
                  ),

                  // Information Collection
                  _buildSection(
                    title: "Information We Collect",
                    icon: Icons.data_usage,
                    content: "",
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBulletPoint(
                          icon: Icons.location_on,
                          text:
                              "Location Data: We collect real-time location information to connect you with nearby drivers and enable ride booking.",
                        ),
                        _buildBulletPoint(
                          icon: Icons.person,
                          text:
                              "Personal Information: Name, phone number, email address, and profile photo for account creation and verification.",
                        ),
                        _buildBulletPoint(
                          icon: Icons.payment,
                          text:
                              "Payment Information: Payment method details (processed securely through third-party payment processors).",
                        ),
                        _buildBulletPoint(
                          icon: Icons.history,
                          text:
                              "Trip History: Records of your rides, including pickup and drop locations, routes, and timestamps.",
                        ),
                        _buildBulletPoint(
                          icon: Icons.phone_android,
                          text:
                              "Device Information: Device model, operating system, and app version for technical support and improvements.",
                        ),
                      ],
                    ),
                  ),

                  // How We Use Information
                  _buildSection(
                    title: "How We Use Your Information",
                    icon: Icons.analytics,
                    content: "",
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNumberedPoint(
                          number: "1",
                          title: "To Provide Services",
                          description:
                              "Connect you with drivers, process payments, and enable ride booking functionality.",
                        ),
                        _buildNumberedPoint(
                          number: "2",
                          title: "To Improve Our Services",
                          description:
                              "Analyze usage patterns, optimize routes, and enhance user experience.",
                        ),
                        _buildNumberedPoint(
                          number: "3",
                          title: "For Safety and Security",
                          description:
                              "Monitor rides for safety, verify user identities, and prevent fraud.",
                        ),
                        _buildNumberedPoint(
                          number: "4",
                          title: "To Communicate",
                          description:
                              "Send important updates, ride confirmations, and customer support messages.",
                        ),
                      ],
                    ),
                  ),

                  // Location Data Specific
                  _buildSection(
                    title: "Location Data Usage",
                    icon: Icons.gps_fixed,
                    content:
                        "We collect location data to enable ride booking even when the app is closed or not in use. This allows us to:",
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBulletPoint(
                          text: "Find nearby available drivers",
                        ),
                        _buildBulletPoint(
                          text: "Calculate accurate fare estimates",
                        ),
                        _buildBulletPoint(
                          text: "Show real-time driver location",
                        ),
                        _buildBulletPoint(
                          text: "Optimize pickup and drop-off",
                        ),
                      ],
                    ),
                  ),

                  // Data Sharing
                  _buildSection(
                    title: "Data Sharing and Disclosure",
                    icon: Icons.share,
                    content: "We may share your information with:",
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBulletPoint(
                          icon: Icons.drive_eta,
                          text:
                              "Drivers: To facilitate rides (name, location, pickup point)",
                        ),
                        _buildBulletPoint(
                          icon: Icons.payment,
                          text: "Payment Processors: To process transactions",
                        ),
                        _buildBulletPoint(
                          icon: Icons.support_agent,
                          text:
                              "Service Providers: For customer support and app maintenance",
                        ),
                        _buildBulletPoint(
                          icon: Icons.gavel,
                          text:
                              "Legal Authorities: When required by law or to protect rights",
                        ),
                      ],
                    ),
                  ),

                  // Data Security
                  _buildSection(
                    title: "Data Security",
                    icon: Icons.security,
                    content:
                        "We implement industry-standard security measures to protect your personal information, including encryption, secure servers, and access controls. However, no method of transmission over the Internet is 100% secure.",
                  ),

                  // Your Rights
                  _buildSection(
                    title: "Your Rights",
                    icon: Icons.verified_user,
                    content: "You have the right to:",
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBulletPoint(
                          text: "Access your personal information",
                        ),
                        _buildBulletPoint(
                          text: "Correct inaccurate data",
                        ),
                        _buildBulletPoint(
                          text: "Request deletion of your data",
                        ),
                        _buildBulletPoint(
                          text: "Opt-out of location tracking (app features may be limited)",
                        ),
                      ],
                    ),
                  ),

                  // Changes to Policy
                  _buildSection(
                    title: "Changes to This Policy",
                    icon: Icons.update,
                    content:
                        "We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the 'Last Updated' date.",
                  ),

                  // Contact Information
                  _buildSection(
                    title: "Contact Us",
                    icon: Icons.contact_mail,
                    content: "If you have questions about this Privacy Policy:",
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () async {
                            final Uri emailUri = Uri(
                              scheme: 'mailto',
                              path: 'privacy@transportapp.com',
                              query: 'subject=Privacy Policy Inquiry',
                            );
                            if (await canLaunchUrl(emailUri)) {
                              await launchUrl(emailUri);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.email,
                                    color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'privacy@transportapp.com',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final Uri telUri = Uri(
                              scheme: 'tel',
                              path: '+1234567890',
                            );
                            if (await canLaunchUrl(telUri)) {
                              await launchUrl(telUri);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.phone,
                                    color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '+1 (234) 567-890',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Agreement Statement
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "By clicking 'ACCEPT & CONTINUE', you acknowledge that you have read and agree to our Privacy Policy.",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // // Bottom Button
          // Container(
          //   padding: const EdgeInsets.all(20),
          //   decoration: BoxDecoration(
          //     color: Colors.white,
          //     boxShadow: [
          //       BoxShadow(
          //         color: Colors.grey.withOpacity(0.3),
          //         spreadRadius: 1,
          //         blurRadius: 5,
          //         offset: const Offset(0, -3),
          //       ),
          //     ],
          //   ),
          //   child: SafeArea(
          //     child: SizedBox(
          //       width: double.infinity,
          //       height: 50,
          //       child: ElevatedButton(
          //         onPressed: isLoading ? null : onAccept,
          //         style: ElevatedButton.styleFrom(
          //           backgroundColor: Colors.black,
          //           foregroundColor: Colors.white,
          //           shape: RoundedRectangleBorder(
          //             borderRadius: BorderRadius.circular(10),
          //           ),
          //           elevation: 2,
          //         ),
          //         child: isLoading
          //             ? const SizedBox(
          //                 height: 20,
          //                 width: 20,
          //                 child: CircularProgressIndicator(
          //                   strokeWidth: 2,
          //                   valueColor:
          //                       AlwaysStoppedAnimation<Color>(Colors.white),
          //                 ),
          //               )
          //             : const Text(
          //                 "ACCEPT & CONTINUE",
          //                 style: TextStyle(
          //                   fontSize: 16,
          //                   fontWeight: FontWeight.bold,
          //                   letterSpacing: 1,
          //                 ),
          //               ),
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required String content,
    Widget? child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.blue.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Text(
                content,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            ),
          if (child != null)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 8),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint({IconData? icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: Icon(icon, size: 16, color: Colors.blue.shade700),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: Icon(Icons.circle, size: 6, color: Colors.blue.shade700),
            ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberedPoint({
    required String number,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}