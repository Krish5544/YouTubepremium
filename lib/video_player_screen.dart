import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'native_player_bridge.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.videoId,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  @override
  void initState() {
    super.initState();
    // 🌟 जैसे ही स्क्रीन खुलेगी, हम Native Android को वीडियो प्ले करने का सिग्नल भेजेंगे 🌟
    _startNativePlayer();
  }

  Future<void> _startNativePlayer() async {
    // हमारा ब्रिज Android को वीडियो की ID भेजेगा
    await NativePlayerBridge.playVideo(widget.videoId);
  }

  @override
  void dispose() {
    // 🌟 स्क्रीन से बैक आने पर फोन को वापस सीधा करने के लिए 🌟
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F), // Premium Black Theme
      
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("ProTube Native", style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
          
      body: Column(
        children: [
          // 🌟 THE REAL NATIVE ENGINE (AndroidView) 🌟
          // यह वो जगह है जहाँ Android अपना असली ExoPlayer रेंडर करेगा!
          const AspectRatio(
            aspectRatio: 16 / 9,
            child: AndroidView(
              viewType: 'native-player-view',
              creationParamsCodec: StandardMessageCodec(),
            ),
          ),
          
          // 🌟 वीडियो के नीचे का हिस्सा (टाइटल) 🌟
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white, 
                      fontSize: 18, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
