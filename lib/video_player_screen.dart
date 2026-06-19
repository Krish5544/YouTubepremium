import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'channel_screen.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;

  const VideoPlayerScreen({super.key, required this.videoId, required this.title});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late YoutubePlayerController _controller;
  final String apiKey = 'AIzaSyBpPAohs_WhlCTiozmCVMEzrGsRE86LgpU';

  List<Map<String, dynamic>> relatedVideos = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  String? nextPageToken;
  
  bool isSaved = false;
  bool isDarkMode = true;

  Color get bgColor => isDarkMode ? const Color(0xFF0F0F0F) : Colors.white;
  Color get textColor => isDarkMode ? Colors.white : Colors.black;
  Color get subTextColor => isDarkMode ? Colors.grey : Colors.grey[700]!;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _checkIfSaved();
    _saveToHistory();
    
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
      ),
    );

    _loadRelatedVideos(isRefresh: true);
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        isDarkMode = prefs.getBool('isDarkMode') ?? true;
      });
    }
  }

  // 🌟 वॉच लेटर में चेक करने का लॉजिक
  Future<void> _checkIfSaved() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedList = prefs.getStringList('watch_later') ?? [];
    setState(() {
      isSaved = savedList.any((item) => jsonDecode(item)['id'] == widget.videoId);
    });
  }

  // 🌟 वॉच लेटर में सेव/रिमूव करने का लॉजिक
  Future<void> _toggleWatchLater() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedList = prefs.getStringList('watch_later') ?? [];

    if (isSaved) {
      savedList.removeWhere((item) => jsonDecode(item)['id'] == widget.videoId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from Watch Later')));
    } else {
      Map<String, dynamic> videoData = {
        'id': widget.videoId,
        'title': widget.title,
      };
      savedList.add(jsonEncode(videoData));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Watch Later')));
    }

    await prefs.setStringList('watch_later', savedList);
    setState(() {
      isSaved = !isSaved;
    });
  }

  // 🌟 हिस्ट्री में सेव करने का लॉजिक
  Future<void> _saveToHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyList = prefs.getStringList('video_history') ?? [];
    
    historyList.removeWhere((item) => jsonDecode(item)['id'] == widget.videoId);
    
    Map<String, dynamic> historyData = {
      'id': widget.videoId,
      'title': widget.title,
      'position': 0, // position can be updated later via listener if needed
    };
    
    historyList.insert(0, jsonEncode(historyData));
    if (historyList.length > 100) historyList = historyList.sublist(0, 100);
    
    await prefs.setStringList('video_history', historyList);
  }

  // 🌟 अनलिमिटेड रिलेटेड वीडियोज़ लोडिंग (जादुई 50% प्री-लोडिंग के साथ) 🌟
  Future<void> _loadRelatedVideos({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() { isLoading = true; relatedVideos.clear(); nextPageToken = null; });
    } else {
      if (nextPageToken == null || isLoadingMore) return;
      setState(() => isLoadingMore = true);
    }

    try {
      // YouTube ने relatedToVideoId बंद कर दिया है, इसलिए हम वीडियो के टाइटल से सर्च करके एकदम सटीक रिलेटेड वीडियोज़ निकालते हैं
      String query = Uri.encodeComponent(widget.title.split('|').first.split('-').first);
      String url = 'https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=20&q=$query&type=video&key=$apiKey';
      if (nextPageToken != null) url += '&pageToken=$nextPageToken';

      var res = await http.get(Uri.parse(url));
      var data = jsonDecode(res.body);
      nextPageToken = data['nextPageToken'];
      List items = data['items'] ?? [];
      
      if (items.isNotEmpty) {
        List<Map<String, dynamic>> newResults = [];
        List<String> videoIds = items.map((item) => item['id']['videoId'].toString()).toList();
        
        // वीडियो के डिटेल (Duration, Views) निकालने का कोड
        var detailsRes = await http.get(Uri.parse('https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails,statistics&id=${videoIds.join(',')}&key=$apiKey'));
        var vDetails = jsonDecode(detailsRes.body)['items'] ?? [];
        
        // चैनल के लोगो निकालने का कोड
        Set<String> channelIds = vDetails.map<String>((e) => e['snippet']['channelId'].toString()).toSet();
        var channelRes = await http.get(Uri.parse('https://www.googleapis.com/youtube/v3/channels?part=snippet&id=${channelIds.take(50).join(',')}&key=$apiKey'));
        Map<String, String> channelLogos = {};
        if (jsonDecode(channelRes.body)['items'] != null) {
          for (var ch in jsonDecode(channelRes.body)['items']) {
            channelLogos[ch['id']] = ch['snippet']['thumbnails']['default']?['url'] ?? '';
          }
        }

        for (var v in vDetails) {
          // जो वीडियो चल रही है, उसे दोबारा लिस्ट में नहीं दिखाना
          if (v['id'] == widget.videoId) continue; 

          newResults.add({
            'id': v['id'], 'title': v['snippet']['title'], 'thumbnail': v['snippet']['thumbnails']['high']?['url'] ?? '',
            'author': v['snippet']['channelTitle'], 'channelId': v['snippet']['channelId'],
            'channelLogo': channelLogos[v['snippet']['channelId']] ?? '', 'date': v['snippet']['publishedAt'],
            'durationStr': _formatDuration(_parseDuration(v['contentDetails']['duration'])), 'views': v['statistics']['viewCount'] ?? '0'
          });
        }
        if (mounted) setState(() { relatedVideos.addAll(newResults); isLoading = false; isLoadingMore = false; });
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

  String _formatViews(String viewsStr) {
    int views = int.tryParse(viewsStr) ?? 0;
    if (views >= 10000000) return '${(views / 10000000).toStringAsFixed(1)} करोड़';
    if (views >= 100000) return '${(views / 100000).toStringAsFixed(1)} लाख';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
    return views.toString();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // 📺 यूट्यूब प्लेयर
            YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.red,
              progressColors: const ProgressBarColors(
                playedColor: Colors.red,
                handleColor: Colors.redAccent,
              ),
            ),
            
            // 📜 टाइटल और बटन्स
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(Icons.thumb_up_alt_outlined, "Like"),
                      GestureDetector(
                        onTap: () {
                          Share.share('Check out this awesome video on ProTube: https://youtu.be/${widget.videoId}');
                        },
                        child: _buildActionButton(Icons.share, "Share"),
                      ),
                      GestureDetector(
                        onTap: _toggleWatchLater,
                        child: _buildActionButton(isSaved ? Icons.bookmark : Icons.bookmark_border, isSaved ? "Saved" : "Save", color: isSaved ? Colors.red : textColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Divider(color: isDarkMode ? Colors.white24 : Colors.black12, thickness: 1, height: 1),

            // 🌟 अनलिमिटेड रिलेटेड वीडियोज़ की लिस्ट (50% स्क्रॉल लॉजिक के साथ) 🌟
            Expanded(
              child: isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.red))
              : NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (!isLoadingMore && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent * 0.5) {
                      _loadRelatedVideos(); 
                    }
                    return true;
                  },
                  child: ListView.builder(
                    itemCount: relatedVideos.length + (nextPageToken != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == relatedVideos.length) return const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator(color: Colors.red)));
                      
                      final item = relatedVideos[index];
                      return _buildRelatedVideoCard(
                        item['id'], item['title'], item['thumbnail'], 
                        "${item['author']} • ${_formatViews(item['views'])} views", 
                        item['durationStr'], item['channelId'], item['channelLogo']
                      );
                    },
                  ),
                ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? textColor, size: 24),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: color ?? textColor, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildRelatedVideoCard(String videoId, String title, String imageUrl, String subtitleText, String durationText, String channelId, String channelLogoUrl) {
    return GestureDetector(
      onTap: () {
        // जब किसी रिलेटेड वीडियो पर क्लिक करें, तो प्लेयर को उसी वीडियो के साथ अपडेट कर दो
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => VideoPlayerScreen(videoId: videoId, title: title)));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // थंबनेल
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(imageUrl, height: 90, width: 160, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(height: 90, width: 160, color: isDarkMode ? Colors.grey[900] : Colors.grey[300])),
                ),
                if (durationText.isNotEmpty) 
                  Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(4)), child: Text(durationText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(width: 12),
            // टाइटल और डिटेल्स
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(subtitleText, style: TextStyle(color: subTextColor, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
