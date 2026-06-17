import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    // 🌟 प्लेयर को एकदम साफ़-सुथरा इनिशियलाइज़ किया है 🌟
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
    );
    _fetchRelated();
  }

  Future<void> _fetchRelated() async {
    try {
      var res = await http.get(Uri.parse('https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=10&q=${widget.title}&type=video&key=$apiKey'));
      var data = jsonDecode(res.body);
      List items = data['items'] ?? [];
      List<Map<String, dynamic>> list = [];
      for (var v in items) {
        list.add({'id': v['id']['videoId'], 'title': v['snippet']['title'], 'thumb': v['snippet']['thumbnails']['high']['url']});
      }
      if (mounted) setState(() { relatedVideos = list; isLoading = false; });
    } catch (e) { if (mounted) setState(() => isLoading = false); }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 🌟 वीडियो प्लेयर 🌟
            YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.red,
            ),
            // 🌟 रिलेटेड वीडियोज़ 🌟
            Expanded(
              child: isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.red))
                : ListView.builder(
                    itemCount: relatedVideos.length,
                    itemBuilder: (c, i) => ListTile(
                      leading: Image.network(relatedVideos[i]['thumb'], width: 100),
                      title: Text(relatedVideos[i]['title'], style: const TextStyle(color: Colors.white)),
                      onTap: () {
                        // नई वीडियो लोड करना
                        _controller.load(relatedVideos[i]['id']);
                      },
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
