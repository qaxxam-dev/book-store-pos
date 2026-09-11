import 'package:flutter/services.dart';

class ForceHaptic {
  static const platform = MethodChannel('com.example.app/force_vibrate');

  static Future<void> click() async {
    try {
      await platform.invokeMethod('forceVibrate');
    } on PlatformException catch (e) {
      print("Failed to vibrate: '${e.message}'.");
    }
  }
}
