import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:trogo_app/auth/login_notifier.dart';
import 'package:trogo_app/global/utils.dart';
import 'package:trogo_app/otp_screen.dart';


class PhoneNumberScreen extends ConsumerStatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  ConsumerState<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends ConsumerState<PhoneNumberScreen> {
  final FocusNode phoneFocus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    phoneFocus.addListener(() {
      setState(() {
        _focused = phoneFocus.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    phoneFocus.dispose();
    super.dispose();
  }
   TextEditingController usernameController = TextEditingController(text: "vikas@gmail.com");
   TextEditingController passwordController = TextEditingController(text: "vikas1234");
  @override
  Widget build(BuildContext context) {

      final loginState = ref.watch(loginProvider);
          // final usernameController.text = "";
          // final passwordController.text = "";
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              ),
      
              const SizedBox(height: 10),
      
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Enter phone number for\nverification",
                    style: TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 3,
                    width: 70,
                    color: const Color(0xFF1C56A9),
                  ),
                ],
              ),
      
              const SizedBox(height: 8),
      
              const Text(
                "This number will be used for all ride-related communication. "
                "You shall receive an sms with code for verification.",
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
      
              const SizedBox(height: 30),
      
              const Text(
                "Email no",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
      
              const SizedBox(height: 6),
      
              Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.email, color: Colors.grey),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: usernameController,
                          focusNode: phoneFocus,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: "email",
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
      
                  Container(
                    height: 1,
                    width: double.infinity,
                    color: _focused
                        ? const Color(0xFF1C56A9)
                        : const Color(0xFF424242),
                  ),
                ],
              ),
              const SizedBox(height: 20),
               const Text(
                "Password",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
      
              const SizedBox(height: 6),
               Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock, color: Colors.grey),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: passwordController,
                          focusNode: phoneFocus,
                          keyboardType: TextInputType.visiblePassword,
                          decoration: const InputDecoration(
                            hintText: "Password",
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
      
                  Container(
                    height: 1,
                    width: double.infinity,
                    color: _focused
                        ? const Color(0xFF1C56A9)
                        : const Color(0xFF424242),
                  ),
                ],
              ),
      
              const Spacer(),
       Material(
                    borderRadius: BorderRadius.circular(15),
                    elevation: 5,
                    child: InkWell(
                      onTap: () async {
                        final stId = usernameController.text;
                        final password = passwordController.text;
      
                        if (stId.isEmpty) {
                          Utils().showTopSnackBar(
                              context, "Please Enter Email ", Colors.red);
                          return;
                        }
                        if (password.isEmpty) {
                          Utils().showTopSnackBar(
                              context, "Please Enter Password", Colors.red);
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
      
                      child: Container(
                        alignment: Alignment.center,
                        height: 55,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(15),
                        ),
      
                        child: loginState.maybeWhen(
                          loading: () => CircularProgressIndicator(
                            color: Colors.white,
                          ),
                          orElse: () => Text(
                            "Login",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
           
      
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
