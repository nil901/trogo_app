

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:trogo_app/api_service/api_service.dart';
import 'package:trogo_app/api_service/urls.dart';
import 'package:trogo_app/auth/login_notifier.dart';
import 'package:trogo_app/models/recent_drop_model.dart';


import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trogo_app/models/recent_drop_model.dart';
import 'package:trogo_app/prefs/PreferencesKey.dart';
import 'package:trogo_app/prefs/app_preference.dart';
class RecentDropModel {
  final String id;
  final String userId;
  final DropLocation drop;
  final DateTime lastUsedAt;

  RecentDropModel({
    required this.id,
    required this.userId,
    required this.drop,
    required this.lastUsedAt,
  });

  factory RecentDropModel.fromJson(Map<String, dynamic> json) {
    return RecentDropModel(
      id: json['_id'] ?? '',
      userId: json['user'] ?? '',
      drop: DropLocation.fromJson(json['drop'] ?? {}),
      lastUsedAt: DateTime.parse(
        json['lastUsedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class DropLocation {
  final String address;
  final double lat;
  final double lng;

  DropLocation({
    required this.address,
    required this.lat,
    required this.lng,
  });

  factory DropLocation.fromJson(Map<String, dynamic> json) {
    List<dynamic> coordinates = json['coordinates'] ?? [0.0, 0.0];
    return DropLocation(
      address: json['address'] ?? '',
      lat: coordinates.isNotEmpty ? coordinates[1].toDouble() : 0.0,
      lng: coordinates.isNotEmpty ? coordinates[0].toDouble() : 0.0,
    );
  }
}
final recentDropProvider = StateProvider<List<RecentDropModel>>((ref) {
  return [];
});

final recentDropLoadingProvider = StateProvider<bool>((ref) {
  return false;
});

Future<void> fetchRecentDrops(WidgetRef ref) async {
  try {
    ref.read(recentDropLoadingProvider.notifier).state = true;
    final authToken = AppPreference().getString(PreferencesKey.authToken);
    if (authToken.isEmpty) {
      debugPrint('Skipping recent drops fetch because auth token is missing.');
      ref.read(recentDropProvider.notifier).state = [];
      return;
    }
    
    final response = await ApiService().getRequest(recentDropList);
    log("datrnhhhhhhhhhhhhhhhhhhhhhh${response?.data}");
    if (response != null && response.statusCode == 200) {
      final data = response.data;
      
      if (data != null && data is List) {
        List<RecentDropModel> recentDrops = [];
        
        for (var item in data) {
          recentDrops.add(RecentDropModel.fromJson(item));
        }
        
        // Sort by lastUsedAt (most recent first)
        recentDrops.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
        
        ref.read(recentDropProvider.notifier).state = recentDrops;
      }
    } else {
      debugPrint("Failed to fetch recent drops: ${response?.statusCode}");
    }
  } catch (e) {
    debugPrint("Error fetching recent drops: $e");
  } finally {
    ref.read(recentDropLoadingProvider.notifier).state = false;
  }
}
