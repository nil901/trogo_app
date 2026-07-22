import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trogo_app/api_service/passenger_location_service.dart';

class RideLocationTrackingService {
  RideLocationTrackingService._();

  static final RideLocationTrackingService instance =
      RideLocationTrackingService._();

  StreamSubscription<Position>? _positionSubscription;
  DateTime? _lastSyncedAt;
  Position? _lastSyncedPosition;
  bool _isStarting = false;
  final Set<String> _activeOwners = <String>{};

  Future<void> start({required String owner}) async {
    _activeOwners.add(owner);
    if (_positionSubscription != null || _isStarting) return;

    await _startSubscription();
  }

  Future<void> restart({String? owner}) async {
    if (owner != null) {
      _activeOwners.add(owner);
    }
    if (_activeOwners.isEmpty) return;

    await _cancelSubscription();
    await _startSubscription();
  }

  Future<void> stop({required String owner}) async {
    _activeOwners.remove(owner);
    if (_activeOwners.isNotEmpty) return;

    await _cancelSubscription();
  }

  Future<void> _startSubscription() async {
    _isStarting = true;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        debugPrint('Ride tracking skipped because location permission is missing.');
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Ride tracking skipped because location service is disabled.');
        return;
      }

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: _buildLocationSettings(),
      ).listen(
        _handlePositionUpdate,
        onError: (Object error) {
          debugPrint('Ride tracking stream error: $error');
          _positionSubscription = null;
        },
      );
    } catch (e) {
      debugPrint('Failed to start ride tracking: $e');
      _positionSubscription = null;
    } finally {
      _isStarting = false;
    }
  }

  Future<void> _cancelSubscription() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  LocationSettings _buildLocationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Trogo location tracking active',
          notificationText:
              'Your live location is being updated during active rides.',
          enableWakeLock: true,
        ),
      );
    }

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 10,
    );
  }

  Future<void> _handlePositionUpdate(Position position) async {
    if (!_shouldSync(position)) return;

    _lastSyncedAt = DateTime.now();
    _lastSyncedPosition = position;

    await PassengerLocationService().syncPassengerLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      source: 'ride_tracking_stream',
    );
  }

  bool _shouldSync(Position position) {
    final lastSyncedPosition = _lastSyncedPosition;
    final lastSyncedAt = _lastSyncedAt;
    if (lastSyncedPosition == null || lastSyncedAt == null) {
      return true;
    }

    final movedDistance = Geolocator.distanceBetween(
      lastSyncedPosition.latitude,
      lastSyncedPosition.longitude,
      position.latitude,
      position.longitude,
    );
    final elapsed = DateTime.now().difference(lastSyncedAt);

    return movedDistance >= 10 || elapsed >= const Duration(seconds: 15);
  }
}
