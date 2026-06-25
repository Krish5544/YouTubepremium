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
    // 🌟 THE 100% REAL YOUTUBE WEB PLAYER (Vidsave जैसा) 🌟
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true, // 🌟 असली कंट्रोल्स 🌟
        showFullscreenButton: true, // 🌟 असली फुलस्क्रीन बटन 🌟
        mute: false,
        enableCaption: true, // 🌟 Subtitles (CC) का ऑप्शन 🌟
        loop: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 YoutubePlayerScaffold फुलस्क्रीन को अच्छे से हैंडल करता है 🌟
    return YoutubePlayerScaffold(
      controller: _controller,
      builder: (context, player) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F0F0F), // Premium Black Theme
          
          // जब वीडियो फुलस्क्रीन में होगी, तो AppBar अपने आप छुप जाएगा
          appBar: MediaQuery.of(context).orientation == Orientation.landscape 
            ? null 
            : AppBar(
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
              
              if (MediaQuery.of(context).orientation == Orientation.portrait) ...[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.title,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ]
            ],
          ),
        );
      },
    );
  }
}
