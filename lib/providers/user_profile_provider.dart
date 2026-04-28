import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:trogo_app/api_service/api_service.dart';
import 'package:trogo_app/api_service/urls.dart';
import 'package:trogo_app/models/user_profile.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfile?>>((ref) => UserProfileNotifier());

class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  UserProfileNotifier() : super(const AsyncValue.loading());

  Future<void> fetchProfile() async {
    final previousProfile = state.asData?.value;
    final authToken = AppPreference().getString(PreferencesKey.authToken);
    if (authToken.isEmpty) {
      debugPrint('Skipping profile fetch because auth token is missing.');
      if (previousProfile != null) {
        state = AsyncValue.data(previousProfile);
      }
      return;
    }

    if (previousProfile == null) {
      state = const AsyncValue.loading();
    }

    try {
      final response = await ApiService().getRequest(profileGet);
      debugPrint('fetchProfile response: ${response?.data}');

      if (response != null && response.statusCode == 200) {
        final record = response.data['record'];
        final profile = UserProfile.fromJson(record);
        await AppPreference().setString(PreferencesKey.userName, profile.name);
        await AppPreference().setString(PreferencesKey.userEmail, profile.email);
        await AppPreference().setString(
          PreferencesKey.userMobile,
          profile.mobile,
        );
        await AppPreference().setString(
          PreferencesKey.userGender,
          profile.gender,
        );
        await AppPreference().setString(
          PreferencesKey.userProfileImage,
          profile.profileImage ?? '',
        );
        state = AsyncValue.data(profile);
      } else {
        if (previousProfile != null) {
          state = AsyncValue.data(previousProfile);
        } else {
          state = AsyncValue.error(
            'Failed to fetch profile',
            StackTrace.current,
          );
        }
      }
    } catch (e, s) {
      debugPrint('fetchProfile error: $e');
      if (previousProfile != null) {
        state = AsyncValue.data(previousProfile);
      } else {
        state = AsyncValue.error(e.toString(), s);
      }
    }
  }

  void reset() {
    state = const AsyncValue.loading();
  }
}
