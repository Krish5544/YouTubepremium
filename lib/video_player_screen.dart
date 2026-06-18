import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart'; // 🌟 शेयर पैकेज एकदम सुरक्षित है

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
  
  // 🌟 डिस्क्रिप्शन को छोटा-बड़ा करने का स्टेट वेरिएबल
  bool _isDescriptionExpanded = false;

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

  // 🌟 शेयर करने का मास्टर फंक्शन
  void _shareVideo() {
    final String youtubeLink = 'https://youtu.be/${widget.videoId}';
    Share.share('इस शानदार वीडियो को ProTube पर देखें:\n${widget.title}\n\nलिंक: $youtubeLink');
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlayerReady) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: const Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    // ग्लोबल बैक बटन गार्ड
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
                  // 1. वीडियो प्लेयर (टॉप पर फिक्स)
                  player,
                  
                  // 2. नीचे का पूरा स्क्रॉल होने वाला हिस्सा
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                      children: [
                        // 🎥 वीडियो का टाइटल
                        Text(
                          widget.title,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        
                        // व्यूज और टाइम की डमी लाइन
                        const Text(
                          "120K views • 2 days ago",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        
                        // 🤝 1. चैनल नाम और सब्सक्राइब बटन रो (Row)
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.red,
                              child: Icon(Icons.play_arrow, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("ProTube Online Classes", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                  Text("2.5M subscribers", style: TextStyle(color: Colors.grey, fontSize: 11)),
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
                        
                        // 🚀 2. यूट्यूब स्टाइल एक्शन बार (लाइक, शेयर, डाउनलोड)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // लाइक बटन (पिल शेप)
                              _buildPillButton(
                                icon: Icons.thumb_up_out_outlined,
                                label: "15K",
                                onTap: () {},
                              ),
                              const SizedBox(width: 8),
                              
                              // 🌟 हमारा असली काम करने वाला 'Share' बटन 🌟
                              _buildPillButton(
                                icon: Icons.share_outlined,
                                label: "Share",
                                onTap: _shareVideo, // क्लिक करते ही शेयर फंक्शन कॉल होगा
                              ),
                              const SizedBox(width: 8),
                              
                              // डाउनलोड बटन (पिल शेप)
                              _buildPillButton(
                                icon: Icons.vertical_align_bottom_outlined,
                                label: "Download",
                                onTap: () {},
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        
                        // 📝 3. स्मार्ट और एक्सपेंडेबल डिस्क्रिप्शन बॉक्स
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
                                      ? "नमस्कार साथियों! ProTube ऐप में आपका स्वागत है। इस वीडियो में हमने आगामी प्रतियोगी परीक्षाओं (जैसे UPSSSC Lower PCS, RO/ARO) के लिए बेहद महत्वपूर्ण विषयों को कवर किया है। अपनी तैयारी को मजबूत करने के लिए क्लास को अंत तक जरूर देखें।\n\n🔹 परीक्षा उपयोगी महत्वपूर्ण नोट्स\n🔹 पिछले वर्षों के प्रश्नों का विश्लेषण\n\nवीडियो को लाइक करें और अपने दोस्तों के साथ SHARE करना न भूलें! धन्यवाद।"
                                      : "नमस्कार साथियों! ProTube ऐप में आपका स्वागत है। इस वीडियो में हमने आगामी प्रतियोगी परीक्षाओं के लिए...",
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
                        
                        // 'Up Next' या रिलेटेड वीडियोज़ की हेडिंग
                        const Text("Up next", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 14),
                        ...List.generate(6, (index) => _buildDummyRelatedVideo()),
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

  // यूट्यूब स्टाइल पिल बटन्स बनाने का सुंदर विजेट
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

  // डमी वीडियोज़ का डिज़ाइन
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
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.play_circle_outline, color: Colors.white30, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 12, width: double.infinity, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(height: 12, width: 120, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(height: 10, width: 70, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
              ],
            ),
          )
        ],
      ),
    );
  }
}
