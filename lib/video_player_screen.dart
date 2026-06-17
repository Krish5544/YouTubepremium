import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'channel_screen.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;

  const VideoPlayerScreen({super.key, required this.videoId, required this.title});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  final String apiKey = 'AIzaSyBpPAohs_WhlCTiozmCVMEzrGsRE86LgpU';
  late YoutubePlayerController _controller;
  
  List<Map<String, dynamic>> relatedVideos = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  String? nextPageToken;

  @override
  void initState() {
    super.initState();
    // 🎥 प्लेयर को सेट करना
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
      ),
    );
    _loadRelatedVideos();
  }

  // 🌐 मिलती-जुलती वीडियोज़ मंगाना (स्मार्ट जुगाड़)
  Future<void> _loadRelatedVideos() async {
    if (nextPageToken == null && relatedVideos.isNotEmpty) return;
    if (isLoadingMore) return;
    
    setState(() => isLoadingMore = true);

    try {
      // वीडियो के टाइटल से मिलते-जुलते कीवर्ड निकालकर सर्च करना
      String query = widget.title.split(' ').take(3).join(' '); 
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
          // जो वीडियो चल रही है, उसे दोबारा लिस्ट में न दिखाना
          if (v['id'] == widget.videoId) continue; 
          
          newVideos.add({
            'id': v['id'],
            'title': v['snippet']['title'],
            'thumbnail': v['snippet']['thumbnails']['high']?['url'] ?? '',
            'author': v['snippet']['channelTitle'],
            'channelId': v['snippet']['channelId'],
            'date': v['snippet']['publishedAt'],
            'durationStr': _formatDuration(_parseDuration(v['contentDetails']['duration'])),
            'views': v['statistics']['viewCount'] ?? '0'
          });
        }
        if (mounted) setState(() { relatedVideos.addAll(newVideos); isLoading = false; isLoadingMore = false; });
      } else {
        if (mounted) setState(() { isLoading = false; isLoadingMore = false; });
      }
    } catch (e) {
      if (mounted) setState(() { isLoading = false; isLoadingMore = false; });
    }
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
  void deactivate() {
    _controller.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            // 🌟 1. प्लेयर जो हमेशा ऊपर पिन रहेगा (लगभग 35% हिस्सा) 🌟
            YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.red,
              progressColors: const ProgressBarColors(playedColor: Colors.red, handleColor: Colors.redAccent),
            ),
            
            // 🌟 2. नीचे की इनफिनिट स्क्रॉलिंग लिस्ट 🌟
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
                        // पहला आइटम वीडियो का टाइटल होगा
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                const Divider(color: Colors.grey, height: 1),
                                const SizedBox(height: 16),
                                const Text("मिलती-जुलती वीडियोज़", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }
                        
                        int videoIndex = index - 1;
                        // अगर लोडिंग हो रही है
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
      ),
    );
  }

  Widget _buildRelatedVideoCard(Map<String, dynamic> video) {
    return InkWell(
      onTap: () {
        // जैसे ही किसी रिलेटेड वीडियो पर क्लिक करेंगे, प्लेयर अपडेट हो जाएगा!
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(videoId: video['id'], title: video['title']),
        ));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Image.network(video['thumbnail'], width: 160, height: 90, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 160, height: 90, color: Colors.grey[900])),
                Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), color: Colors.black.withOpacity(0.8), child: Text(video['durationStr'], style: const TextStyle(color: Colors.white, fontSize: 10))),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(video['title'], style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(video['author'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  Text("${_formatViews(video['views'])} views • ${_formatExactDate(video['date'])}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
