import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'video_player_screen.dart';
import 'playlist_screen.dart';

class ChannelScreen extends StatefulWidget {
  final String channelId;
  const ChannelScreen({super.key, required this.channelId});

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  // 🔑 तुम्हारी YouTube Data API Key
  final String apiKey = 'AIzaSyBpPAohs_WhlCTiozmCVMEzrGsRE86LgpU';

  bool isLoading = true;
  String channelName = '';
  String channelLogo = '';
  String channelBanner = '';
  String channelDesc = '';
  String subsCount = '';
  String _uploadsPlaylistId = '';

  List<Map<String, dynamic>> normalVideos = [];
  List<Map<String, dynamic>> shortVideos = [];
  List<Map<String, dynamic>> playlists = [];

  // 📜 Infinite Scroll के लिए "Next Page Tokens"
  String? _videosNextPageToken;
  String? _playlistsNextPageToken;
  bool _isLoadingMoreVideos = false;
  bool _isLoadingMorePlaylists = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  // 🌐 पहली बार डेटा मंगाना
  Future<void> _fetchInitialData() async {
    try {
      // 1. चैनल की डिटेल
      var chRes = await http.get(Uri.parse('https://www.googleapis.com/youtube/v3/channels?part=snippet,brandingSettings,statistics,contentDetails&id=${widget.channelId}&key=$apiKey'));
      var chData = jsonDecode(chRes.body);
      if (chData['items'] == null || chData['items'].isEmpty) {
        setState(() => isLoading = false);
        return;
      }
      
      var channel = chData['items'][0];
      channelName = channel['snippet']['title'] ?? 'YouTube Channel';
      channelLogo = channel['snippet']['thumbnails']['high']['url'] ?? '';
      channelDesc = channel['snippet']['description'] ?? 'कोई जानकारी नहीं';
      subsCount = channel['statistics']['subscriberCount'] ?? '0';
      if (channel['brandingSettings'] != null && channel['brandingSettings']['image'] != null) {
        channelBanner = channel['brandingSettings']['image']['bannerExternalUrl'] ?? '';
      }
      _uploadsPlaylistId = channel['contentDetails']['relatedPlaylists']['uploads'];

      // 2. Playlists मंगाना
      var plRes = await http.get(Uri.parse('https://www.googleapis.com/youtube/v3/playlists?part=snippet&channelId=${widget.channelId}&maxResults=20&key=$apiKey'));
      var plData = jsonDecode(plRes.body);
      _playlistsNextPageToken = plData['nextPageToken'];
      if (plData['items'] != null) {
        playlists = List<Map<String, dynamic>>.from(plData['items']);
      }

      // 3. वीडियोस मंगाना
      await _fetchVideos(pageToken: '');

      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 📥 वीडियोज़ मंगाने का मेन फंक्शन (यह पहली बार और स्क्रॉल करने पर दोनों टाइम काम आएगा)
  Future<void> _fetchVideos({required String pageToken}) async {
    String url = 'https://www.googleapis.com/youtube/v3/playlistItems?part=snippet,contentDetails&playlistId=$_uploadsPlaylistId&maxResults=50&key=$apiKey';
    if (pageToken.isNotEmpty) url += '&pageToken=$pageToken';

    var vRes = await http.get(Uri.parse(url));
    var vData = jsonDecode(vRes.body);
    _videosNextPageToken = vData['nextPageToken'];
    List items = vData['items'] ?? [];
    
    if (items.isNotEmpty) {
      String vIds = items.map((e) => e['contentDetails']['videoId']).join(',');
      var detailsRes = await http.get(Uri.parse('https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails,statistics&id=$vIds&key=$apiKey'));
      var detailsData = jsonDecode(detailsRes.body);
      List vDetails = detailsData['items'] ?? [];
      
      List<Map<String, dynamic>> newNormals = [];
      List<Map<String, dynamic>> newShorts = [];

      for (var v in vDetails) {
        int seconds = _parseDuration(v['contentDetails']['duration']);
        Map<String, dynamic> videoObj = {
          'id': v['id'],
          'title': v['snippet']['title'],
          'thumbnail': v['snippet']['thumbnails']['high']?['url'] ?? '',
          'author': v['snippet']['channelTitle'],
          'date': v['snippet']['publishedAt'],
          'durationStr': _formatDuration(seconds),
          'views': v['statistics']['viewCount'] ?? '0'
        };
        
        if (seconds <= 60 && seconds > 0) {
          newShorts.add(videoObj);
        } else {
          newNormals.add(videoObj);
        }
      }
      
      if (mounted) {
        setState(() {
          normalVideos.addAll(newNormals);
          shortVideos.addAll(newShorts);
        });
      }
    }
  }

  // 🔄 स्क्रॉल करने पर 'और वीडियोस' लोड करना
  Future<void> _loadMoreVideos() async {
    if (_videosNextPageToken == null || _isLoadingMoreVideos) return;
    setState(() => _isLoadingMoreVideos = true);
    await _fetchVideos(pageToken: _videosNextPageToken!);
    setState(() => _isLoadingMoreVideos = false);
  }

  // 🔄 स्क्रॉल करने पर 'और Playlists' लोड करना
  Future<void> _loadMorePlaylists() async {
    if (_playlistsNextPageToken == null || _isLoadingMorePlaylists) return;
    setState(() => _isLoadingMorePlaylists = true);
    try {
      var plRes = await http.get(Uri.parse('https://www.googleapis.com/youtube/v3/playlists?part=snippet&channelId=${widget.channelId}&maxResults=20&pageToken=$_playlistsNextPageToken&key=$apiKey'));
      var plData = jsonDecode(plRes.body);
      _playlistsNextPageToken = plData['nextPageToken'];
      if (plData['items'] != null) {
        setState(() {
          playlists.addAll(List<Map<String, dynamic>>.from(plData['items']));
        });
      }
    } catch (e) {}
    setState(() => _isLoadingMorePlaylists = false);
  }

  // --- फॉर्मेटिंग टूल्स ---
  int _parseDuration(String isoDuration) {
    int hours = 0; int minutes = 0; int seconds = 0;
    RegExp reg = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    var match = reg.firstMatch(isoDuration);
    if (match != null) {
      if (match.group(1) != null) hours = int.parse(match.group(1)!);
      if (match.group(2) != null) minutes = int.parse(match.group(2)!);
      if (match.group(3) != null) seconds = int.parse(match.group(3)!);
    }
    return hours * 3600 + minutes * 60 + seconds;
  }

  String _formatDuration(int totalSeconds) {
    int h = totalSeconds ~/ 3600;
    int m = (totalSeconds % 3600) ~/ 60;
    int s = totalSeconds % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _timeAgo(String dateStr) {
    DateTime date = DateTime.parse(dateStr);
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()} साल पहले';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} महीने पहले';
    if (diff.inDays > 0) return '${diff.inDays} दिन पहले';
    if (diff.inHours > 0) return '${diff.inHours} घंटे पहले';
    if (diff.inMinutes > 0) return '${diff.inMinutes} मिनट पहले';
    return 'अभी-अभी';
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
    if (isLoading) return const Scaffold(backgroundColor: Color(0xFF0F0F0F), body: Center(child: CircularProgressIndicator(color: Colors.red)));
    if (channelName.isEmpty) return Scaffold(appBar: AppBar(backgroundColor: const Color(0xFF0F0F0F)), backgroundColor: const Color(0xFF0F0F0F), body: const Center(child: Text("चैनल लोड नहीं हो सका", style: TextStyle(color: Colors.white))));

    return DefaultTabController(
      length: 7, 
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 100.0, backgroundColor: const Color(0xFF0F0F0F), pinned: true, iconTheme: const IconThemeData(color: Colors.white),
                flexibleSpace: FlexibleSpaceBar(
                  background: channelBanner.isNotEmpty ? Image.network(channelBanner, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[900])) : Container(color: Colors.grey[900]),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 35, backgroundImage: NetworkImage(channelLogo), backgroundColor: Colors.grey[800]),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(channelName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("@${channelName.replaceAll(' ', '')} • ${_formatViews(subsCount)} सब्सक्राइबर्स", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  const TabBar(
                    isScrollable: true, tabAlignment: TabAlignment.start, indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.grey,
                    tabs: [Tab(text: "Home"), Tab(text: "Videos"), Tab(text: "Shorts"), Tab(text: "Playlists"), Tab(text: "Live"), Tab(text: "Community"), Tab(text: "About")],
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(
            children: [
              _buildVideoList(normalVideos), // Home 
              _buildVideoList(normalVideos), // Videos 
              _buildShortsGrid(shortVideos), // Shorts 
              _buildPlaylists(),             // Playlists
              const Center(child: Text("Live Streams जल्द आ रहे हैं", style: TextStyle(color: Colors.grey))),
              const Center(child: Text("Community Posts जल्द आ रहे हैं", style: TextStyle(color: Colors.grey))),
              _buildAboutTab(),              // About
            ],
          ),
        ),
      ),
    );
  }

  // 📱 वीडियोस की लिस्ट (इसमें Infinite Scroll लगा है)
  Widget _buildVideoList(List<Map<String, dynamic>> vids) {
    if (vids.isEmpty) return const Center(child: Text("कोई वीडियो नहीं मिली", style: TextStyle(color: Colors.grey)));
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        // जैसे ही यूज़र नीचे पहुँचने वाला होगा, नई वीडियो मंगा लेगा
        if (!_isLoadingMoreVideos && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          _loadMoreVideos();
        }
        return false;
      },
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: vids.length + (_videosNextPageToken != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == vids.length) {
            return const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator(color: Colors.red)));
          }
          final video = vids[index];
          return InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VideoPlayerScreen(videoId: video['id'], title: video['title']))),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Image.network(video['thumbnail'], height: 200, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(height: 200, color: Colors.grey[900])),
                      Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), color: Colors.black.withOpacity(0.8), child: Text(video['durationStr'], style: const TextStyle(color: Colors.white, fontSize: 12)))
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(video['title'], style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text("${_formatViews(video['views'])} views • ${_timeAgo(video['date'])}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 📱 Shorts की डिज़ाइन (इसमें भी Infinite Scroll है)
  Widget _buildShortsGrid(List<Map<String, dynamic>> vids) {
    if (vids.isEmpty) return const Center(child: Text("कोई Shorts नहीं मिले", style: TextStyle(color: Colors.grey)));
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!_isLoadingMoreVideos && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          _loadMoreVideos();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.55, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemCount: vids.length + (_videosNextPageToken != null ? 3 : 0), // लोडिंग के लिए जगह
        itemBuilder: (context, index) {
          if (index >= vids.length) return const Center(child: CircularProgressIndicator(color: Colors.red));
          final video = vids[index];
          return InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VideoPlayerScreen(videoId: video['id'], title: video['title']))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(video['thumbnail'], fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[900])),
                  Positioned(bottom: 4, left: 4, child: Text("${_formatViews(video['views'])} views", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 📱 Playlists की डिज़ाइन (अब यह Clickable है)
  Widget _buildPlaylists() {
    if (playlists.isEmpty) return const Center(child: Text("कोई Playlist नहीं मिली", style: TextStyle(color: Colors.grey)));
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!_isLoadingMorePlaylists && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 100) {
          _loadMorePlaylists();
        }
        return false;
      },
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: playlists.length + (_playlistsNextPageToken != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == playlists.length) return const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator(color: Colors.red)));
          final pl = playlists[index];
          return InkWell(
            // 🌟 यहाँ हमने क्लिक करने का फीचर डाल दिया है 🌟
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => PlaylistScreen(playlistId: pl['id'], playlistTitle: pl['snippet']['title']),
              ));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      Container(
                        height: 80, width: 140, color: Colors.grey[900],
                        child: pl['snippet']['thumbnails']['high'] != null ? Image.network(pl['snippet']['thumbnails']['high']['url'], fit: BoxFit.cover) : const Icon(Icons.playlist_play, color: Colors.white),
                      ),
                      Container(
                        width: 50, height: 80, color: Colors.black.withOpacity(0.7),
                        child: const Center(child: Icon(Icons.playlist_play, color: Colors.white, size: 30)),
                      )
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pl['snippet']['title'], style: const TextStyle(color: Colors.white, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        const Text("Playlist", style: TextStyle(color: Colors.grey, fontSize: 12)),
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


  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Description", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(channelDesc, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);
  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: const Color(0xFF0F0F0F), child: _tabBar);
  }
  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
