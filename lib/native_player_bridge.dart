import 'package:flutter/services.dart';

class NativePlayerBridge {
  // 🌟 यह चैनल का नाम Android (MainActivity.kt) से बिल्कुल मैच होना चाहिए 🌟
  static const platform = MethodChannel('com.protube.zero/player');

  // 🚀 Android के नेटिव प्लेयर को वीडियो का लिंक भेजने वाला फंक्शन
  static Future<void> playVideo(String videoUrl) async {
    try {
      await platform.invokeMethod('playVideo', {"url": videoUrl});
    } on PlatformException catch (e) {
      print("Native Player Error: ${e.message}");
    }
  }
}
