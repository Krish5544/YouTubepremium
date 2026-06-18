import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';

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
  
  List<Map<String, dynamic>> _relatedVideos = [];
  bool _isLoadingRelated = true;
  final String apiKey = 'AIzaSyBpPAohs_WhlCTiozmCVMEzrGsRE86LgpU';
  
  bool _isNavigatingToNext = false; 
  bool _isFullScreenState = false;

  // 🌟 Save फीचर का वेरिएबल
  bool _isSaved = false;

  // MX Player जेस्चर के वेरिएबल्स
  double _volume = 0.5;
  double _brightness = 0.5;
  bool _showIndicator = false;
  IconData _indicatorIcon = Icons.volume_up;
  String _indicatorText = "";
  Timer? _indicatorTimer;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _fetchRelatedVideos();
    _initGestures();
    _checkIfSaved(); // 🌟 चेक करेगा कि वीडियो पहले से सेव है या नहीं
  }

  // 🌟 चेक करने का फंक्शन कि वीडियो सेव है या नहीं
  Future<void> _checkIfSaved() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedList = prefs.getStringList('saved_videos') ?? [];
    bool exists = false;
    for (String item in savedList) {
      try {
        if (jsonDecode(item)['id'] == widget.videoId) {
          exists = true;
          break;
        }
      } catch(e) {}
    }
    if (mounted) setState(() => _isSaved = exists);
  }

  // 🌟 वीडियो को लोकल तिजोरी में सेव/अनसेव करने का फंक्शन 🌟
  Future<void> _toggleSaveVideo() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedList = prefs.getStringList('saved_videos') ?? [];
    
    Map<String, dynamic> videoData = {
      'id': widget.videoId,
      'title': widget.title,
    };
    String videoJson = jsonEncode(videoData);

    if (_isSaved) {
      savedList.removeWhere((item) {
        try { return jsonDecode(item)['id'] == widget.videoId; } catch(e) { return false; }
      });
      if (mounted) setState(() => _isSaved = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("वीडियो हटा दी गई", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
    } else {
      savedList.removeWhere((item) {
        try { return jsonDecode(item)['id'] == widget.videoId; } catch(e) { return false; }
      });
      savedList.insert(0, videoJson);
      if (mounted) setState(() => _isSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("वीडियो सेव हो गई", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
    }
    prefs.setStringList('saved_videos', savedList);
  }

  Future<void> _initGestures() async {
    try {
      await FlutterVolumeController.updateShowSystemUI(false);
      double? initVol = await FlutterVolumeController.getVolume();
      if (initVol != null && mounted) setState(() => _volume = initVol);
      double initBright = await ScreenBrightness().current;
      if (mounted) setState(() => _brightness = initBright);
    } catch (e) {
      debugPrint("Gesture Init Error: $e");
    }
  }

  Future<void> _fetchRelatedVideos() async {
    try {
      String query = Uri.encodeComponent(widget.title.split(' ').take(3).join(' '));
      String url = 'https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=15&q=$query&type=video&key=$apiKey';
      var res = await http.get(Uri.parse(url));
      var data = jsonDecode(res.body);
      List items = data['items'] ?? [];
      
      List<Map<String, dynamic>> newResults = [];
      for (var item in items) {
        if (item['id']['videoId'] != widget.videoId) {
          newResults.add({
            'id': item['id']['videoId'], 'title': item['snippet']['title'],
            'thumbnail': item['snippet']['thumbnails']['high']?['url'] ?? '',
            'channel': item['snippet']['channelTitle'], 'date': item['snippet']['publishedAt'],
          });
        }
      }
      if (mounted) setState(() { _relatedVideos = newResults; _isLoadingRelated = false; });
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
    } catch (e) { }

    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: YoutubePlayerFlags(autoPlay: true, mute: false, startAt: startPosition),
    )..addListener(_videoListener);

    if (mounted) setState(() => _isPlayerReady = true);
  }

  void _videoListener() async {
    if (_controller.value.isFullScreen != _isFullScreenState) {
      _isFullScreenState = _controller.value.isFullScreen;
      if (_isFullScreenState) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      if (mounted) setState(() {}); 
    }

    if (_controller.value.isReady && !_isNavigatingToNext) {
      final prefs = await SharedPreferences.getInstance();
      List<String> historyList = prefs.getStringList('video_history') ?? [];
      historyList.removeWhere((item) {
        try { return jsonDecode(item)['id'] == widget.videoId; } catch (e) { return false; }
      });
      Map<String, dynamic> newData = {
        'id': widget.videoId, 'title': widget.title,
        'position': _controller.value.position.inSeconds, 'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      historyList.insert(0, jsonEncode(newData));
      prefs.setStringList('video_history', historyList);
    }

    if (_controller.value.playerState == PlayerState.ended && !_isNavigatingToNext) {
      _isNavigatingToNext = true; 
      if (_relatedVideos.isNotEmpty) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            final nextVideo = _relatedVideos[0];
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => VideoPlayerScreen(videoId: nextVideo['id'], title: nextVideo['title'])));
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    FlutterVolumeController.updateShowSystemUI(true);
    super.dispose();
  }

  void _changeVolume(double delta) {
    setState(() {
      _volume += delta;
      if (_volume > 1.0) _volume = 1.0;
      if (_volume < 0.0) _volume = 0.0;
      FlutterVolumeController.setVolume(_volume);
      _indicatorIcon = _volume > 0 ? Icons.volume_up : Icons.volume_off;
      _indicatorText = "${(_volume * 100).toInt()}%";
      _showIndicator = true;
    });
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 2), () { if (mounted) setState(() => _showIndicator = false); });
  }

  void _changeBrightness(double delta) {
    setState(() {
      _brightness += delta;
      if (_brightness > 1.0) _brightness = 1.0;
      if (_brightness < 0.0) _brightness = 0.0;
      ScreenBrightness().setScreenBrightness(_brightness);
      _indicatorIcon = Icons.brightness_6;
      _indicatorText = "${(_brightness * 100).toInt()}%";
      _showIndicator = true;
    });
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 2), () { if (mounted) setState(() => _showIndicator = false); });
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

  Widget _buildGestureOverlay() {
    return Column(
      children: [
        Navigator.canPop(context) ? const SizedBox() : const SizedBox(),
        Expanded(
          flex: 8,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragUpdate: (details) => _changeBrightness(-details.primaryDelta! / 200),
                  onDoubleTap: () {
                    _controller.seekTo(_controller.value.position - const Duration(seconds: 10));
                    setState(() { _indicatorIcon = Icons.fast_rewind; _indicatorText = "-10s"; _showIndicator = true; });
                    _indicatorTimer?.cancel();
                    _indicatorTimer = Timer(const Duration(seconds: 1), () { if (mounted) setState(() => _showIndicator = false); });
                  },
                  child: Container(),
                ),
              ),
              Expanded(flex: 4, child: IgnorePointer(child: Container())),
              Expanded(
                flex: 3,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragUpdate: (details) => _changeVolume(-details.primaryDelta! / 200),
                  onDoubleTap: () {
                    _controller.seekTo(_controller.value.position + const Duration(seconds: 10));
                    setState(() { _indicatorIcon = Icons.fast_forward; _indicatorText = "+10s"; _showIndicator = true; });
                    _indicatorTimer?.cancel();
                    _indicatorTimer = Timer(const Duration(seconds: 1), () { if (mounted) setState(() => _showIndicator = false); });
                  },
                  child: Container(),
                ),
              ),
            ],
          ),
        ),
        Expanded(flex: 2, child: IgnorePointer(child: Container())),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlayerReady) return const Scaffold(backgroundColor: Color(0xFF0F0F0F), body: Center(child: CircularProgressIndicator(color: Colors.red)));

    return WillPopScope(
      onWillPop: () async {
        if (_isFullScreenState) { _controller.toggleFullScreenMode(); return false; }
        return true; 
      },
      child: OrientationBuilder(
        builder: (context, orientation) {
          bool isLandscape = orientation == Orientation.landscape;
          
          Widget playerWidget = Stack(
            alignment: Alignment.center,
            children: [
              YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
                progressColors: const ProgressBarColors(playedColor: Colors.red, handleColor: Colors.redAccent),
                bottomActions: const [CurrentPosition(), ProgressBar(isExpanded: true), RemainingDuration(), FullScreenButton()],
              ),
              if (isLandscape) Positioned.fill(child: _buildGestureOverlay()),
              if (_showIndicator && isLandscape)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_indicatorIcon, color: Colors.white, size: 40),
                      const SizedBox(height: 8),
                      Text(_indicatorText, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          );

          return Scaffold(
            backgroundColor: const Color(0xFF0F0F0F),
            body: SafeArea(
              child: isLandscape 
                ? Center(child: playerWidget)
                : Column(
                    children: [
                      playerWidget,
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                          children: [
                            Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const CircleAvatar(radius: 16, backgroundColor: Colors.red, child: Icon(Icons.play_arrow, color: Colors.white, size: 16)),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text("ProTube Channel", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)), Text("Subscribe & Learn", style: TextStyle(color: Colors.grey, fontSize: 11))])),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: const Text("Subscribe", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold))),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildPillButton(icon: Icons.thumb_up_outlined, label: "Like", onTap: () {}), const SizedBox(width: 8),
                                  _buildPillButton(icon: Icons.share_outlined, label: "Share", onTap: _shareVideo), const SizedBox(width: 8),
                                  
                                  // 🌟 सिर्फ 'Save' और 'Saved' बटन 🌟
                                  _buildPillButton(
                                    icon: _isSaved ? Icons.bookmark : Icons.bookmark_add_outlined, 
                                    label: _isSaved ? "Saved" : "Save", 
                                    onTap: _toggleSaveVideo,
                                    iconColor: _isSaved ? Colors.blueAccent : Colors.white,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            GestureDetector(
                              onTap: () { setState(() { _isDescriptionExpanded = !_isDescriptionExpanded; }); },
                              child: Container(
                                width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_isDescriptionExpanded ? "ProTube ऐप में आपका स्वागत है। इस वीडियो में हमने आगामी परीक्षाओं के लिए महत्वपूर्ण विषयों को कवर किया है।\n\nअपनी तैयारी को मजबूत करने के लिए पूरी वीडियो देखें और हमारे चैनल को सपोर्ट करें।" : "ProTube ऐप में आपका स्वागत है। इस वीडियो में...", style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4), maxLines: _isDescriptionExpanded ? 100 : 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 6),
                                    Text(_isDescriptionExpanded ? "Show less" : "...more", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white12, thickness: 1),
                            const SizedBox(height: 10),
                            const Text("Up next", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 14),
                            if (_isLoadingRelated) const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Colors.red)))
                            else if (_relatedVideos.isEmpty) const Center(child: Text("No related videos found", style: TextStyle(color: Colors.grey)))
                            else ..._relatedVideos.map((video) => _buildRealRelatedVideo(video)).toList(),
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

  Widget _buildPillButton({required IconData icon, required String label, required VoidCallback onTap, Color iconColor = Colors.white}) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(icon, color: iconColor, size: 18), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))])));
  }

  Widget _buildRealRelatedVideo(Map<String, dynamic> video) {
    return GestureDetector(
      onTap: () { Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => VideoPlayerScreen(videoId: video['id'], title: video['title']))); },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(video['thumbnail'], width: 140, height: 80, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 140, height: 80, color: Colors.grey[800]))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(video['title'], style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Text("${video['channel']} • ${_formatDate(video['date'])}", style: const TextStyle(color: Colors.grey, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis)])),
          ],
        ),
      ),
    );
  }
}
