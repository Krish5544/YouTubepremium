import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'channel_screen.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;

  const VideoPlayerScreen({super.key, required this.videoId, required this.title});

  // 🌟 पूरे ऐप में कहीं से भी वीडियो चलाने का जादुई स्टेटिक फंक्शन 🌟
  static OverlayEntry? _overlayEntry;
  static final ValueNotifier<Map<String, String>?> currentVideo = ValueNotifier<Map<String, String>?>(null);
  static final ValueNotifier<bool> isMinimized = ValueNotifier<bool>(false);

  static void play(BuildContext context, String videoId, String title) {
    currentVideo.value = {'id': videoId, 'title': title};
    isMinimized.value = false;

    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder: (context) => const GlobalVideoPlayerOverlay(),
      );
      Overlay.of(context).insert(_overlayEntry!);
    }
  }

  static void close() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    currentVideo.value = null;
  }

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // इसकी अब सीधे ज़रूरत नहीं है
  }
}

// 🎥 असली ओवरले विजेट जो बैकग्राउंड में हमेशा जिंदा रहेगा
class GlobalVideoPlayerOverlay extends StatefulWidget {
  const GlobalVideoPlayerOverlay({super.key});

  @override
  State<GlobalVideoPlayerOverlay> createState() => _GlobalVideoPlayerOverlayState();
}

class _GlobalVideoPlayerOverlayState extends State<GlobalVideoPlayerOverlay> {
  YoutubePlayerController? _controller;
  String currentVideoId = '';
  String currentTitle = '';
  
  List<Map<String, dynamic>> relatedVideos = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  String? nextPageToken;
  final String apiKey = 'AIzaSyBpPAohs_WhlCTiozmCVMEzrGsRE86LgpU';

  @override
  void initState() {
    super.initState();
    VideoPlayerScreen.currentVideo.addListener(_onVideoChanged);
    _onVideoChanged();
  }

  @override
  void dispose() {
    VideoPlayerScreen.currentVideo.removeListener(_onVideoChanged);
    _controller?.dispose();
    super.dispose();
  }

  // जब भी कोई नई वीडियो क्लिक होगी, ये फंक्शन उसे बिना रुके लोड कर देगा
  void _onVideoChanged() {
    final videoData = VideoPlayerScreen.currentVideo.value;
    if (videoData == null) return;

    String newId = videoData['id'] ?? '';
    String newTitle = videoData['title'] ?? '';

    if (newId != currentVideoId) {
      setState(() {
        currentVideoId = newId;
        currentTitle = newTitle;
        relatedVideos.clear();
        nextPageToken = null;
        isLoading = true;
      });

      if (_controller == null) {
        _controller = YoutubePlayerController(
          initialVideoId: currentVideoId,
          flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
        )..addListener(() {
            if (mounted) setState(() {}); // प्ले-पॉज बटन को अपडेट रखने के लिए
          });
      } else {
        _controller!.load(currentVideoId);
      }
      _loadRelatedVideos();
    }
  }

  Future<void> _loadRelatedVideos() async {
    if (nextPageToken == null && relatedVideos.isNotEmpty) return;
    if (isLoadingMore) return;
    setState(() => isLoadingMore = true);

    try {
      String query = currentTitle.split(' ').take(3).join(' '); 
      String url = 'https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=20&q=$query&type=video&key=$apiKey';
      if (nextPageToken != null) url += '&pageToken=$nextPageToken';

      var res = await http.get(Uri.parse(url));
      var data = jsonDecode(res.body);
      nextPageToken = data['nextPageToken'];
      List items = data['items'] ?? [];

      if (items.isNotEmpty) {
        String vIds = items.map((e) => e['id']['videoId']).join(',');
        var detailsRes = await http.get(Uri.parse('https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails,statistics&id=$vIds&key=$apiKey'));
        var vDetails = jsonDecode(detailsRes.body)['items'] ?? [];

        List<Map<String, dynamic>> newVideos = [];
        for (var v in vDetails) {
          if (v['id'] == currentVideoId) continue; 
          newVideos.add({
            'id': v['id'], 'title': v['snippet']['title'], 'thumbnail': v['snippet']['thumbnails']['high']?['url'] ?? '',
            'author': v['snippet']['channelTitle'], 'channelId': v['snippet']['channelId'], 'date': v['snippet']['publishedAt'],
            'durationStr': _formatDuration(_parseDuration(v['contentDetails']['duration'])), 'views': v['statistics']['viewCount'] ?? '0'
          });
        }
        if (mounted) setState(() { relatedVideos.addAll(newVideos); isLoading = false; isLoadingMore = false; });
      } else { if (mounted) setState(() { isLoading = false; isLoadingMore = false; }); }
    } catch (e) { if (mounted) setState(() { isLoading = false; isLoadingMore = false; }); }
  }

  int _parseDuration(String isoDuration) {
    RegExp reg = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    var match = reg.firstMatch(isoDuration);
    int h = int.parse(match?.group(1) ?? '0'); int m = int.parse(match?.group(2) ?? '0'); int s = int.parse(match?.group(3) ?? '0');
    return h * 3600 + m * 60 + s;
  }

  String _formatDuration(int totalSeconds) {
    int h = totalSeconds ~/ 3600; int m = (totalSeconds % 3600) ~/ 60; int s = totalSeconds % 60;
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}' : '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatExactDate(String dateStr) {
    try {
      DateTime date = DateTime.parse(dateStr).toLocal();
      List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
    } catch(e) { return ''; }
  }

  String _formatViews(String viewsStr) {
    int views = int.tryParse(viewsStr) ?? 0;
    if (views >= 10000000) return '${(views / 10000000).toStringAsFixed(1)} करोड़';
    if (views >= 100000) return '${(views / 100000).toStringAsFixed(1)} लाख';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
    return views.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: VideoPlayerScreen.isMinimized,
      builder: (context, minimized, child) {
        double screenHeight = MediaQuery.of(context).size.height;
        double screenWidth = MediaQuery.of(context).size.width;

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          top: minimized ? screenHeight - 135 : 0, // बॉटम नेविगेशन बार के ठीक ऊपर सेट करने के लिए
          left: 0,
          right: 0,
          bottom: minimized ? 65 : 0, 
          child: Material(
            color: const Color(0xFF0F0F0F),
            elevation: 10,
            child: minimized 
                ? _buildMinimizedLayout(screenWidth)
                : _buildMaximizedLayout(screenWidth),
          ),
        );
      },
    );
  }

  // 📱 1. छोटा मिनीप्लेयर डिजाइन (YouTube जैसा पट्टी वाला लुक)
  Widget _buildMinimizedLayout(double screenWidth) {
    return Container(
      color: const Color(0xFF1F1F1F),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 70,
            child: _controller != null 
                ? YoutubePlayer(controller: _controller!, topActions: const [], bottomActions: const []) 
                : Container(color: Colors.black),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => VideoPlayerScreen.isMinimized.value = false, // टैप करते ही बड़ा हो जाएगा
              child: Text(currentTitle, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          IconButton(
            icon: Icon(_controller?.value.isPlaying == true ? Icons.pause : Icons.play_arrow, color: Colors.white),
            onPressed: () {
              _controller?.value.isPlaying == true ? _controller!.pause() : _controller!.play();
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => VideoPlayerScreen.close(), // प्लेयर बंद करने के लिए
          ),
        ],
      ),
    );
  }

  // 📱 2. बड़ा फुलस्क्रीन प्लेयर डिजाइन (ऊपर पिन वीडियो, नीचे इनफिनिट स्क्रॉल)
  Widget _buildMaximizedLayout(double screenWidth) {
    return SafeArea(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
                onPressed: () => VideoPlayerScreen.isMinimized.value = true, // दबाते ही छोटा हो जाएगा
              ),
              const Spacer(),
            ],
          ),
          SizedBox(
            width: screenWidth,
            height: 220,
            child: _controller != null 
                ? YoutubePlayer(controller: _controller!, showVideoProgressIndicator: true, progressIndicatorColor: Colors.red)
                : const Center(child: CircularProgressIndicator(color: Colors.red)),
          ),
          Expanded(
            child: isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.red))
                : NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification scrollInfo) {
                      if (!isLoadingMore && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                        _loadRelatedVideos();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      itemCount: relatedVideos.length + 1 + (nextPageToken != null ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(currentTitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                const Divider(color: Colors.grey, height: 0.5),
                                const SizedBox(height: 16),
                                const Text("मिलती-जुलती वीडियोज़", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }
                        int videoIndex = index - 1;
                        if (videoIndex == relatedVideos.length) {
                          return const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator(color: Colors.red)));
                        }
                        final video = relatedVideos[videoIndex];
                        return _buildRelatedVideoCard(video);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedVideoCard(Map<String, dynamic> video) {
    return InkWell(
      onTap: () {
        VideoPlayerScreen.currentVideo.value = {'id': video['id'], 'title': video['title']};
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Image.network(video['thumbnail'], width: 150, height: 85, fit: BoxFit.cover),
                Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), color: Colors.black.withOpacity(0.8), child: Text(video['durationStr'], style: const TextStyle(color: Colors.white, fontSize: 10))),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(video['title'], style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(video['author'], style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  Text("${_formatViews(video['views'])} views • ${_formatExactDate(video['date'])}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
