import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class LocationManager {
  static final LocationManager _instance = LocationManager._internal();
  factory LocationManager() => _instance;
  LocationManager._internal();

  Timer? _heartbeatTimer;
  bool _isHiking = false;

  void startHiking() {
    _isHiking = true;
    _startHeartbeat();
  }

  void stopHiking() {
    _isHiking = false;
    _stopHeartbeat();
    _notifyOffline();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_isHiking) return;
      try {
        await ApiService().post('/users/heartbeat');
      } catch (e) {
        debugPrint('Heartbeat failed: $e');
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
  }

  Future<void> _notifyOffline() async {
    try {
      await ApiService().post('/users/offline');
    } catch (e) {
      debugPrint('Offline notification failed: $e');
    }
  }
}
