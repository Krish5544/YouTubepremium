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

  String? _videosNextPageToken;
  String? _playlistsNextPageToken;
  bool _isLoadingMoreVideos = false;
  bool _isLoadingMorePlaylists = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      var chRes = await http.get(Uri.parse('https://www.googleapis.com/youtube/v3/channels?part=snippet,brandingSettings,statistics,contentDetails&id=${widget.channelId}&key=$apiKey'));
      var chData = jsonDecode(chRes.body);
      if (chData['items'] == null || chData['items'].isEmpty) { setState(() => isLoading = false); return; }

      var channel = chData['items'][0];
      channelName = channel['snippet']['title'] ?? 'YouTube Channel';
      channelLogo = channel['snippet']['thumbnails']['high']?['url'] ?? '';
      channelDesc = channel['snippet']['description'] ?? '';
      subsCount = channel['statistics']['subscriberCount'] ?? '0';
      channelBanner = channel['brandingSettings']?['image']?['bannerExternalUrl'] ?? '';
      _uploadsPlaylistId = channel['contentDetails']['relatedPlaylists']['uploads'];

      var plRes = await http.get(Uri.parse('https://www.googleapis.com/youtube/v3/playlists?part=snippet&channelId=${widget.channelId}&maxResults=20&key=$apiKey'));
      var plData = jsonDecode(plRes.body);
      _playlistsNextPageToken = plData['nextPageToken'];
      playlists = List<Map<String, dynamic>>.from(plData['items'] ?? []);

      await _fetchVideos(pageToken: '');
      if (mounted) setState(() => isLoading = false);
    } catch (e) { if (mounted) setState(() => isLoading = false); }
  }

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
      var vDetails = jsonDecode(detailsRes.body)['items'] ?? [];

      List<Map<String, dynamic>> newNormals = [];
      List<Map<String, dynamic>> newShorts = [];

      for (var v in vDetails) {
        int seconds = _parseDuration(v['contentDetails']['duration']);
        Map<String, dynamic> videoObj = {
          'id': v['id'], 'title': v['snippet']['title'], 'thumbnail': v['snippet']['thumbnails']['high']?['url'] ?? '',
          'date': v['snippet']['publishedAt'], 'durationStr': _formatDuration(seconds), 'views': v['statistics']['viewCount'] ?? '0'
        };
        seconds <= 60 && seconds > 0 ? newShorts.add(videoObj) : newNormals.add(videoObj);
      }
      if (mounted) setState(() { normalVideos.addAll(newNormals); shortVideos.addAll(newShorts); });
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_videosNextPageToken == null || _isLoadingMoreVideos) return;
    setState(() => _isLoadingMoreVideos = true);
    await _fetchVideos(pageToken: _videosNextPageToken!);
    setState(() => _isLoadingMoreVideos = false);
  }

  Future<void> _loadMorePlaylists() async {
    if (_playlistsNextPageToken == null || _isLoadingMorePlaylists) return;
    setState(() => _isLoadingMorePlaylists = true);
    var plRes = await http.get(Uri.parse('https://www.googleapis.com/youtube/v3/playlists?part=snippet&channelId=${widget.channelId}&maxResults=20&pageToken=$_playlistsNextPageToken&key=$apiKey'));
    var plData = jsonDecode(plRes.body);
    _playlistsNextPageToken = plData['nextPageToken'];
    if (plData['items'] != null) setState(() => playlists.addAll(List<Map<String, dynamic>>.from(plData['items'])));
    setState(() => _isLoadingMorePlaylists = false);
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
    if (isLoading) return const Scaffold(backgroundColor: Color(0xFF0F0F0F), body: Center(child: CircularProgressIndicator(color: Colors.red)));
    return DefaultTabController(
      length: 7, 
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: NestedScrollView(
          headerSliverBuilder: (c, i) => [
            SliverAppBar(expandedHeight: 100.0, backgroundColor: const Color(0xFF0F0F0F), pinned: true, iconTheme: const IconThemeData(color: Colors.white), flexibleSpace: FlexibleSpaceBar(background: channelBanner.isNotEmpty ? Image.network(channelBanner, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[900])) : Container(color: Colors.grey[900]))),
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16.0), child: Row(children: [CircleAvatar(radius: 35, backgroundImage: NetworkImage(channelLogo), backgroundColor: Colors.grey[800]), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(channelName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), Text("${_formatViews(subsCount)} सब्सक्राइबर्स", style: const TextStyle(color: Colors.grey))]))]))),
            SliverPersistentHeader(delegate: _SliverAppBarDelegate(const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, indicatorColor: Colors.white, labelColor: Colors.white, unselectedLabelColor: Colors.grey, tabs: [Tab(text: "Home"), Tab(text: "Videos"), Tab(text: "Shorts"), Tab(text: "Playlists"), Tab(text: "Live"), Tab(text: "Community"), Tab(text: "About")])), pinned: true)
          ], 
          body: TabBarView(
            children: [
              _buildVideoList(normalVideos), 
              _buildVideoList(normalVideos), 
              _buildShortsGrid(shortVideos), 
              _buildPlaylists(), 
              const Center(child: Text("Live", style: TextStyle(color: Colors.grey))), 
              const Center(child: Text("Community", style: TextStyle(color: Colors.grey))), 
              _buildAboutTab()
            ]
          )
        )
      )
    );
  }

  Widget _buildVideoList(List<Map<String, dynamic>> vids) {
    return NotificationListener<ScrollNotification>(
      onNotification: (s) { 
        if (!s.metrics.outOfRange && s.metrics.pixels >= s.metrics.maxScrollExtent - 200) _loadMoreVideos(); 
        return false; 
      },
      child: ListView.builder(
        padding: EdgeInsets.zero, 
        itemCount: vids.length + (_videosNextPageToken != null ? 1 : 0), 
        itemBuilder: (c, i) {
          if (i == vids.length) return const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator(color: Colors.red)));
          final v = vids[i];
          return InkWell(
            // 🌟 यहाँ मिनीप्लेयर का एकदम सही कोड है 🌟
            onTap: () => VideoPlayerScreen.play(context, v['id'], v['title']),
            child: Column(
              children: [
                Image.network(v['thumbnail'], width: double.infinity, height: 200, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(height: 200, color: Colors.grey[900])), 
                Padding(padding: const EdgeInsets.all(12), child: Text(v['title'], style: const TextStyle(color: Colors.white), maxLines: 2))
              ]
            )
          );
        }
      )
    );
  }

  Widget _buildShortsGrid(List<Map<String, dynamic>> vids) {
    return GridView.builder(
      padding: const EdgeInsets.all(8), 
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.55, crossAxisSpacing: 8, mainAxisSpacing: 8), 
      itemCount: vids.length, 
      itemBuilder: (c, i) => InkWell(
        // 🌟 शॉर्ट्स के लिए भी मिनीप्लेयर का एकदम सही कोड है 🌟
        onTap: () => VideoPlayerScreen.play(context, vids[i]['id'], vids[i]['title']), 
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(vids[i]['thumbnail'], fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[900])))
      )
    );
  }

  Widget _buildPlaylists() {
    return ListView.builder(
      padding: EdgeInsets.zero, 
      itemCount: playlists.length + (_playlistsNextPageToken != null ? 1 : 0), 
      itemBuilder: (c, i) {
        if (i == playlists.length) return const Center(child: CircularProgressIndicator());
        final pl = playlists[i];
        return ListTile(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => PlaylistScreen(playlistId: pl['id'], playlistTitle: pl['snippet']['title']))),
          leading: Image.network(pl['snippet']['thumbnails']['high']?['url'] ?? '', width: 100, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 100, color: Colors.grey[900])), 
          title: Text(pl['snippet']['title'], style: const TextStyle(color: Colors.white))
        );
      }
    );
  }

  Widget _buildAboutTab() => SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(channelDesc, style: const TextStyle(color: Colors.white))));
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar; 
  _SliverAppBarDelegate(this._tabBar);
  @override double get minExtent => _tabBar.preferredSize.height; 
  @override double get maxExtent => _tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double s, bool o) => Container(color: const Color(0xFF0F0F0F), child: _tabBar);
  @override bool shouldRebuild(_SliverAppBarDelegate d) => false;
}
