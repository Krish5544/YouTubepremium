import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;
  const VideoPlayerScreen({super.key, required this.videoId, required this.title});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final prefs = await SharedPreferences.getInstance();
    int startPosition = 0;
    
    try {
      List<String> historyList = prefs.getStringList('video_history') ?? [];
      for (String item in historyList) {
        Map<String, dynamic> data = jsonDecode(item);
        if (data['id'] == widget.videoId) {
          startPosition = data['position'] ?? 0;
          break;
        }
      }
    } catch (e) {
      debugPrint("History load error: $e");
    }

    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        startAt: startPosition, 
      ),
    )..addListener(_savePosition);

    if (mounted) {
      setState(() {
        _isPlayerReady = true;
      });
    }
  }

  void _savePosition() async {
    if (_controller.value.isReady) {
      final prefs = await SharedPreferences.getInstance();
      List<String> historyList = prefs.getStringList('video_history') ?? [];
      
      historyList.removeWhere((item) {
        try {
          Map<String, dynamic> data = jsonDecode(item);
          return data['id'] == widget.videoId;
        } catch (e) {
          return false;
        }
      });

      Map<String, dynamic> newData = {
        'id': widget.videoId,
        'title': widget.title,
        'position': _controller.value.position.inSeconds,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      historyList.insert(0, jsonEncode(newData));
      await prefs.setStringList('video_history', historyList);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_savePosition);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlayerReady) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: const Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    // 🌟 बैक बटन गार्ड एकदम सुरक्षित है 🌟
    return WillPopScope(
      onWillPop: () async {
        if (_controller.value.isFullScreen) {
          _controller.toggleFullScreenMode();
          return false; 
        }
        return true; 
      },
      child: YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
          progressColors: const ProgressBarColors(
            playedColor: Colors.red,
            handleColor: Colors.redAccent,
          ),
          bottomActions: [
            const CurrentPosition(),
            const ProgressBar(isExpanded: true),
            const RemainingDuration(),
            const FullScreenButton(), 
          ],
        ),
        builder: (context, player) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F0F0F),
            // 🚀 यहाँ से AppBar हटा दिया गया है ताकि प्लेयर टॉप पर रहे 🚀
            body: SafeArea(
              child: Column(
                children: [
                  // 1. वीडियो प्लेयर (टॉप पर फिक्स रहेगा)
                  player,
                  
                  // 2. नीचे का हिस्सा जो स्क्रॉल होगा
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                      children: [
                        // वीडियो का टाइटल
                        Text(
                          widget.title,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        
                        // 🌟 यह वो जगह है जहाँ हम अगले टास्क में 'शेयर बटन' और 'डिस्क्रिप्शन' लगाएंगे 🌟
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              "यहाँ हमारा शेयर बटन और स्मार्ट डिस्क्रिप्शन आएगा\n(अगले टास्क में)",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white24, thickness: 1),
                        const SizedBox(height: 12),
                        
                        // 'Up Next' या रिलेटेड वीडियोज़ (स्क्रॉल फील के लिए डमी UI)
                        const Text("Up next", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        ...List.generate(8, (index) => _buildDummyRelatedVideo()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // डमी वीडियोज़ बनाने का फंक्शन (डिज़ाइन के लिए)
  Widget _buildDummyRelatedVideo() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 140,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.play_circle_outline, color: Colors.white54, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: double.infinity, color: Colors.grey[800]),
                const SizedBox(height: 8),
                Container(height: 14, width: 120, color: Colors.grey[800]),
                const SizedBox(height: 8),
                Container(height: 12, width: 80, color: Colors.grey[900]),
              ],
            ),
          )
        ],
      ),
    );
  }
}
