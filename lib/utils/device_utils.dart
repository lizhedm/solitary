import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceUtils {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static bool? _isSimulator;

  static Future<bool> isSimulator() async {
    if (_isSimulator != null) return _isSimulator!;

    if (kIsWeb) {
      _isSimulator = false;
      return false;
    }

    try {
      if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _isSimulator = !iosInfo.isPhysicalDevice;
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _isSimulator = !androidInfo.isPhysicalDevice;
      } else {
        _isSimulator = false;
      }
    } catch (e) {
      debugPrint('Error checking device info: $e');
      _isSimulator = false;
    }

    return _isSimulator!;
  }
}
