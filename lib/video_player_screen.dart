import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // यह फंक्शन पुरानी सेव की हुई टाइमिंग ढूँढेगा
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

  // यह फंक्शन वीडियो चलते हुए उसकी टाइमिंग सेव करेगा
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
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text(widget.title), backgroundColor: Colors.black),
        body: const Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    // 🌟 WillPopScope: वीडियो प्लेयर स्क्रीन का बैक बटन फिक्स 🌟
    return WillPopScope(
      onWillPop: () async {
        // अगर वीडियो फुल स्क्रीन मोड में चल रही है, तो बैक दबाने पर पहले नॉर्मल मोड में आएगी
        if (_controller.value.isFullScreen) {
          _controller.toggleFullScreenMode();
          return false; // ऐप या स्क्रीन को बंद मत होने दो
        }
        return true; // नॉर्मल मोड में पिछले पेज पर जाने दो
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
            backgroundColor: Colors.black,
            appBar: AppBar(
              title: Text(widget.title),
              backgroundColor: Colors.black,
            ),
            body: Center(child: player),
          );
        },
      ),
    );
  }
}
