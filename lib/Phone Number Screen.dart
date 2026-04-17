import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:trogo_app/auth/forgot_screen.dart';
import 'package:trogo_app/auth/login_notifier.dart';
import 'package:trogo_app/auth/ragister_screen.dart';
import 'package:trogo_app/global/utils.dart';
import 'package:trogo_app/localization/app_strings.dart';
import 'package:trogo_app/otp_screen.dart';

class PhoneNumberScreen extends ConsumerStatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  ConsumerState<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends ConsumerState<PhoneNumberScreen> {
  static const Color _inputBorderColor = Color(0xFFD8D8D8);
  static const Color _inputIconColor = Color(0xFF8A8A8A);
  final FocusNode emailFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();
  final FocusNode mobileFocus = FocusNode();
  bool _showPassword = false;
  bool _useOtpLogin = false;
  
  TextEditingController usernameController = TextEditingController(
    //text: "passengerdigi@gmail.com",
  );
  TextEditingController passwordController = TextEditingController(
    // text: "123",
  );
  TextEditingController mobileController = TextEditingController();

  @override
  void initState() {
    super.initState();
    emailFocus.addListener(_refreshFocusState);
    passwordFocus.addListener(_refreshFocusState);
    mobileFocus.addListener(_refreshFocusState);
  }

  void _refreshFocusState() {
    if (mounted) {
      setState(() {});
    }
  }

  InputDecoration _plainFieldDecoration({
    required String hintText,
    String? counterText,
  }) {
    return const InputDecoration().copyWith(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.grey),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      filled: false,
      fillColor: Colors.transparent,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      counterText: counterText,
    );
  }

  @override
  void dispose() {
    emailFocus.removeListener(_refreshFocusState);
    passwordFocus.removeListener(_refreshFocusState);
    mobileFocus.removeListener(_refreshFocusState);
    emailFocus.dispose();
    passwordFocus.dispose();
    mobileFocus.dispose();
    usernameController.dispose();
    passwordController.dispose();
    mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.08,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= Back Button =================
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: Colors.black,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ================= Welcome Section =================
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome Back 👋",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppStrings.t('signInToContinue'),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 50),

              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _useOtpLogin = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_useOtpLogin ? Colors.black : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            AppStrings.t('emailLogin'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: !_useOtpLogin ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _useOtpLogin = true;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _useOtpLogin ? Colors.black : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            AppStrings.t('mobileOtp'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _useOtpLogin ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              if (!_useOtpLogin) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.t('emailAddress'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _inputBorderColor,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(
                            Icons.email_outlined,
                            color: _inputIconColor,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: usernameController,
                              focusNode: emailFocus,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                              ),
                              decoration: _plainFieldDecoration(
                                hintText: AppStrings.t('enterYourEmail'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.t('password'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _inputBorderColor,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(
                            Icons.lock_outline,
                            color: _inputIconColor,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: passwordController,
                              focusNode: passwordFocus,
                              obscureText: !_showPassword,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                              ),
                              decoration: _plainFieldDecoration(
                                hintText: AppStrings.t('enterYourPassword'),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey.shade500,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.t('mobileNumber'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _inputBorderColor,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(
                            Icons.phone_android_outlined,
                            color: _inputIconColor,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: mobileController,
                              focusNode: mobileFocus,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                              ),
                              decoration: _plainFieldDecoration(
                                hintText: AppStrings.t('enterMobileNumber'),
                                counterText: "",
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppStrings.t('otpWillBeSent'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // ================= Forgot Password =================
    //           Align(
    //             alignment: Alignment.centerRight,
    //             child: GestureDetector(
    //               onTap: () {
    //                  Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => const ForgotPasswordScreen(),
    //   ),
    // );
    //               },
    //               child: Text(
    //                 "Forgot Password?",
    //                 style: TextStyle(
    //                   color: Colors.black,
    //                   fontWeight: FontWeight.w600,
    //                   fontSize: 14,
    //                   decoration: TextDecoration.underline,
    //                 ),
    //               ),
    //             ),
    //           ),

              const SizedBox(height: 40),

              // ================= Login Button =================
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_useOtpLogin) {
                      final mobile = mobileController.text.trim();

                      if (mobile.isEmpty) {
                        Utils().showTopSnackBar(
                          context,
                          "Please Enter Mobile Number",
                          Colors.red,
                        );
                        return;
                      }
                      if (!RegExp(r'^\d{10}$').hasMatch(mobile)) {
                        Utils().showTopSnackBar(
                          context,
                          "Please Enter Valid Mobile Number",
                          Colors.red,
                        );
                        return;
                      }

                      final sent = await ref
                          .read(loginProvider.notifier)
                          .requestOtp(mobile);

                      if (!mounted) return;
                      if (sent) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OtpScreen(mobile: mobile),
                          ),
                        );
                      }
                      return;
                    }

                    final stId = usernameController.text;
                    final password = passwordController.text;

                    if (stId.isEmpty) {
                      Utils().showTopSnackBar(
                        context,
                        "Please Enter Email",
                        Colors.red,
                      );
                      return;
                    }
                    if (password.isEmpty) {
                      Utils().showTopSnackBar(
                        context,
                        "Please Enter Password",
                        Colors.red,
                      );
                      return;
                    }

                    await ref
                        .read(loginProvider.notifier)
                        .login(stId, password, context);

                    final loginResult = ref.read(loginProvider);

                    loginResult.when(
                      data: (_) {
                        usernameController.clear();
                        passwordController.clear();
                      },
                      loading: () {},
                      error: (error, stackTrace) {
                        Utils().showToastMessage(error.toString());
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: loginState.maybeWhen(
                    loading: () => SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    orElse: () => Text(
                      _useOtpLogin
                          ? AppStrings.t('sendOtp')
                          : AppStrings.t('login'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ================= Divider =================
              Row(
                children: [
                  Expanded(
                    child: Divider(color: Colors.grey.shade300),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "or continue with",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: Colors.grey.shade300),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // ================= Social Login =================
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.center,
              //   children: [
              //     _buildSocialButton(
              //       icon: Icons.g_mobiledata,
              //       color: Colors.red.shade500,
              //       onTap: () {},
              //     ),
              //     const SizedBox(width: 20),
              //     _buildSocialButton(
              //       icon: Icons.facebook,
              //       color: Colors.blue.shade800,
              //       onTap: () {},
              //     ),
              //     const SizedBox(width: 20),
              //     _buildSocialButton(
              //       icon: Icons.apple,
              //       color: Colors.black,
              //       onTap: () {},
              //     ),
              //   ],
              // ),

              // const SizedBox(height: 50),

              // ================= Register Link =================
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "Don't have an account? ",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        TextSpan(
                          text: "Sign Up",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ================= Social Button Widget =================
  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Icon(
            icon,
            color: color,
            size: 28,
          ),
        ),
      ),
    );
  }
}
