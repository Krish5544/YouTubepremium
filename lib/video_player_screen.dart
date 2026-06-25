import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

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
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    // 🌟 THE 100% REAL YOUTUBE WEB PLAYER (बिना किसी बदलाव के) 🌟
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true, 
        showFullscreenButton: true, 
        mute: false,
        enableCaption: true, 
        loop: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    // 🌟 स्क्रीन से बैक आने पर फोन को वापस सीधा करने के लिए 🌟
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 YoutubePlayerScaffold फुलस्क्रीन को एकदम स्मूथली हैंडल करता है 🌟
    return YoutubePlayerScaffold(
      controller: _controller,
      builder: (context, player) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F0F0F), // Premium Black Theme
          
          // 🌟 MAGIC FIX: हमने यहाँ से MediaQuery वाला कोड हटा दिया है। 
          // अब पैकेज खुद ही फुलस्क्रीन को मक्खन की तरह हैंडल करेगा! 🌟
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text("ProTube Video", style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
              
          body: Column(
            children: [
              // 🌟 यहाँ तुम्हारा Vidsave वेबसाइट वाला हूबहू असली प्लेयर दिखेगा 🌟
              player,
              
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
      },
    );
  }
}
