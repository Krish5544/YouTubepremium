import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'search_delegate.dart';
import 'video_player_screen.dart';
import 'channel_screen.dart';
import 'playlist_screen.dart';

class YouTubeHomeScreen extends StatefulWidget {
  const YouTubeHomeScreen({super.key});

  @override
  State<YouTubeHomeScreen> createState() => _YouTubeHomeScreenState();
}

class _YouTubeHomeScreenState extends State<YouTubeHomeScreen> {
  int _selectedIndex = 0;
  final String apiKey = 'AIzaSyBpPAohs_WhlCTiozmCVMEzrGsRE86LgpU';
  
  List<Map<String, dynamic>> searchResults = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  String? nextPageToken;
  String currentQuery = "UPSSSC Lower PCS classes";
  
  // हिस्ट्री, वाच लेटर और सब्सक्रिप्शन का डेटा
  List<Map<String, dynamic>> _historyData = [];
  List<Map<String, dynamic>> _watchLaterData = [];
  
  // 🌟 Subscriptions के वेरिएबल्स 🌟
  List<Map<String, dynamic>> _subscriptionsData = [];
  bool _isLoadingSubscriptions = false;

  @override
  void initState() {
    super.initState();
    _loadResults(currentQuery, isRefresh: true);
    _loadHistory(); 
    _loadWatchLater(); 
    _loadSubscriptions(); // 🌟 ऐप खुलते ही सब्सक्रिप्शंस भी लोड होंगे
  }

  Future<void> _loadResults(String query, {bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() { isLoading = true; searchResults.clear(); nextPageToken = null; currentQuery = query; });
    } else {
      if (nextPageToken == null || isLoadingMore) return;
      setState(() => isLoadingMore = true);
    }

    try {
      String url = 'https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=20&q=$currentQuery&key=$apiKey';
      if (nextPageToken != null) url += '&pageToken=$nextPageToken';

      var res = await http.get(Uri.parse(url));
      var data = jsonDecode(res.body);
      nextPageToken = data['nextPageToken'];
      List items = data['items'] ?? [];
      
      if (items.isNotEmpty) {
        List<Map<String, dynamic>> newResults = [];
        List<String> videoIds = [];
        
        for (var item in items) {
          String kind = item['id']['kind'];
          if (kind == 'youtube#channel') {
            newResults.add({'type': 'channel', 'id': item['id']['channelId'], 'title': item['snippet']['channelTitle'], 'thumbnail': item['snippet']['thumbnails']['high']?['url'] ?? ''});
          } else if (kind == 'youtube#playlist') {
            newResults.add({'type': 'playlist', 'id': item['id']['playlistId'], 'title': item['snippet']['title'], 'channel': item['snippet']['channelTitle'], 'thumbnail': item['snippet']['thumbnails']['high']?['url'] ?? ''});
          } else if (kind == 'youtube#video') {
            videoIds.add(item['id']['videoId']);
          }
        }

        if (videoIds.isNotEmpty) {
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
            newResults.add({
              'type': 'video', 'id': v['id'], 'title': v['snippet']['title'], 'thumbnail': v['snippet']['thumbnails']['high']?['url'] ?? '',
              'author': v['snippet']['channelTitle'], 'channelId': v['snippet']['channelId'],
              'channelLogo': channelLogos[v['snippet']['channelId']] ?? '', 'date': v['snippet']['publishedAt'],
              'durationStr': _formatDuration(_parseDuration(v['contentDetails']['duration'])), 'views': v['statistics']['viewCount'] ?? '0'
            });
          }
        }
        if (mounted) setState(() { searchResults.addAll(newResults); isLoading = false; isLoadingMore = false; });
      } else { if (mounted) setState(() { isLoading = false; isLoadingMore = false; }); }
    } catch (e) { if (mounted) setState(() { isLoading = false; isLoadingMore = false; }); }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyList = prefs.getStringList('video_history') ?? [];
    setState(() => _historyData = historyList.map((item) => jsonDecode(item) as Map<String, dynamic>).toList());
  }

  Future<void> _loadWatchLater() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedList = prefs.getStringList('watch_later') ?? [];
    setState(() => _watchLaterData = savedList.map((item) => jsonDecode(item) as Map<String, dynamic>).toList());
  }

  // 🌟 सब्सक्राइब किए गए चैनल्स की वीडियोज़ लोड करने का मास्टर लॉजिक 🌟
  Future<void> _loadSubscriptions() async {
    if (!mounted) return;
    setState(() { _isLoadingSubscriptions = true; _subscriptionsData.clear(); });
    
    final prefs = await SharedPreferences.getInstance();
    List<String> subChannels = prefs.getStringList('subscribed_channels') ?? [];

    if (subChannels.isEmpty) {
      if (mounted) setState(() => _isLoadingSubscriptions = false);
      return;
    }

    try {
      List<Map<String, dynamic>> allVideos = [];
      
      // टॉप 10 चैनल्स की 5-5 लेटेस्ट वीडियोज़ निकालेंगे (ताकि ऐप हैंग न हो)
      for (String cId in subChannels.take(10)) {
        String url = 'https://www.googleapis.com/youtube/v3/search?part=snippet&channelId=$cId&maxResults=5&order=date&type=video&key=$apiKey';
        var res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) {
          var data = jsonDecode(res.body);
          List items = data['items'] ?? [];
          for (var item in items) {
            allVideos.add({
              'type': 'video',
              'id': item['id']['videoId'],
              'title': item['snippet']['title'],
              'thumbnail': item['snippet']['thumbnails']['high']?['url'] ?? '',
              'author': item['snippet']['channelTitle'],
              'channelId': item['snippet']['channelId'],
              'date': item['snippet']['publishedAt'],
              'durationStr': '',
              'views': '0',
            });
          }
        }
      }

      // 🌟 सारी वीडियोज़ को 'ताज़ा डेट और टाइम' के हिसाब से सॉर्ट (क्रमबद्ध) करेंगे 🌟
      allVideos.sort((a, b) {
        DateTime dateA = DateTime.parse(a['date']);
        DateTime dateB = DateTime.parse(b['date']);
        return dateB.compareTo(dateA); // सबसे नई वीडियो सबसे ऊपर
      });

      // अब इन वीडियोज़ के व्यूज़ और ड्यूरेशन निकालेंगे
      if (allVideos.isNotEmpty) {
        List<String> videoIds = allVideos.map((v) => v['id'].toString()).take(50).toList();
        var detailsRes = await http.get(Uri.parse('https://www.googleapis.com/youtube/v3/videos?part=contentDetails,statistics&id=${videoIds.join(',')}&key=$apiKey'));
        if (detailsRes.statusCode == 200) {
           var vDetails = jsonDecode(detailsRes.body)['items'] ?? [];
           Map<String, dynamic> detailMap = { for (var v in vDetails) v['id']: v };
           for(var v in allVideos) {
              var d = detailMap[v['id']];
              if (d != null) {
                 v['durationStr'] = _formatDuration(_parseDuration(d['contentDetails']['duration']));
                 v['views'] = d['statistics']['viewCount'] ?? '0';
              }
           }
        }
      }

      if (mounted) setState(() { _subscriptionsData = allVideos; _isLoadingSubscriptions = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingSubscriptions = false);
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
      int h = date.hour; String ampm = h >= 12 ? 'PM' : 'AM'; if (h == 0) h = 12; if (h > 12) h -= 12;
      return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}, ${h.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $ampm';
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
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          setState(() { _selectedIndex = 0; });
          return false; 
        }
        if (currentQuery != "UPSSSC Lower PCS classes") {
          _loadResults("UPSSSC Lower PCS classes", isRefresh: true);
          return false; 
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F0F0F),
          elevation: 0,
          leadingWidth: 120,
          leading: Padding(padding: const EdgeInsets.only(left: 12.0), child: Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/b/b8/YouTube_Logo_2017.svg/512px-YouTube_Logo_2017.svg.png', fit: BoxFit.contain)),
          actions: [
            Container(margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.search, color: Colors.white, size: 22), onPressed: () => showSearch(context: context, delegate: VideoSearchDelegate((q) => _loadResults(q, isRefresh: true))))),
            const Padding(padding: EdgeInsets.only(right: 12.0, left: 4.0), child: CircleAvatar(radius: 14, backgroundColor: Colors.deepPurple, child: Text("K", style: TextStyle(fontSize: 14, color: Colors.white))))
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: const Color(0xFF0F0F0F), 
          selectedItemColor: Colors.white, 
          unselectedItemColor: Colors.grey, 
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed, 
          onTap: (i) { 
            setState(() => _selectedIndex = i); 
            // 🌟 जब भी जो टैब दबेगा, उसका डेटा रिफ्रेश होगा 🌟
            if (i == 1) _loadSubscriptions(); 
            if (i == 2) _loadHistory(); 
            if (i == 3) _loadWatchLater(); 
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"), 
            BottomNavigationBarItem(icon: Icon(Icons.subscriptions_outlined), label: "Subscriptions"),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"), 
            BottomNavigationBarItem(icon: Icon(Icons.watch_later_outlined), label: "Watch Later"), 
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    // 🏠 टैब 0: Home Screen
    if (_selectedIndex == 0) {
      if (isLoading) return const Center(child: CircularProgressIndicator(color: Colors.red));
      return NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (!isLoadingMore && scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            _loadResults(currentQuery); 
          }
          return true;
        },
        child: ListView.builder(
          itemCount: searchResults.length + (nextPageToken != null ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == searchResults.length) return const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator(color: Colors.red)));
            final item = searchResults[index];
            if (item['type'] == 'channel') return ListTile(contentPadding: const EdgeInsets.all(16), leading: CircleAvatar(radius: 30, backgroundImage: NetworkImage(item['thumbnail'])), title: Text(item['title'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), subtitle: const Text("SUBSCRIBE", style: TextStyle(color: Colors.red)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ChannelScreen(channelId: item['id']))));
            if (item['type'] == 'playlist') return ListTile(contentPadding: const EdgeInsets.all(8), leading: Stack(alignment: Alignment.centerRight, children: [Image.network(item['thumbnail'], width: 120, height: 80, fit: BoxFit.cover), Container(width: 40, height: 80, color: Colors.black.withOpacity(0.7), child: const Center(child: Icon(Icons.playlist_play, color: Colors.white)))]), title: Text(item['title'], style: const TextStyle(color: Colors.white, fontSize: 16)), subtitle: Text("Playlist • ${item['channel']}", style: const TextStyle(color: Colors.grey)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => PlaylistScreen(playlistId: item['id'], playlistTitle: item['title']))));
            return _buildVideoCard(item['id'], item['title'], item['thumbnail'], "${item['author']} • ${_formatViews(item['views'])} views • ${_formatExactDate(item['date'])}", item['durationStr'], false, item['channelId'], item['channelLogo']);
          },
        ),
      );
    } 
    // 📺 टैब 1: Subscriptions (🌟 एकदम नया फीचर 🌟)
    else if (_selectedIndex == 1) {
      if (_isLoadingSubscriptions) return const Center(child: CircularProgressIndicator(color: Colors.red));
      if (_subscriptionsData.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.subscriptions_outlined, size: 60, color: Colors.grey), SizedBox(height: 10), Text("No subscriptions yet", style: TextStyle(color: Colors.grey, fontSize: 16))]));
      
      return ListView.builder(
        itemCount: _subscriptionsData.length, 
        itemBuilder: (context, index) { 
          final data = _subscriptionsData[index]; 
          return _buildVideoCard(data['id'], data['title'], data['thumbnail'], "${data['author']} • ${_formatViews(data['views'])} views • ${_formatExactDate(data['date'])}", data['durationStr'], false, data['channelId'], ""); 
        }
      );
    } 
    // 🕒 टैब 2: History
    else if (_selectedIndex == 2) {
      if (_historyData.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history, size: 60, color: Colors.grey), SizedBox(height: 10), Text("History is empty", style: TextStyle(color: Colors.grey, fontSize: 16))]));
      return ListView.builder(
        itemCount: _historyData.length, 
        itemBuilder: (context, index) { 
          final data = _historyData[index]; 
          return _buildVideoCard(data['id'], data['title'], 'https://img.youtube.com/vi/${data['id']}/hqdefault.jpg', "History", _formatDuration(data['position'] ?? 0), true, data['channelId'] ?? '', data['channelLogo'] ?? ''); 
        }
      );
    } 
    // ⌚ टैब 3: Watch Later 
    else if (_selectedIndex == 3) {
      if (_watchLaterData.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.watch_later_outlined, size: 60, color: Colors.grey), SizedBox(height: 10), Text("No videos in Watch Later", style: TextStyle(color: Colors.grey, fontSize: 16))]));
      return ListView.builder(
        itemCount: _watchLaterData.length, 
        itemBuilder: (context, index) { 
          final data = _watchLaterData[index]; 
          return _buildVideoCard(data['id'], data['title'], 'https://img.youtube.com/vi/${data['id']}/hqdefault.jpg', "Saved in Watch Later", "", false, "", ""); 
        }
      );
    }
    return Container();
  }

  Widget _buildVideoCard(String videoId, String title, String imageUrl, String subtitleText, String durationText, bool isHistory, String channelId, String channelLogoUrl) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VideoPlayerScreen(videoId: videoId, title: title))).then((_) { 
        if (_selectedIndex == 1) _loadSubscriptions();
        if (_selectedIndex == 2) _loadHistory(); 
        if (_selectedIndex == 3) _loadWatchLater();
      }),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15.0), 
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight, 
              children: [
                Image.network(imageUrl, height: 220, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(height: 220, color: Colors.grey[900])), 
                if (durationText.isNotEmpty) 
                  Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), color: Colors.black.withOpacity(0.8), child: Text(durationText, style: const TextStyle(color: Colors.white, fontSize: 12)))
              ]
            ), 
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0), 
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (channelId.isNotEmpty) Navigator.push(context, MaterialPageRoute(builder: (c) => ChannelScreen(channelId: channelId)));
                    }, 
                    child: CircleAvatar(backgroundColor: Colors.grey[800], backgroundImage: channelLogoUrl.isNotEmpty ? NetworkImage(channelLogoUrl) : null, child: channelLogoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white) : null)
                  ), 
                  const SizedBox(width: 12), 
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis), 
                        const SizedBox(height: 4), 
                        Text(isHistory ? "आपने $durationText तक देखा" : subtitleText, style: const TextStyle(color: Colors.grey, fontSize: 12))
                      ]
                    )
                  )
                ]
              )
            )
          ]
        )
      ),
    );
  }
}
