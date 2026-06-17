import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'video_player_screen.dart';

class PlaylistScreen extends StatefulWidget {
  final String playlistId;
  final String playlistTitle;
  const PlaylistScreen({super.key, required this.playlistId, required this.playlistTitle});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final String apiKey = 'AIzaSyBpPAohs_WhlCTiozmCVMEzrGsRE86LgpU';
  List<Map<String, dynamic>> videos = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPlaylistVideos();
  }

  Future<void> _fetchPlaylistVideos() async {
    try {
      var res = await http.get(Uri.parse('https://www.googleapis.com/youtube/v3/playlistItems?part=snippet,contentDetails&maxResults=50&playlistId=${widget.playlistId}&key=$apiKey'));
      var data = jsonDecode(res.body);
      
      List items = data['items'] ?? [];
      List<Map<String, dynamic>> tempVids = [];
      
      for (var item in items) {
        tempVids.add({
          'id': item['contentDetails']['videoId'],
          'title': item['snippet']['title'],
          'thumbnail': item['snippet']['thumbnails']['high']?['url'] ?? '',
          'author': item['snippet']['videoOwnerChannelTitle'] ?? 'YouTube',
        });
      }
      
      if (mounted) setState(() { videos = tempVids; isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        title: Text(widget.playlistTitle, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : ListView.builder(
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return ListTile(
                  contentPadding: const EdgeInsets.all(8),
                  leading: Image.network(video['thumbnail'], width: 100, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 100, color: Colors.grey[900])),
                  title: Text(video['title'], style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(video['author'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  // 🌟 यहीं पर एरर था जिसे एकदम सही कर दिया गया है 🌟
                  onTap: () => VideoPlayerScreen.play(context, video['id'], video['title']),
                );
              },
            ),
    );
  }
}
