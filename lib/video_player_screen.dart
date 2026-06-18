import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // 🌟 असली वीडियोज़ मंगाने के लिए
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
  bool _isDescriptionExpanded = false;
  
  // 🌟 असली वीडियोज़ के लिए वेरिएबल्स
  List<Map<String, dynamic>> _relatedVideos = [];
  bool _isLoadingRelated = true;
  final String apiKey = 'AIzaSyBpPAohs_WhlCTiozmCVMEzrGsRE86LgpU';

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _fetchRelatedVideos(); // वीडियोज़ मंगाने का फंक्शन कॉल
  }

  // 🌟 YouTube API से असली 'Up Next' वीडियोज़ मंगाना
  Future<void> _fetchRelatedVideos() async {
    try {
      // वीडियो के टाइटल से मिलते-जुलते कीवर्ड्स निकालना
      String query = Uri.encodeComponent(widget.title.split(' ').take(3).join(' '));
      String url = 'https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=15&q=$query&type=video&key=$apiKey';

      var res = await http.get(Uri.parse(url));
      var data = jsonDecode(res.body);
      List items = data['items'] ?? [];
      
      List<Map<String, dynamic>> newResults = [];
      for (var item in items) {
        // जो वीडियो चल रही है, उसे दोबारा लिस्ट में नहीं दिखाना
        if (item['id']['videoId'] != widget.videoId) {
          newResults.add({
            'id': item['id']['videoId'],
            'title': item['snippet']['title'],
            'thumbnail': item['snippet']['thumbnails']['high']?['url'] ?? '',
            'channel': item['snippet']['channelTitle'],
            'date': item['snippet']['publishedAt'],
          });
        }
      }
      
      if (mounted) {
        setState(() {
          _relatedVideos = newResults;
          _isLoadingRelated = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRelated = false);
    }
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

  void _shareVideo() {
    final String youtubeLink = 'https://youtu.be/${widget.videoId}';
    Share.share('इस शानदार वीडियो को ProTube पर देखें:\n${widget.title}\n\nलिंक: $youtubeLink');
  }

  String _formatDate(String dateStr) {
    try {
      DateTime date = DateTime.parse(dateStr);
      return "${date.day}/${date.month}/${date.year}";
    } catch(e) { return ""; }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlayerReady) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: const Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

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
            body: SafeArea(
              child: Column(
                children: [
                  // 1. वीडियो प्लेयर (सबसे ऊपर फिक्स)
                  player,
                  
                  // 2. नीचे की स्क्रॉल लिस्ट
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.red,
                              child: Icon(Icons.play_arrow, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text("ProTube Channel", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                  Text("Subscribe & Learn", style: TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text("Subscribe", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildPillButton(icon: Icons.thumb_up_outlined, label: "Like", onTap: () {}),
                              const SizedBox(width: 8),
                              _buildPillButton(icon: Icons.share_outlined, label: "Share", onTap: _shareVideo),
                              const SizedBox(width: 8),
                              _buildPillButton(icon: Icons.download_outlined, label: "Download", onTap: () {}),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isDescriptionExpanded = !_isDescriptionExpanded;
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isDescriptionExpanded 
                                      ? "ProTube ऐप में आपका स्वागत है। इस वीडियो में हमने आगामी परीक्षाओं के लिए महत्वपूर्ण विषयों को कवर किया है।\n\nअपनी तैयारी को मजबूत करने के लिए पूरी वीडियो देखें और हमारे चैनल को सपोर्ट करें।"
                                      : "ProTube ऐप में आपका स्वागत है। इस वीडियो में...",
                                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                                  maxLines: _isDescriptionExpanded ? 100 : 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isDescriptionExpanded ? "Show less" : "...more",
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white12, thickness: 1),
                        const SizedBox(height: 10),
                        
                        const Text("Up next", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 14),
                        
                        // 🌟 असली वीडियोज़ का डिज़ाइन 🌟
                        if (_isLoadingRelated)
                          const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Colors.red)))
                        else if (_relatedVideos.isEmpty)
                          const Center(child: Text("No related videos found", style: TextStyle(color: Colors.grey)))
                        else
                          ..._relatedVideos.map((video) => _buildRealRelatedVideo(video)).toList(),
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

  Widget _buildPillButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // 🌟 असली 'Up next' वीडियोज़ का कार्ड
  Widget _buildRealRelatedVideo(Map<String, dynamic> video) {
    return GestureDetector(
      onTap: () {
        // वीडियो पर क्लिक करते ही नया प्लेयर खुल जाएगा
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              videoId: video['id'],
              title: video['title'],
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                video['thumbnail'],
                width: 140,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(width: 140, height: 80, color: Colors.grey[800]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video['title'],
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${video['channel']} • ${_formatDate(video['date'])}",
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
