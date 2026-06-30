import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
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
  // 🌟 THE DECODER: YouTube API का बाप 🌟
  final YoutubeExplode _yt = YoutubeExplode();
  
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _extractAndPlayVideo();
  }

  // 🚀 यह फंक्शन YouTube से असली MP4 लिंक निकालेगा
  Future<void> _extractAndPlayVideo() async {
    try {
      // 1. YouTube से वीडियो का 'कच्चा चिट्ठा' (Manifest) मंगाना
      var manifest = await _yt.videos.streamsClient.getManifest(widget.videoId);
      
      // 🌟 MAGIC FIX: यहाँ muxedStreams की जगह 'muxed' और 'withHighestVideoQuality()' का इस्तेमाल होगा 🌟
      var streamInfo = manifest.muxed.withHighestVideoQuality();
      var realMp4Url = streamInfo.url.toString();

      // 3. इस असली MP4 लिंक को हमारे Android ExoPlayer को भेज देना
      await NativePlayerBridge.playVideo(realMp4Url);
      
      if (mounted) {
        setState(() {
          _isLoading = false; // लोडिंग खत्म, प्लेयर रेडी!
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "वीडियो लिंक नहीं मिल पाया! Error: $e";
        });
      }
    }
  }

  @override
  void dispose() {
    _yt.close(); // मेमोरी बचाने के लिए डिकोडर बंद करना
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
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.red))
                : _errorMessage.isNotEmpty
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(_errorMessage, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                      ))
                    : const AndroidView(
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
