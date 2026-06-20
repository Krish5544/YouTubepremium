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
  
  // 🌟 डिस्क्रिप्शन को छोटा-बड़ा करने वाला लॉजिक 🌟
  bool isDescriptionExpanded = false;

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

  Future<void> _checkIfSaved() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedList = prefs.getStringList('watch_later') ?? [];
    setState(() {
      isSaved = savedList.any((item) => jsonDecode(item)['id'] == widget.videoId);
    });
  }

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

  Future<void> _saveToHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyList = prefs.getStringList('video_history') ?? [];
    
    historyList.removeWhere((item) => jsonDecode(item)['id'] == widget.videoId);
    
    Map<String, dynamic> historyData = {
      'id': widget.videoId,
      'title': widget.title,
      'position': 0, 
    };
    
    historyList.insert(0, jsonEncode(historyData));
    if (historyList.length > 100) historyList = historyList.sublist(0, 100);
    
    await prefs.setStringList('video_history', historyList);
  }

  Future<void> _loadRelatedVideos({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() { isLoading = true; relatedVideos.clear(); nextPageToken = null; });
    } else {
      if (nextPageToken == null || isLoadingMore) return;
      setState(() => isLoadingMore = true);
    }

    try {
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
        
        var detailsRes = await http.get(Uri.parse('https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails,statistics&id=${videoIds.join(',')}&key=$apiKey'));
        var vDetails = jsonDecode(detailsRes.body)['items'] ?? [];
        
        Set<String> channelIds = vDetails.map<String>((e) => e['snippet']['channelId'].toString()).toSet();
        var channelRes = await http.get(Uri.parse('https://www.googleapis.com/youtube/v3/channels?part=snippet&id=${channelIds.take(50).join(',')}&key=$apiKey'));
        Map<String, String> channelLogos = {};
        if (jsonDecode(channelRes.body)['items'] != null) {
          for (var ch in jsonDecode(channelRes.body)['items']) {
            channelLogos[ch['id']] = ch['snippet']['thumbnails']['default']?['url'] ?? '';
          }
        }

        for (var v in vDetails) {
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
            // 📺 यूट्यूब प्लेयर (हमेशा ऊपर रहेगा)
            YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.red,
              progressColors: const ProgressBarColors(
                playedColor: Colors.red,
                handleColor: Colors.redAccent,
              ),
            ),
            
            // 🌟 CustomScrollView: स्क्रॉल करने पर सब कुछ ऊपर छुप जाएगा 🌟
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification scrollInfo) {
                  // 🌟 फ़ास्ट लोडिंग (50% वाला लॉजिक जो तुमने बोला था) 🌟
                  if (!isLoadingMore && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent * 0.5) {
                    _loadRelatedVideos(); 
                  }
                  return true;
                },
                child: CustomScrollView(
                  slivers: [
                    // 📜 वीडियो का ओरिजिनल इंटरफ़ेस (Title, Channel, Buttons, Description)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. टाइटल
                            Text(
                              widget.title,
                              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            
                            // 2. चैनल का नाम और सब्सक्राइब बटन 🌟
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                                  child: Icon(Icons.person, color: isDarkMode ? Colors.white : Colors.black),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("ProTube Channel", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                                      Text("1.2M subscribers", style: TextStyle(color: subTextColor, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDarkMode ? Colors.white : Colors.black,
                                    foregroundColor: isDarkMode ? Colors.black : Colors.white,
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                                  ),
                                  onPressed: () {}, // Subscribe Action
                                  child: const Text("Subscribe", style: TextStyle(fontWeight: FontWeight.bold)),
                                )
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // 3. Like, Share, Watch Later (Download) वाले गोल बटन्स 🌟
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildPillButton(Icons.thumb_up_alt_outlined, "Like", onTap: () {}),
                                  const SizedBox(width: 8),
                                  _buildPillButton(Icons.share, "Share", onTap: () {
                                    Share.share('Check out this video: https://youtu.be/${widget.videoId}');
                                  }),
                                  const SizedBox(width: 8),
                                  _buildPillButton(
                                    isSaved ? Icons.bookmark : Icons.download, 
                                    isSaved ? "Saved" : "Watch Later", 
                                    onTap: _toggleWatchLater,
                                    isActive: isSaved
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 4. ग्रे कलर का डिस्क्रिप्शन बॉक्स (छोटा/बड़ा होने वाला) 🌟
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  isDescriptionExpanded = !isDescriptionExpanded;
                                });
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("64K views  •  2 weeks ago", style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Welcome to this amazing video! Here we discuss the important topics for your exams. Make sure to watch till the end.\n\n#ProTube #Education #Learning #Trending",
                                      maxLines: isDescriptionExpanded ? null : 2,
                                      overflow: isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                                      style: TextStyle(color: textColor, fontSize: 13),
                                    ),
                                    if (!isDescriptionExpanded)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text("...more", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                      )
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Divider(color: isDarkMode ? Colors.white24 : Colors.black12, thickness: 1, height: 1),
                          ],
                        ),
                      ),
                    ),

                    // 🌟 अनलिमिटेड रिलेटेड वीडियोज़ की लिस्ट 🌟
                    if (isLoading && relatedVideos.isEmpty)
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator(color: Colors.red)),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == relatedVideos.length) {
                              return const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator(color: Colors.red)));
                            }
                            final item = relatedVideos[index];
                            return _buildRelatedVideoCard(
                              item['id'], item['title'], item['thumbnail'], 
                              "${item['author']} • ${_formatViews(item['views'])} views", 
                              item['durationStr'], item['channelId'], item['channelLogo']
                            );
                          },
                          childCount: relatedVideos.length + (nextPageToken != null ? 1 : 0),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🌟 गोल (Pill-shaped) बटन्स का डिज़ाइन 🌟
  Widget _buildPillButton(IconData icon, String label, {required VoidCallback onTap, bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? Colors.red : textColor, size: 20),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isActive ? Colors.red : textColor, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedVideoCard(String videoId, String title, String imageUrl, String subtitleText, String durationText, String channelId, String channelLogoUrl) {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => VideoPlayerScreen(videoId: videoId, title: title)));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
