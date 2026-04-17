import 'package:trogo_app/localization/app_language.dart';
import 'package:trogo_app/localization/app_language_controller.dart';

class AppStrings {
  static final Map<String, Map<AppLanguage, String>> _strings = {
    'welcome': {
      AppLanguage.english: 'Welcome',
      AppLanguage.hindi: 'स्वागत है',
      AppLanguage.marathi: 'स्वागत आहे',
    },
    'loginOrSignupToContinue': {
      AppLanguage.english: 'Login or Signup to continue',
      AppLanguage.hindi: 'जारी रखने के लिए लॉगिन या साइनअप करें',
      AppLanguage.marathi: 'पुढे जाण्यासाठी लॉगिन किंवा साइनअप करा',
    },
    'continueWithMobileNumber': {
      AppLanguage.english: 'Continue with Mobile Number',
      AppLanguage.hindi: 'मोबाइल नंबर के साथ जारी रखें',
      AppLanguage.marathi: 'मोबाईल नंबरसह पुढे जा',
    },
    'forgotPassword': {
      AppLanguage.english: 'Forgot Password',
      AppLanguage.hindi: 'पासवर्ड भूल गए',
      AppLanguage.marathi: 'पासवर्ड विसरलात',
    },
    'resetPassword': {
      AppLanguage.english: 'Reset Password',
      AppLanguage.hindi: 'पासवर्ड रीसेट करें',
      AppLanguage.marathi: 'पासवर्ड रीसेट करा',
    },
    'resetPasswordDescription': {
      AppLanguage.english:
          "Enter your email address and we'll send you a link to reset your password.",
      AppLanguage.hindi:
          'अपना ईमेल पता दर्ज करें और हम आपको पासवर्ड रीसेट करने के लिए लिंक भेजेंगे।',
      AppLanguage.marathi:
          'तुमचा ईमेल पत्ता टाका आणि पासवर्ड रीसेट करण्यासाठी आम्ही लिंक पाठवू.',
    },
    'enterRegisteredEmail': {
      AppLanguage.english: 'Enter your registered email',
      AppLanguage.hindi: 'अपना पंजीकृत ईमेल दर्ज करें',
      AppLanguage.marathi: 'तुमचा नोंदणीकृत ईमेल टाका',
    },
    'sendResetLink': {
      AppLanguage.english: 'SEND RESET LINK',
      AppLanguage.hindi: 'रीसेट लिंक भेजें',
      AppLanguage.marathi: 'रीसेट लिंक पाठवा',
    },
    'checkSpamFolder': {
      AppLanguage.english:
          "Check your spam folder if you don't receive the email within a few minutes.",
      AppLanguage.hindi:
          'अगर कुछ मिनटों में ईमेल नहीं मिले तो अपना स्पैम फ़ोल्डर देखें।',
      AppLanguage.marathi:
          'काही मिनिटांत ईमेल मिळाला नाही तर स्पॅम फोल्डर तपासा.',
    },
    'needHelp': {
      AppLanguage.english: 'Need help?',
      AppLanguage.hindi: 'मदद चाहिए?',
      AppLanguage.marathi: 'मदत हवी आहे?',
    },
    'contactSupport': {
      AppLanguage.english: 'Contact Support',
      AppLanguage.hindi: 'सपोर्ट से संपर्क करें',
      AppLanguage.marathi: 'सपोर्टशी संपर्क करा',
    },
    'pleaseEnterEmailAddress': {
      AppLanguage.english: 'Please enter your email address',
      AppLanguage.hindi: 'कृपया अपना ईमेल पता दर्ज करें',
      AppLanguage.marathi: 'कृपया तुमचा ईमेल पत्ता टाका',
    },
    'pleaseEnterValidEmailAddress': {
      AppLanguage.english: 'Please enter a valid email address',
      AppLanguage.hindi: 'कृपया वैध ईमेल पता दर्ज करें',
      AppLanguage.marathi: 'कृपया वैध ईमेल पत्ता टाका',
    },
    'passwordResetLinkSent': {
      AppLanguage.english: 'Password reset link sent to',
      AppLanguage.hindi: 'पासवर्ड रीसेट लिंक भेजी गई',
      AppLanguage.marathi: 'पासवर्ड रीसेट लिंक पाठवली',
    },
    'createAccount': {
      AppLanguage.english: 'Create Account',
      AppLanguage.hindi: 'खाता बनाएं',
      AppLanguage.marathi: 'खाते तयार करा',
    },
    'letsGetStarted': {
      AppLanguage.english: "Let's get started!",
      AppLanguage.hindi: 'चलिए शुरू करें!',
      AppLanguage.marathi: 'चला सुरुवात करूया!',
    },
    'createAccountToContinue': {
      AppLanguage.english: 'Create an account to continue',
      AppLanguage.hindi: 'जारी रखने के लिए खाता बनाएं',
      AppLanguage.marathi: 'पुढे जाण्यासाठी खाते तयार करा',
    },
    'addProfilePhoto': {
      AppLanguage.english: 'Add Profile Photo',
      AppLanguage.hindi: 'प्रोफाइल फोटो जोड़ें',
      AppLanguage.marathi: 'प्रोफाइल फोटो जोडा',
    },
    'pleaseSelectProfileImage': {
      AppLanguage.english: 'Please select profile image',
      AppLanguage.hindi: 'कृपया प्रोफाइल इमेज चुनें',
      AppLanguage.marathi: 'कृपया प्रोफाइल इमेज निवडा',
    },
    'fullName': {
      AppLanguage.english: 'Full Name',
      AppLanguage.hindi: 'पूरा नाम',
      AppLanguage.marathi: 'पूर्ण नाव',
    },
    'phoneNumber': {
      AppLanguage.english: 'Phone Number',
      AppLanguage.hindi: 'फोन नंबर',
      AppLanguage.marathi: 'फोन नंबर',
    },
    'gender': {
      AppLanguage.english: 'Gender',
      AppLanguage.hindi: 'लिंग',
      AppLanguage.marathi: 'लिंग',
    },
    'male': {
      AppLanguage.english: 'Male',
      AppLanguage.hindi: 'पुरुष',
      AppLanguage.marathi: 'पुरुष',
    },
    'female': {
      AppLanguage.english: 'Female',
      AppLanguage.hindi: 'महिला',
      AppLanguage.marathi: 'महिला',
    },
    'other': {
      AppLanguage.english: 'Other',
      AppLanguage.hindi: 'अन्य',
      AppLanguage.marathi: 'इतर',
    },
    'confirmPassword': {
      AppLanguage.english: 'Confirm Password',
      AppLanguage.hindi: 'पासवर्ड की पुष्टि करें',
      AppLanguage.marathi: 'पासवर्डची पुष्टी करा',
    },
    'iAgreeToThe': {
      AppLanguage.english: 'I agree to the ',
      AppLanguage.hindi: 'मैं सहमत हूँ ',
      AppLanguage.marathi: 'मी सहमत आहे ',
    },
    'termsAndConditions': {
      AppLanguage.english: 'Terms & Conditions',
      AppLanguage.hindi: 'नियम और शर्तें',
      AppLanguage.marathi: 'अटी व शर्ती',
    },
    'and': {
      AppLanguage.english: ' and ',
      AppLanguage.hindi: ' और ',
      AppLanguage.marathi: ' आणि ',
    },
    'createAccountUpper': {
      AppLanguage.english: 'CREATE ACCOUNT',
      AppLanguage.hindi: 'खाता बनाएं',
      AppLanguage.marathi: 'खाते तयार करा',
    },
    'alreadyHaveAccount': {
      AppLanguage.english: 'Already have an account? ',
      AppLanguage.hindi: 'क्या आपका पहले से खाता है? ',
      AppLanguage.marathi: 'आधीपासून खाते आहे का? ',
    },
    'loginIn': {
      AppLanguage.english: 'Login In',
      AppLanguage.hindi: 'लॉगिन करें',
      AppLanguage.marathi: 'लॉगिन करा',
    },
    'pleaseFillAllRequiredFieldsCorrectly': {
      AppLanguage.english: 'Please fill all required fields correctly',
      AppLanguage.hindi: 'कृपया सभी आवश्यक फ़ील्ड सही भरें',
      AppLanguage.marathi: 'कृपया सर्व आवश्यक फील्ड योग्य भरा',
    },
    'pleaseSelectGender': {
      AppLanguage.english: 'Please select gender',
      AppLanguage.hindi: 'कृपया लिंग चुनें',
      AppLanguage.marathi: 'कृपया लिंग निवडा',
    },
    'registrationSuccessful': {
      AppLanguage.english: 'Registration Successful!',
      AppLanguage.hindi: 'पंजीकरण सफल हुआ!',
      AppLanguage.marathi: 'नोंदणी यशस्वी झाली!',
    },
    'somethingWentWrong': {
      AppLanguage.english: 'Something went wrong',
      AppLanguage.hindi: 'कुछ गलत हो गया',
      AppLanguage.marathi: 'काहीतरी चूक झाली',
    },
    'fullNameRequired': {
      AppLanguage.english: 'Full Name is required',
      AppLanguage.hindi: 'पूरा नाम आवश्यक है',
      AppLanguage.marathi: 'पूर्ण नाव आवश्यक आहे',
    },
    'emailAddressRequired': {
      AppLanguage.english: 'Email Address is required',
      AppLanguage.hindi: 'ईमेल पता आवश्यक है',
      AppLanguage.marathi: 'ईमेल पत्ता आवश्यक आहे',
    },
    'pleaseEnterValidEmail': {
      AppLanguage.english: 'Please enter a valid email',
      AppLanguage.hindi: 'कृपया वैध ईमेल दर्ज करें',
      AppLanguage.marathi: 'कृपया वैध ईमेल टाका',
    },
    'phoneNumberRequired': {
      AppLanguage.english: 'Phone Number is required',
      AppLanguage.hindi: 'फोन नंबर आवश्यक है',
      AppLanguage.marathi: 'फोन नंबर आवश्यक आहे',
    },
    'validTenDigitPhone': {
      AppLanguage.english: 'Please enter a valid 10-digit phone number',
      AppLanguage.hindi: 'कृपया वैध 10 अंकों का फोन नंबर दर्ज करें',
      AppLanguage.marathi: 'कृपया वैध 10 अंकी फोन नंबर टाका',
    },
    'fieldIsRequired': {
      AppLanguage.english: 'is required',
      AppLanguage.hindi: 'आवश्यक है',
      AppLanguage.marathi: 'आवश्यक आहे',
    },
    'passwordAtLeastSix': {
      AppLanguage.english: 'Password must be at least 6 characters',
      AppLanguage.hindi: 'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए',
      AppLanguage.marathi: 'पासवर्ड किमान 6 अक्षरी असावा',
    },
    'passwordsDoNotMatch': {
      AppLanguage.english: 'Passwords do not match',
      AppLanguage.hindi: 'पासवर्ड मेल नहीं खाते',
      AppLanguage.marathi: 'पासवर्ड जुळत नाहीत',
    },
    'settings': {
      AppLanguage.english: 'Settings',
      AppLanguage.hindi: 'सेटिंग्स',
      AppLanguage.marathi: 'सेटिंग्ज',
    },
    'preferences': {
      AppLanguage.english: 'Preferences',
      AppLanguage.hindi: 'प्राथमिकताएं',
      AppLanguage.marathi: 'प्राधान्ये',
    },
    'notifications': {
      AppLanguage.english: 'Notifications',
      AppLanguage.hindi: 'सूचनाएं',
      AppLanguage.marathi: 'सूचना',
    },
    'receivePushNotifications': {
      AppLanguage.english: 'Receive push notifications',
      AppLanguage.hindi: 'पुश सूचनाएं प्राप्त करें',
      AppLanguage.marathi: 'पुश सूचना मिळवा',
    },
    'locationServices': {
      AppLanguage.english: 'Location Services',
      AppLanguage.hindi: 'लोकेशन सेवाएं',
      AppLanguage.marathi: 'लोकेशन सेवा',
    },
    'allowLocationAccess': {
      AppLanguage.english: 'Allow app to access your location',
      AppLanguage.hindi: 'ऐप को आपकी लोकेशन का उपयोग करने दें',
      AppLanguage.marathi: 'अॅपला तुमची लोकेशन वापरू द्या',
    },
    'language': {
      AppLanguage.english: 'Language',
      AppLanguage.hindi: 'भाषा',
      AppLanguage.marathi: 'भाषा',
    },
    'aboutApp': {
      AppLanguage.english: 'About App',
      AppLanguage.hindi: 'ऐप के बारे में',
      AppLanguage.marathi: 'अॅपबद्दल',
    },
    'notificationsTurnedOff': {
      AppLanguage.english: 'Notifications turned off',
      AppLanguage.hindi: 'सूचनाएं बंद कर दी गईं',
      AppLanguage.marathi: 'सूचना बंद केल्या',
    },
    'notificationsTurnedOn': {
      AppLanguage.english: 'Notifications turned on',
      AppLanguage.hindi: 'सूचनाएं चालू कर दी गईं',
      AppLanguage.marathi: 'सूचना चालू केल्या',
    },
    'notificationPermissionNotGranted': {
      AppLanguage.english: 'Notification permission not granted',
      AppLanguage.hindi: 'नोटिफिकेशन अनुमति नहीं मिली',
      AppLanguage.marathi: 'नोटिफिकेशन परवानगी मिळाली नाही',
    },
    'locationTurnedOff': {
      AppLanguage.english: 'Location turned off',
      AppLanguage.hindi: 'लोकेशन बंद कर दी गई',
      AppLanguage.marathi: 'लोकेशन बंद केले',
    },
    'locationTurnedOn': {
      AppLanguage.english: 'Location turned on',
      AppLanguage.hindi: 'लोकेशन चालू कर दी गई',
      AppLanguage.marathi: 'लोकेशन चालू केले',
    },
    'locationPermissionNotGranted': {
      AppLanguage.english: 'Location permission not granted',
      AppLanguage.hindi: 'लोकेशन अनुमति नहीं मिली',
      AppLanguage.marathi: 'लोकेशन परवानगी मिळाली नाही',
    },
    'turnOnLocationServices': {
      AppLanguage.english: 'Please turn on device location services',
      AppLanguage.hindi: 'कृपया डिवाइस की लोकेशन सेवाएं चालू करें',
      AppLanguage.marathi: 'कृपया डिव्हाइसची लोकेशन सेवा सुरू करा',
    },
    'version': {
      AppLanguage.english: 'Version',
      AppLanguage.hindi: 'संस्करण',
      AppLanguage.marathi: 'आवृत्ती',
    },
    'welcomeBack': {
      AppLanguage.english: 'Welcome Back',
      AppLanguage.hindi: 'वापसी पर स्वागत है',
      AppLanguage.marathi: 'पुन्हा स्वागत आहे',
    },
    'signInToContinue': {
      AppLanguage.english: 'Sign in to continue with Trogo',
      AppLanguage.hindi: 'Trogo जारी रखने के लिए साइन इन करें',
      AppLanguage.marathi: 'Trogo सुरू ठेवण्यासाठी साइन इन करा',
    },
    'emailLogin': {
      AppLanguage.english: 'Email Login',
      AppLanguage.hindi: 'ईमेल लॉगिन',
      AppLanguage.marathi: 'ईमेल लॉगिन',
    },
    'mobileOtp': {
      AppLanguage.english: 'Mobile OTP',
      AppLanguage.hindi: 'मोबाइल OTP',
      AppLanguage.marathi: 'मोबाइल OTP',
    },
    'emailAddress': {
      AppLanguage.english: 'EMAIL ADDRESS',
      AppLanguage.hindi: 'ईमेल पता',
      AppLanguage.marathi: 'ईमेल पत्ता',
    },
    'password': {
      AppLanguage.english: 'PASSWORD',
      AppLanguage.hindi: 'पासवर्ड',
      AppLanguage.marathi: 'पासवर्ड',
    },
    'mobileNumber': {
      AppLanguage.english: 'MOBILE NUMBER',
      AppLanguage.hindi: 'मोबाइल नंबर',
      AppLanguage.marathi: 'मोबाईल नंबर',
    },
    'enterYourEmail': {
      AppLanguage.english: 'Enter your email',
      AppLanguage.hindi: 'अपना ईमेल दर्ज करें',
      AppLanguage.marathi: 'तुमचा ईमेल टाका',
    },
    'enterYourPassword': {
      AppLanguage.english: 'Enter your password',
      AppLanguage.hindi: 'अपना पासवर्ड दर्ज करें',
      AppLanguage.marathi: 'तुमचा पासवर्ड टाका',
    },
    'enterMobileNumber': {
      AppLanguage.english: 'Enter mobile number',
      AppLanguage.hindi: 'मोबाइल नंबर दर्ज करें',
      AppLanguage.marathi: 'मोबाईल नंबर टाका',
    },
    'otpWillBeSent': {
      AppLanguage.english: 'OTP will be sent to your registered mobile number.',
      AppLanguage.hindi: 'OTP आपके पंजीकृत मोबाइल नंबर पर भेजा जाएगा।',
      AppLanguage.marathi: 'OTP तुमच्या नोंदणीकृत मोबाईल नंबरवर पाठवला जाईल.',
    },
    'login': {
      AppLanguage.english: 'LOGIN',
      AppLanguage.hindi: 'लॉगिन',
      AppLanguage.marathi: 'लॉगिन',
    },
    'sendOtp': {
      AppLanguage.english: 'SEND OTP',
      AppLanguage.hindi: 'OTP भेजें',
      AppLanguage.marathi: 'OTP पाठवा',
    },
    'enterOtpVerification': {
      AppLanguage.english: 'Enter OTP Verification',
      AppLanguage.hindi: 'OTP सत्यापन दर्ज करें',
      AppLanguage.marathi: 'OTP पडताळणी टाका',
    },
    'enterCodeSentToMobile': {
      AppLanguage.english: 'Enter the code sent to your mobile number',
      AppLanguage.hindi: 'अपने मोबाइल नंबर पर भेजा गया कोड दर्ज करें',
      AppLanguage.marathi: 'तुमच्या मोबाईल नंबरवर पाठवलेला कोड टाका',
    },
    'didNotReceiveCode': {
      AppLanguage.english: "Didn't receive code? Resend in 11s",
      AppLanguage.hindi: 'कोड नहीं मिला? 11 सेकंड में फिर भेजें',
      AppLanguage.marathi: 'कोड मिळाला नाही? 11 सेकंदात पुन्हा पाठवा',
    },
    'verifyOtp': {
      AppLanguage.english: 'Verify OTP',
      AppLanguage.hindi: 'OTP सत्यापित करें',
      AppLanguage.marathi: 'OTP पडताळा',
    },
    'pleaseEnterOtp': {
      AppLanguage.english: 'Please enter OTP',
      AppLanguage.hindi: 'कृपया OTP दर्ज करें',
      AppLanguage.marathi: 'कृपया OTP टाका',
    },
    'pleaseEnterSixDigitOtp': {
      AppLanguage.english: 'Please enter 6-digit OTP',
      AppLanguage.hindi: 'कृपया 6 अंकों का OTP दर्ज करें',
      AppLanguage.marathi: 'कृपया 6 अंकी OTP टाका',
    },
    'myAccount': {
      AppLanguage.english: 'My account',
      AppLanguage.hindi: 'मेरा अकाउंट',
      AppLanguage.marathi: 'माझे खाते',
    },
    'totalRides': {
      AppLanguage.english: 'Total rides',
      AppLanguage.hindi: 'कुल राइड',
      AppLanguage.marathi: 'एकूण राइड',
    },
    'completed': {
      AppLanguage.english: 'Completed',
      AppLanguage.hindi: 'पूर्ण',
      AppLanguage.marathi: 'पूर्ण',
    },
    'cancel': {
      AppLanguage.english: 'Cancel',
      AppLanguage.hindi: 'रद्द करें',
      AppLanguage.marathi: 'रद्द करा',
    },
    'privacyPolicy': {
      AppLanguage.english: 'Privacy Policy',
      AppLanguage.hindi: 'गोपनीयता नीति',
      AppLanguage.marathi: 'गोपनीयता धोरण',
    },
    'setting': {
      AppLanguage.english: 'Setting',
      AppLanguage.hindi: 'सेटिंग',
      AppLanguage.marathi: 'सेटिंग',
    },
    'logOutTitle': {
      AppLanguage.english: 'Log Out?',
      AppLanguage.hindi: 'लॉग आउट करें?',
      AppLanguage.marathi: 'लॉग आउट करायचे?',
    },
    'logOutMessage': {
      AppLanguage.english: 'Are you sure you want to log out of your account?',
      AppLanguage.hindi: 'क्या आप वाकई अपने अकाउंट से लॉग आउट करना चाहते हैं?',
      AppLanguage.marathi: 'तुम्हाला खात्यातून लॉग आउट करायचे आहे का?',
    },
    'logOut': {
      AppLanguage.english: 'Log Out',
      AppLanguage.hindi: 'लॉग आउट',
      AppLanguage.marathi: 'लॉग आउट',
    },
    'loggedOutSuccessfully': {
      AppLanguage.english: 'Logged out successfully!',
      AppLanguage.hindi: 'सफलतापूर्वक लॉग आउट हो गया!',
      AppLanguage.marathi: 'यशस्वीरित्या लॉग आउट झाले!',
    },
    'awesomeApp': {
      AppLanguage.english: 'My Awesome App',
      AppLanguage.hindi: 'माय ऑसम ऐप',
      AppLanguage.marathi: 'माय ऑसम अॅप',
    },
    'appDescription': {
      AppLanguage.english: 'A powerful and user-friendly application built with Flutter.',
      AppLanguage.hindi: 'Flutter से बना एक शक्तिशाली और उपयोगकर्ता-अनुकूल एप्लिकेशन।',
      AppLanguage.marathi: 'Flutter मध्ये बनवलेले एक शक्तिशाली आणि वापरायला सोपे अॅप.',
    },
    'ok': {
      AppLanguage.english: 'OK',
      AppLanguage.hindi: 'ठीक है',
      AppLanguage.marathi: 'ठीक आहे',
    },
    'home': {
      AppLanguage.english: 'Home',
      AppLanguage.hindi: 'होम',
      AppLanguage.marathi: 'होम',
    },
    'transport': {
      AppLanguage.english: 'Transport',
      AppLanguage.hindi: 'ट्रांसपोर्ट',
      AppLanguage.marathi: 'ट्रान्सपोर्ट',
    },
    'history': {
      AppLanguage.english: 'History',
      AppLanguage.hindi: 'हिस्ट्री',
      AppLanguage.marathi: 'हिस्ट्री',
    },
    'profile': {
      AppLanguage.english: 'Profile',
      AppLanguage.hindi: 'प्रोफ़ाइल',
      AppLanguage.marathi: 'प्रोफाइल',
    },
    'goodMorning': {
      AppLanguage.english: 'Good Morning',
      AppLanguage.hindi: 'सुप्रभात',
      AppLanguage.marathi: 'शुभ सकाळ',
    },
    'goodAfternoon': {
      AppLanguage.english: 'Good Afternoon',
      AppLanguage.hindi: 'शुभ दोपहर',
      AppLanguage.marathi: 'शुभ दुपार',
    },
    'goodEvening': {
      AppLanguage.english: 'Good Evening',
      AppLanguage.hindi: 'शुभ संध्या',
      AppLanguage.marathi: 'शुभ संध्याकाळ',
    },
    'goodNight': {
      AppLanguage.english: 'Good Night',
      AppLanguage.hindi: 'शुभ रात्रि',
      AppLanguage.marathi: 'शुभ रात्री',
    },
    'user': {
      AppLanguage.english: 'User',
      AppLanguage.hindi: 'यूजर',
      AppLanguage.marathi: 'यूजर',
    },
    'oopsSomethingWentWrong': {
      AppLanguage.english: 'Oops! Something went wrong',
      AppLanguage.hindi: 'अरे! कुछ गलत हो गया',
      AppLanguage.marathi: 'अरे! काहीतरी चूक झाली',
    },
    'tryAgain': {
      AppLanguage.english: 'Try Again',
      AppLanguage.hindi: 'फ़िर से कोशिश करें',
      AppLanguage.marathi: 'पुन्हा प्रयत्न करा',
    },
    'whereTo': {
      AppLanguage.english: 'Where to?',
      AppLanguage.hindi: 'कहाँ जाना है?',
      AppLanguage.marathi: 'कुठे जायचे?',
    },
    'now': {
      AppLanguage.english: 'Now',
      AppLanguage.hindi: 'अभी',
      AppLanguage.marathi: 'आता',
    },
    'allCategories': {
      AppLanguage.english: 'All Categories',
      AppLanguage.hindi: 'सभी श्रेणियाँ',
      AppLanguage.marathi: 'सर्व श्रेणी',
    },
    'allVehicles': {
      AppLanguage.english: 'All Vehicles',
      AppLanguage.hindi: 'सभी वाहन',
      AppLanguage.marathi: 'सर्व वाहने',
    },
    'currentLocationNotAvailable': {
      AppLanguage.english: 'Current location not available. Please allow location',
      AppLanguage.hindi: 'वर्तमान लोकेशन उपलब्ध नहीं है. कृपया लोकेशन की अनुमति दें',
      AppLanguage.marathi: 'सध्याचे लोकेशन उपलब्ध नाही. कृपया लोकेशन अनुमती द्या',
    },
    'goodsTransport': {
      AppLanguage.english: 'Goods Transport',
      AppLanguage.hindi: 'सामान परिवहन',
      AppLanguage.marathi: 'माल वाहतूक',
    },
    'whatWouldYouLikeToDo': {
      AppLanguage.english: 'What would you like to do?',
      AppLanguage.hindi: 'आप क्या करना चाहेंगे?',
      AppLanguage.marathi: 'तुम्हाला काय करायचे आहे?',
    },
    'sendGoodsTransport': {
      AppLanguage.english: 'Send Goods Transport',
      AppLanguage.hindi: 'सामान परिवहन भेजें',
      AppLanguage.marathi: 'माल वाहतूक पाठवा',
    },
    'sendWithCityLimit': {
      AppLanguage.english: 'Send with city limit',
      AppLanguage.hindi: 'शहर की सीमा में भेजें',
      AppLanguage.marathi: 'शहराच्या हद्दीत पाठवा',
    },
    'noHistoryFound': {
      AppLanguage.english: 'No history found',
      AppLanguage.hindi: 'कोई हिस्ट्री नहीं मिली',
      AppLanguage.marathi: 'कोणतीही हिस्ट्री मिळाली नाही',
    },
    'goodsBookingsWillAppearHere': {
      AppLanguage.english: 'Your goods bookings will appear here.',
      AppLanguage.hindi: 'आपकी सामान बुकिंग यहाँ दिखाई देगी.',
      AppLanguage.marathi: 'तुमच्या माल बुकिंग इथे दिसतील.',
    },
    'myRides': {
      AppLanguage.english: 'My rides',
      AppLanguage.hindi: 'मेरी राइड्स',
      AppLanguage.marathi: 'माझ्या राइड्स',
    },
    'requested': {
      AppLanguage.english: 'Requested',
      AppLanguage.hindi: 'अनुरोधित',
      AppLanguage.marathi: 'विनंती केलेले',
    },
    'inProgress': {
      AppLanguage.english: 'In Progress',
      AppLanguage.hindi: 'प्रगति पर',
      AppLanguage.marathi: 'सुरू आहे',
    },
    'cancelled': {
      AppLanguage.english: 'Cancelled',
      AppLanguage.hindi: 'रद्द',
      AppLanguage.marathi: 'रद्द',
    },
    'ridesAndGoodsBookingsWillAppearHere': {
      AppLanguage.english: 'Your rides and goods bookings will appear here.',
      AppLanguage.hindi: 'आपकी राइड्स और सामान बुकिंग यहाँ दिखाई देगी.',
      AppLanguage.marathi: 'तुमच्या राइड्स आणि माल बुकिंग इथे दिसतील.',
    },
    'goodsDelivery': {
      AppLanguage.english: 'Goods Delivery',
      AppLanguage.hindi: 'सामान डिलिवरी',
      AppLanguage.marathi: 'माल डिलिव्हरी',
    },
    'package': {
      AppLanguage.english: 'Package',
      AppLanguage.hindi: 'पैकेज',
      AppLanguage.marathi: 'पॅकेज',
    },
    'pickUp': {
      AppLanguage.english: 'Pick-up',
      AppLanguage.hindi: 'पिक-अप',
      AppLanguage.marathi: 'पिक-अप',
    },
    'dropOff': {
      AppLanguage.english: 'Drop off',
      AppLanguage.hindi: 'ड्रॉप ऑफ',
      AppLanguage.marathi: 'ड्रॉप ऑफ',
    },
    'estimatedPrefix': {
      AppLanguage.english: 'Est:',
      AppLanguage.hindi: 'अनुमान:',
      AppLanguage.marathi: 'अन्दाज:',
    },
    'seeAll': {
      AppLanguage.english: 'See All',
      AppLanguage.hindi: 'सभी देखें',
      AppLanguage.marathi: 'सर्व पहा',
    },
    'exploreCategories': {
      AppLanguage.english: 'Explore Categories',
      AppLanguage.hindi: 'श्रेणियों एक्सप्लोर करें',
      AppLanguage.marathi: 'श्रेणी एक्सप्लोर करा',
    },
    'suggestionsForYou': {
      AppLanguage.english: 'Suggestions for you',
      AppLanguage.hindi: 'आपके लिए सुझाव',
      AppLanguage.marathi: 'तुमच्यासाठी सुचना',
    },
    'unknownLocation': {
      AppLanguage.english: 'Unknown location',
      AppLanguage.hindi: 'अज्ञात लोकेशन',
      AppLanguage.marathi: 'अज्ञात लोकेशन',
    },
    'noBannersAvailable': {
      AppLanguage.english: 'No banners available',
      AppLanguage.hindi: 'कोई बैनर उपलब्ध नहीं है',
      AppLanguage.marathi: 'कोणतेही बॅनर उपलब्ध नाही',
    },
  };

  static String t(String key) {
    final language = AppLanguageController.instance.currentLanguage;
    return _strings[key]?[language] ??
        _strings[key]?[AppLanguage.english] ??
        key;
  }
}

extension AppStringsX on String {
  String get tr => AppStrings.t(this);
}
