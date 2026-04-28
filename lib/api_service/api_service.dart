import 'dart:io';

import 'package:dio/dio.dart';
import 'package:trogo_app/api_service/urls.dart';
import 'package:trogo_app/global/utils.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';

class ApiService {
  String? tokens = AppPreference().getString(PreferencesKey.authToken);

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  Map<String, dynamic> _buildHeaders({bool includeAuth = true}) {
    final headers = <String, dynamic>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (!includeAuth) {
      print("Auth disabled for this request.");
      return headers;
    }

    final authToken = AppPreference().getString(PreferencesKey.authToken);
    print("AUTH TOKEN => $authToken");

    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    } else {
      print("No auth token found. Sending request without Authorization header.");
    }

    return headers;
  }

  Future<Response?> getRequest(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    bool includeAuth = true,
  }) async {
    try {
      return await _dio.get(
        endpoint,
        queryParameters: queryParams,
        options: Options(headers: _buildHeaders(includeAuth: includeAuth)),
      );
    } on DioError catch (e) {
      _handleDioError(e);
      return null;
    } catch (e) {
      print("Unexpected error: $e");
      return null;
    }
  }

  Future<Response?> postRequest(
    String endpoint,
    dynamic data, {
    bool includeAuth = true,
  }) async {
    try {
      print(
        "authTokentttttttttttttttttttttttttttttttttttttsa: ${AppPreference().getString(PreferencesKey.authToken)}",
      );
      print("POST endpoint: $endpoint");
      print("POST includeAuth: $includeAuth");
      print("POST request body: $data");
      print(
        "POST request headers: ${_buildHeaders(includeAuth: includeAuth)}",
      );

      final response = await _dio.post(
        endpoint,
        data: data,
        options: Options(headers: _buildHeaders(includeAuth: includeAuth)),
      );

      print("Response: ${response.data}");
      return response;
    } on DioError catch (e) {
      print("Status Code: ${e.response?.statusCode}");
      print("Response: ${e.response?.data}");
      _handleDioError(e);
      return null;
    } catch (e) {
      print("Unexpected error: $e");
      return null;
    }
  }

  Future<Response?> putRequest(
    String endpoint,
    dynamic data, {
    bool includeAuth = true,
  }) async {
    try {
      return await _dio.put(
        endpoint,
        data: data,
        options: Options(headers: _buildHeaders(includeAuth: includeAuth)),
      );
    } on DioError catch (e) {
      print(e);
      print("data");
      return null;
    } catch (e) {
      print("Unexpected error: $e");
      return null;
    }
  }

  Future<Response?> deleteRequest(
    String endpoint, {
    bool includeAuth = true,
  }) async {
    try {
      return await _dio.delete(
        endpoint,
        options: Options(headers: _buildHeaders(includeAuth: includeAuth)),
      );
    } on DioError catch (e) {
      _handleDioError(e);
      return null;
    } catch (e) {
      print("Unexpected error: $e");
      return null;
    }
  }

  void _handleDioError(DioError error) {
    if (error.response != null) {
      switch (error.response?.statusCode) {
        case 400:
          print("${error.response?.data['message']}");
          Utils().showToastMessage("${error.response?.data['message']}");
          break;
        case 401:
          Utils().showToastMessage("${error.response?.data['message']}");
          break;
        case 403:
          Utils().showToastMessage("${error.response?.data['message']}");
          break;
        case 404:
          Utils().showToastMessage("${error.response?.data['message']}");
          break;
        case 500:
          Utils().showToastMessage(error.response?.data['message']);
          break;
        default:
          Utils().showToastMessage("${error.response?.data['message']}");
          break;
      }
    } else {
      switch (error.type) {
        case DioErrorType.connectionTimeout:
          print("Connection timeout occurred.");
          Utils().showToastMessage("Connection timeout occurred.");
          break;
        case DioErrorType.receiveTimeout:
          print("Receive timeout occurred.");
          Utils().showToastMessage("Receive timeout occurred.");
          break;
        case DioErrorType.sendTimeout:
          print("Send timeout occurred.");
          Utils().showToastMessage("Send timeout occurred.");
          break;
        case DioErrorType.cancel:
          print("Request was cancelled.");
          Utils().showToastMessage("Request was cancelled.");
          break;
        case DioErrorType.unknown:
          if (error.error is SocketException) {
            print("No Internet connection. Please check your network.");
            Utils().showToastMessage(
              "No Internet connection. Please check your network.",
            );
          } else {
            print("Unexpected error: ${error.message}");
            Utils().showToastMessage("Unexpected error: ${error.message}");
          }
          break;
        default:
          print("Unknown DioError: ${error.message}");
          Utils().showToastMessage("Unknown DioError: ${error.message}");
          break;
      }
    }
  }
}
