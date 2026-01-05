// import 'dart:developer';
// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:dio/dio.dart';
// import 'package:peace_india_test_series_app/api_service/api_service.dart';
// import 'package:peace_india_test_series_app/api_service/urls.dart';
// import 'package:peace_india_test_series_app/global/utils.dart';
// import 'package:peace_india_test_series_app/model/bannar_model.dart';
// import 'package:peace_india_test_series_app/prefs/PreferencesKey.dart';
// import 'package:peace_india_test_series_app/prefs/app_preference.dart';
// import 'package:peace_india_test_series_app/screen/dashboard/dashbard_screen.dart';
//
// final loginProvider =
//     StateNotifierProvider<LoginNotifier, AsyncValue<void>>((ref) {
//   return LoginNotifier();
// });
//
// class LoginNotifier extends StateNotifier<AsyncValue<void>> {
//   LoginNotifier() : super(const AsyncValue.data(null));
//
//   Future<void> login(String stId, String password, BuildContext context) async {
//     state = const AsyncValue.loading();
//   // FirebaseMessaging messaging = FirebaseMessaging.instance;
//     // String? token = await messaging.getToken();
//     try {
//       final response = await ApiService().postRequest(
//         loginEndPoint,
//         {"student_id": stId, "generate_password": password,},
//       );
//
//       print("statusCode: ${response?.statusCode}");
//       print("status: ${response?.data['status']}");
//       print("message: ${response?.data['message']}");
//
//       if (response?.statusCode == 200 &&
//           response?.data['status'] == "success") {
//         final responseData = response!.data;
//   Utils()
//             .showToastMessage('Login successful');
//
//         await AppPreference()
//             .setString(PreferencesKey.student_id, responseData['user']['id']);
//         await AppPreference().setString(
//             PreferencesKey.institute_id, responseData['user']['institute_id']);
//         await AppPreference().setString(PreferencesKey.institute_name,
//             responseData['user']['institute_name']);
//         await AppPreference().setString(
//             PreferencesKey.student_name, responseData['user']['student_name']);
//         await AppPreference().setString(
//             PreferencesKey.student_id, responseData['user']['student_id']);
//         await AppPreference().setString(
//             PreferencesKey.mobile_no, responseData['user']['mobile_no']);
//         await AppPreference().setString(
//             PreferencesKey.email_id, responseData['user']['email_id']);
//         // await AppPreference().setString(
//         //     PreferencesKey.password, responseData['user']['password']);
//         await AppPreference().setString(PreferencesKey.generate_password,
//             responseData['user']['generate_password']);
//         await AppPreference().setString(
//             PreferencesKey.monther_name, responseData['user']['monther_name']);
//         await AppPreference().setString(
//             PreferencesKey.addar_card, responseData['user']['addar_card']);
//         await AppPreference().setString(
//             PreferencesKey.appar_id, responseData['user']['appar_id']);
//         await AppPreference()
//             .setString(PreferencesKey.city, responseData['user']['city']);
//         await AppPreference()
//             .setString(PreferencesKey.address, responseData['user']['address']);
//         await AppPreference().setString(PreferencesKey.registration_date,
//             responseData['user']['registration_date']);
//         await AppPreference().setString(
//             PreferencesKey.upload_photo, responseData['user']['upload_photo']);
//         await AppPreference().setString(
//             PreferencesKey.status, responseData['user']['status'] ?? '');
//         // await AppPreference().setString(
//         //     PreferencesKey.exam_date, responseData['user']['exam_date'] ?? '');
//
//         state = const AsyncValue.data(null);
//
//
//         //if (!context.mounted) return;
//
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => DashboardScreen()),
//         );
//       } else {
//         state = AsyncValue.error(
//           response?.data['message'] ?? 'Invalid username or password',
//           StackTrace.current,
//         );
//       }
//     } catch (e, stackTrace) {
//       print("Login Error: $e");
//       state =
//           AsyncValue.error('Failed to login. Please try again.', stackTrace);
//     }
//   }
// }
//
// // final chaperListProvider = StateProvider<List<ChapterListModel>>((ref) => []);
// // final startExamProvider = StateProvider<List<StartExamModel>>((ref) => []);
// final bannarProvider = StateProvider<List<BannarModel>>((ref) => []);
// // final videoProvider = StateProvider<List<GetVideoLIstModel>>((ref) => []);
// // final notifactionProvider = StateProvider<List<GetNotifactionLIstModel>>((ref) => []);
// // Future<void> chapterListApi(WidgetRef ref) async {
// //   print("helowwckxckdnkdfn");
// //   try {
// //     final response = await ApiService().getRequest(
// //       chapterList,
// //     );
// //     print(response?.data['status']);
// //     if (response != null && response.data['status'] == "success") {
// //       final data = response.data['data'] as List;
//
// //       print(data);
//
// //       ref.read(chaperListProvider.notifier).state =
// //           data.map((json) => ChapterListModel.fromJson(json)).toList();
// //     } else {}
// //   } catch (e) {
// //     print("Error fetching appointments: $e");
// //     throw Exception("Failed to load data");
// //   }
// // }
//
// // Future<List<StartExamModel>> StartExpamApi(WidgetRef ref, context, cName,
// //     {time, practice}) async {
// //   // log("StartExpamApi called with cName: $startPractice");
// //   var startPracticeody = {
// //     "student_id": AppPreference().getString(PreferencesKey.student_id),
// //     "chapter_name": cName
// //   };
// //   log("${startPracticeody}");
// //   log("StartExpamApi called with time: $startPractice");
// //   try {
// //     final response = await ApiService().postRequest(startPractice, {
// //       "student_id": AppPreference().getString(PreferencesKey.student_id),
// //       "chapter_name": cName
// //     });
//
// //     if (response != null) {
// //       if (response.data['status'] == "success") {
// //         final data = response.data['questions'] as List;
// //         if (data.isEmpty) {
// //           throw Exception("No questions found for this chapter.");
// //         }
// //         final hospitals =
// //             data.map((json) => StartExamModel.fromJson(json)).toList();
// //         ref.read(startExamProvider.notifier).state = hospitals;
// //         if (practice == true) {
// //           Navigator.push(
// //             context,
// //             MaterialPageRoute(builder: (context) => StartExamScreen()),
// //           );
// //         } else {
// //           Navigator.push(
// //             context,
// //             MaterialPageRoute(builder: (context) => OnlineExamScreen(time)),
// //           );
// //         }
//
// //         return hospitals;
// //       } else {
// //         // Show error message if API response has an error status
// //         throw Exception(response.data['message'] ?? "Something went wrong.");
// //       }
// //     } else {
// //       throw Exception("No response from server.");
// //     }
// //   } catch (e) {
// //     print("Error fetching questions: $e");
//
// //     // Show an error message in a Snackbar
// //     if (context.mounted) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(
// //           content: Text(e.toString()),
// //           backgroundColor: Colors.red,
// //         ),
// //       );
// //     }
// //   }
// //   return [];
// // }
//
// // Future<List<StartExamModel>> onlineExpamd(
// //     WidgetRef ref, context, cName, endpoint,
// //     {time, practice}) async {
// //   try {
// //     final response = await ApiService().getRequest(
// //       "${baseUrl + endpoint}",
// //     );
//
// //     if (response != null) {
// //       if (response.data['status'] == "success") {
// //         final data = response.data['questions'] as List;
// //         if (data.isEmpty) {
// //           throw Exception("No questions found for this chapter.");
// //         }
// //         final hospitals =
// //             data.map((json) => StartExamModel.fromJson(json)).toList();
// //         ref.read(startExamProvider.notifier).state = hospitals;
//
// //         Navigator.push(
// //           context,
// //           MaterialPageRoute(builder: (context) => OnlineExamScreen(time)),
// //         );
//
// //         return hospitals;
// //       } else {
// //         // Show error message if API response has an error status
// //         throw Exception(response.data['message'] ?? "Something went wrong.");
// //       }
// //     } else {
// //       throw Exception("No response from server.");
// //     }
// //   } catch (e) {
// //     print("Error fetching questions: $e");
//
// //     // Show an error message in a Snackbar
// //     if (context.mounted) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(
// //           content: Text(e.toString()),
// //           backgroundColor: Colors.red,
// //         ),
// //       );
// //     }
// //   }
// //   return [];
// // }
//
// Future<List<BannarModel>> bannarAPi(
//   WidgetRef ref,
// ) async {
//   try {
//     final response = await ApiService().getRequest(
// bannar,
//     );
//
//     if (response != null) {
//       if (response.data['status'] == true) {
//         final data = response.data['data'] as List;
//         if (data.isEmpty) {
//           throw Exception("No questions found for this chapter.");
//         }
//         final bannar =
//             data.map((json) => BannarModel.fromJson(json)).toList();
//         ref.read(bannarProvider.notifier).state = bannar;
//
//         return bannar;
//       } else {
//         // Show error message if API response has an error status
//         throw Exception(response.data['message'] ?? "Something went wrong.");
//       }
//     } else {
//       throw Exception("No response from server.");
//     }
//   } catch (e) {
//     print("Error fetching questions: $e");
//   }
//   return [];
// }
//
//
// // Future<List<GetVideoLIstModel>> videoApi(
// //   WidgetRef ref,
// // ) async {
// //   try {
// //     final response = await ApiService().getRequest(
// //       "https://peacexperts.org/ccc-demo/ccc-admin/api-app-online-session",
// //     );
//
// //     if (response != null) {
// //       if (response.data['status'] == true) {
// //         final data = response.data['data'] as List;
// //         if (data.isEmpty) {
// //           throw Exception("No questions found for this chapter.");
// //         }
// //         final video =
// //             data.map((json) => GetVideoLIstModel.fromJson(json)).toList();
// //         ref.read(videoProvider.notifier).state = video;
//
// //         return video;
// //       } else {
// //         // Show error message if API response has an error status
// //         throw Exception(response.data['message'] ?? "Something went wrong.");
// //       }
// //     } else {
// //       throw Exception("No response from server.");
// //     }
// //   } catch (e) {
// //     print("Error fetching questions: $e");
// //   }
// //   return [];
// // }
//
// // Future<List<GetNotifactionLIstModel>> getNotifactionList(
// //   WidgetRef ref,
// // ) async {
// //   try {
// //     final response = await ApiService().getRequest(
// //       "https://peacexperts.org/ccc-demo/ccc-admin/api-notifications",
// //     );
//
// //     if (response != null) {
// //       if (response.data['status'] == true) {
// //         final data = response.data['data'] as List;
// //         if (data.isEmpty) {
// //           throw Exception("No notifications found.");
// //         }
// //         final notifications =
// //             data.map((json) => GetNotifactionLIstModel.fromJson(json)).toList();
// //         ref.read(notifactionProvider.notifier).state = notifications;
//
// //         return notifications;
// //       } else {
// //         // Show error message if API response has an error status
// //         throw Exception(response.data['message'] ?? "Something went wrong.");
// //       }
// //     } else {
// //       throw Exception("No response from server.");
// //     }
// //   } catch (e) {
// //     print("Error fetching notifications: $e");
// //   }
// //   return [];
// // }

// Updated Login Notifier with IS_LOGGED_IN set
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:trogo_app/api_service/api_service.dart';
import 'package:trogo_app/api_service/urls.dart';
import 'package:trogo_app/global/utils.dart';
import 'package:trogo_app/location_permission_screen.dart';
import 'package:trogo_app/main_bottom_nav.dart';
import 'package:trogo_app/models/bannar_model.dart';
import 'package:trogo_app/models/estimateurl_model.dart';
import 'package:trogo_app/models/history_model.dart';
import 'package:trogo_app/models/transport_vihcle_type_model.dart';
import 'package:trogo_app/models/vehicle_type_model.dart';
import 'package:trogo_app/otp_screen.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';


final loginProvider = StateNotifierProvider<LoginNotifier, AsyncValue<void>>((
  ref,
) {
  return LoginNotifier();
});

class LoginNotifier extends StateNotifier<AsyncValue<void>> {
  LoginNotifier() : super(const AsyncValue.data(null));

  Future<void> login(String stId, String password, BuildContext context) async {
    state = const AsyncValue.loading();
    try {
      final response = await ApiService().postRequest(loginEndPoint, {
        "email":stId,
        "password":password,
        "type": "user",
      });

      print("statusCode: \${response?.statusCode}");
      print("status: \${response?.data['status']}");
      print("message: \${response?.data['message']}");

      if (response?.statusCode == 200) {
        final responseData = response!.data;
        Utils().showToastMessage('Login successful');

        final user = responseData['user'];

     

        // await AppPreference().setBool("IS_LOGGED_IN", true);

        await AppPreference().setString(PreferencesKey.authToken, response!.data['token']);
        await AppPreference().setString(PreferencesKey.userId, user['_id']);
        await AppPreference().setString(PreferencesKey.userName, user['name']);
        await AppPreference().setString(PreferencesKey.userEmail, user['email']);
        await AppPreference().setString(PreferencesKey.userMobile, user['mobile']);
        await AppPreference().setString(PreferencesKey.userGender, user['gender']);
        await AppPreference().setString(PreferencesKey.userProfileImage, user['profileImage']??"");

        state = const AsyncValue.data(null);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LocationPermissionScreen()),
        );
      } else {
        state = AsyncValue.error(
          response?.data['message'] ?? 'Invalid username or password',
          StackTrace.current,
        );
      }
    } catch (e, stackTrace) {
      print("Login Error: $e");
      state = AsyncValue.error(
        'Failed to login. Please try again.',
        stackTrace,
      );
    }
  }
}
final bannerCategoriesProvider = StateProvider<List<BannerCategory>>((ref) => []);
final bannersProvider = StateProvider<List<Banners>>((ref) => []);
final selectedCategoryProvider = StateProvider<String>((ref) => '');
final vihicletypeProvider = StateProvider<List<VehicleType>>((ref) => []);

final transdportVihicletypeProvider = StateProvider<List<TransportVehicle>>((ref) => []);


Future<List<TransportVehicle>> transportVehicletypesApi(WidgetRef ref) async {
  try {
    final response = await ApiService().getRequest(transportVehicleGet);

    if (response != null && response.statusCode == 200) {
      final data = response.data['vehicles'] as List;
      final bannar = data.map((json) => TransportVehicle.fromJson(json)).toList();
      ref.read(transdportVihicletypeProvider.notifier).state = bannar;
      return bannar;
    } else {
      throw Exception(response?.data['message'] ?? "Something went wrong.");
    }
  } catch (e) {
    print("Error fetching Suggestions: $e");
  }
  return [];
}

Future<List<VehicleType>> vehicletypesApi(WidgetRef ref) async {
  try {
    final response = await ApiService().getRequest(vehicletypes);

    if (response != null && response.statusCode == 200) {
      final data = response.data['vehicleTypes'] as List;
      final bannar = data.map((json) => VehicleType.fromJson(json)).toList();
      ref.read(vihicletypeProvider.notifier).state = bannar;
      return bannar;
    } else {
      throw Exception(response?.data['message'] ?? "Something went wrong.");
    }
  } catch (e) {
    print("Error fetching Suggestions: $e");
  }
  return [];
}
final bookingHistoryProvider = StateProvider<List<BookingHistory>>((ref) => []);

Future<List<BookingHistory>> getBookingHistoryApi(WidgetRef ref) async {
  try {
    final response = await ApiService().getRequest(history); // अपना endpoint adjust करें
    
    if (response != null && response.statusCode == 200) {
      final data = response.data['bookings'] as List;
      final bookings = data.map((json) => BookingHistory.fromJson(json)).toList();
      ref.read(bookingHistoryProvider.notifier).state = bookings;
      return bookings;
    } else {
      throw Exception(response?.data['message'] ?? "Something went wrong.");
    }
  } catch (e) {
    print("Error fetching booking history: $e");
  }
  return [];
}


Future<List<BannerCategory>> getBannerCategories() async {
    try {
      final response = await ApiService().getRequest('${baseUrl}/api/admin/banners/category');
      
      if (response != null && response.statusCode == 200) {
        final data = response.data['categories'] as List;
        return data.map((json) => BannerCategory.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print("Error fetching banner categories: $e");
      return [];
    }
  }
  
  Future<List<Banners>> getBannersByCategory(String categoryId) async {
    try {
      final response = await ApiService().getRequest('${baseUrl}/api/admin/banners?categoryId=$categoryId');
      
      if (response != null && response.statusCode == 200) {
        final data = response.data['banners'] as List;
        return data.map((json) => Banners.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print("Error fetching banners: $e");
      return [];
    }
  }



  final fareEstimateProvider =
    StateProvider<List<FareEstimate>>((ref) => []);
Future<List<FareEstimate>> fareEstimateApi({
  required WidgetRef ref,
  required String vehicleTypeId,
  required String pickupAddress,
  required List<double> pickupCoordinates,
  required String dropAddress,
  required List<double> dropCoordinates,
}) async {
  try {
    final body = {
      "category": "passenger",
      "vehicleTypeId": vehicleTypeId,
      "pickup": {
        "address": pickupAddress,
        "coordinates": pickupCoordinates,
      },
      "drop": {
        "address": dropAddress,
        "coordinates": dropCoordinates,
      }
    };

    final response = await ApiService().postRequest(
      fareEstimateUrl, // {{baseUrl}}/api/passenger/fare-estimate
       body,
    );

    if (response != null && response.statusCode == 200) {
      final List data = response.data['vehicles'];

      final fares =
          data.map((json) => FareEstimate.fromJson(json)).toList();

      ref.read(fareEstimateProvider.notifier).state = fares;

      return fares;
    } else {
      throw Exception(response?.data['message'] ?? "Something went wrong");
    }
  } catch (e) {
    print("❌ Error fetching fare estimate: $e");
  }
  return [];
}
