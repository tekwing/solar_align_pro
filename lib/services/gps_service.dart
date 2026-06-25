import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class GpsService {
  /// Fetches the current location after verifying permissions platform-safely
  Future<Position?> getLocation() async {
    // 1. Check if location services are enabled on the device
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'Location services are disabled. Please enable them in settings.',
      );
    }

    // 2. Platform-Specific Permission Handling
    if (kIsWeb) {
      // WEB LOGIC: Use Geolocator's internal browser permission check
      LocationPermission webPermission = await Geolocator.checkPermission();
      if (webPermission == LocationPermission.denied) {
        webPermission = await Geolocator.requestPermission();
        if (webPermission == LocationPermission.denied) {
          throw Exception('Location permission denied in browser.');
        }
      }
      if (webPermission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permissions permanently denied in browser. Please check browser settings.',
        );
      }
    } else {
      // MOBILE LOGIC: Use permission_handler for native iOS/Android dialogs
      var status = await Permission.locationWhenInUse.status;
      if (status.isDenied) {
        status = await Permission.locationWhenInUse.request();
        if (status.isDenied) {
          throw Exception(
            'Location permission denied. Cannot auto-fetch coordinates.',
          );
        }
      }

      if (status.isPermanentlyDenied) {
        throw Exception(
          'Location permissions are permanently denied. Please open app settings.',
        );
      }
    }

    // 3. Get the high-accuracy position
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
