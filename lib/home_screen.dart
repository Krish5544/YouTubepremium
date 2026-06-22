import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'search_delegate.dart';
import 'video_player_screen.dart';
import 'channel_screen.dart';
import 'playlist_screen.dart';
import 'music_player_screen.dart'; // 🌟 जादुई लिंक: नया MP3 प्लेयर इम्पोर्ट कर लिया!

class YouTubeHomeScreen extends StatefulWidget {
  const YouTubeHomeScreen({super.key});

  @override
  State<YouTubeHomeScreen> createState() => _YouTubeHomeScreenState();
}

class _YouTubeHomeScreenState extends State<YouTubeHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  int _selectedIndex = 0;
  final String apiKey = 'AIzaSyBpPAohs_WhlCTiozmCVMEzrGsRE86LgpU';
  
  List<Map<String, dynamic>> searchResults = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  String? nextPageToken;
  String currentQuery = "UPSSSC Lower PCS classes";
  
  List<Map<String, dynamic>> _historyData = [];
  List<Map<String, dynamic>> _watchLaterData = [];
  
  List<Map<String, dynamic>> _subscriptionsData = [];
  List<Map<String, dynamic>> _subscribedChannelsDetails = []; 
  bool _isLoadingSubscriptions = false;
  bool _isLoadingMoreSubs = false;
  Map<String, String> _subPageTokens = {}; 
  bool _hasMoreSubs = true;

  // 🌟 Pro Music के लिए डेटा 🌟
  List<Map<String, dynamic>> _musicData = [];
  bool _isLoadingMusic = false;

  final MethodChannel _platform = const MethodChannel('com.protube_app/voice');

  bool isDarkMode = true; 

  // 🌟 जादुई वेरिएबल: क्या हम म्यूजिक मोड में हैं? 🌟
  bool isMusicMode = false; 

  Color get bgColor => isDarkMode ? const Color(0xFF0F0F0F) : Colors.white;
  Color get textColor => isDarkMode ? Colors.white : Colors.black;
  Color get subTextColor => isDarkMode ? Colors.grey : Colors.grey[700]!;
  Color get searchBgColor => isDarkMode ? Colors.white10 : Colors.grey[200]!;
  Color get iconColor => isDarkMode ? Colors.white : Colors.black;

  @override
  void initState() {
    super.initState();
    _loadTheme(); 
    _loadResults(currentQuery, isRefresh: true);
    _loadHistory(); 
    _loadWatchLater(); 
    _loadSubscriptions(isRefresh: true); 
    _loadMusic(); // ऐप खुलते ही बैकग्राउंड में म्यूजिक लोड हो जाएगा
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        isDarkMode = prefs.getBool('isDarkMode') ?? true;
      });
    }
  }

  Future<void> _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = value;
      prefs.setBool('isDarkMode', value);
    });
  }

  void _startVoiceSearch() async {
    try {
      final String result = await _platform.invokeMethod('startVoiceSearch');
      if (result.isNotEmpty) {
        setState(() { currentQuery = result; });
        _loadResults(currentQuery, isRefresh: true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Voice search unavailable.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
    }
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

  // 🌟 Pro Music डेटा लाने का सिस्टम 🌟
  Future<void> _loadMusic() async {
    if (mounted) setState(() => _isLoadingMusic = true);
    try {
      String url = 'https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=20&q=latest+trending+songs&type=video&videoCategoryId=10&key=$apiKey';
      var res = await http.get(Uri.parse(url));
      var data = jsonDecode(res.body);
      List items = data['items'] ?? [];
      
      List<Map<String, dynamic>> newMusic = [];
      for (var item in items) {
         if(item['id']['videoId'] != null) {
           newMusic.add({
             'id': item['id']['videoId'],
             'title': item['snippet']['title'],
             'thumbnail': item['snippet']['thumbnails']['high']?['url'] ?? '',
             'channel': item['snippet']['channelTitle'],
           });
         }
      }
      if (mounted) setState(() { _musicData = newMusic; _isLoadingMusic = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingMusic = false);
    }
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

  Future<void> _loadSubscriptions({bool isRefresh = false}) async {
    if (isRefresh) {
      _subPageTokens.clear(); 
      if (mounted) setState(() { _isLoadingSubscriptions = true; _subscriptionsData.clear(); _subscribedChannelsDetails.clear(); _hasMoreSubs = true; });
    } else {
      if (_isLoadingMoreSubs || !_hasMoreSubs) return;
      if (mounted) setState(() => _isLoadingMoreSubs = true);
    }
    
    final prefs = await SharedPreferences.getInstance();
    List<String> subChannels = prefs.getStringList('subscribed_channels') ?? [];

    if (subChannels.isEmpty) {
      if (mounted) setState(() { _isLoadingSubscriptions = false; _isLoadingMoreSubs = false; _hasMoreSubs = false; });
      return;
    }

    try {
      var topChannels = subChannels.take(10).toList(); 

      if (isRefresh) {
        var channelRes = await http.get(Uri.parse('https://www.googleapis.com/youtube/v3/channels?part=snippet&id=${topChannels.join(',')}&key=$apiKey'));
        if (channelRes.statusCode == 200) {
          var chData = jsonDecode(channelRes.body)['items'] ?? [];
          for (var ch in chData) {
            _subscribedChannelsDetails.add({
              'id': ch['id'], 'title': ch['snippet']['title'], 'thumbnail': ch['snippet']['thumbnails']['default']?['url'] ?? ''
            });
          }
        }
      }

      List<Map<String, dynamic>> newVideos = [];
      bool anyChannelHasMore = false;
      
      for (String cId in topChannels) {
        String? token = _subPageTokens[cId];
        if (token == 'END') continue; 

        String url = 'https://www.googleapis.com/youtube/v3/search?part=snippet&channelId=$cId&maxResults=50&order=date&type=video&key=$apiKey';
        if (token != null && token.isNotEmpty) {
          url += '&pageToken=$token';
        }

        var res = await http.get(Uri.parse(url));
        if (res.statusCode == 200) {
          var data = jsonDecode(res.body);
          String? nextToken = data['nextPageToken'];
          _subPageTokens[cId] = nextToken ?? 'END'; 
          if (nextToken != null) anyChannelHasMore = true;

          List items = data['items'] ?? [];
          for (var item in items) {
            newVideos.add({
              'type': 'video', 'id': item['id']['videoId'], 'title': item['snippet']['title'],
              'thumbnail': item['snippet']['thumbnails']['high']?['url'] ?? '', 'author': item['snippet']['channelTitle'],
              'channelId': item['snippet']['channelId'], 'date': item['snippet']['publishedAt'],
              'durationStr': '', 'views': '0', 'channelLogo': ''
            });
          }
        }
      }

      if (newVideos.isNotEmpty) {
        List<String> videoIds = newVideos.map((v) => v['id'].toString()).toList();
        for (int i = 0; i < videoIds.length; i += 50) {
          var chunk = videoIds.skip(i).take(50).toList();
          var detailsRes = await http.get(Uri.parse('https://www.googleapis.com/youtube/v3/videos?part=contentDetails,statistics&id=${chunk.join(',')}&key=$apiKey'));
          if (detailsRes.statusCode == 200) {
             var vDetails = jsonDecode(detailsRes.body)['items'] ?? [];
             Map<String, dynamic> detailMap = { for (var v in vDetails) v['id']: v };
             for(var v in newVideos) {
                var d = detailMap[v['id']];
                if (d != null) {
                   v['durationStr'] = _formatDuration(_parseDuration(d['contentDetails']['duration']));
                   v['views'] = d['statistics']['viewCount'] ?? '0';
                }
             }
          }
        }
      }

      newVideos.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
      _subscriptionsData.addAll(newVideos); 
      
      if (!anyChannelHasMore) {
         _hasMoreSubs = false;
      }

      if (mounted) setState(() { _isLoadingSubscriptions = false; _isLoadingMoreSubs = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoadingSubscriptions = false; _isLoadingMoreSubs = false; });
    }
  }

  int _parseDuration(String isoDuration) {
    RegExp reg = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    var match = reg.firstMatch(isoDuration);
    int h = int.parse(match?.group(1) ?? '0'); int m = int.parse(match?.group(2) ?? '0'); int s = int.parse(match?.group(3) ?? '0');
    return h * 3600 + m * 60 + s;
  }

  String _formatDuration(int totalSeconds) {
    int h = totalSeconds ~/ 3600;
    int m = (totalSeconds % 3600) ~/ 60; int s = totalSeconds % 60;
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}' : '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatExactDate(String dateStr) {
    try {
      DateTime date = DateTime.parse(dateStr).toLocal();
      List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      int h = date.hour;
      String ampm = h >= 12 ? 'PM' : 'AM'; if (h == 0) h = 12;
      if (h > 12) h -= 12;
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
    return PopScope(
      canPop: false, 
      onPopInvoked: (didPop) {
        if (didPop) return;
        
        if (isMusicMode) { 
          setState(() { isMusicMode = false; }); 
        } 
        else if (_selectedIndex != 0) { 
          setState(() { _selectedIndex = 0; }); 
        } 
        else if (currentQuery != "UPSSSC Lower PCS classes") { 
          _loadResults("UPSSSC Lower PCS classes", isRefresh: true); 
        } 
        else {
          SystemNavigator.pop(); 
        }
      },
      child: Scaffold(
        key: _scaffoldKey, 
        backgroundColor: bgColor, 
        
        endDrawer: Drawer(
          backgroundColor: bgColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 60, bottom: 30, left: 20, right: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDarkMode ? [Colors.red[900]!, Colors.black] : [Colors.red[400]!, Colors.red[100]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      child: Text("K", style: TextStyle(fontSize: 30, color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 15),
                    Text("ProTube", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text("Made by Krishna Saini", style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54, fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              
              ListTile(
                leading: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode, color: iconColor),
                title: Text("Dark Theme", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
                trailing: Switch(
                  value: isDarkMode,
                  onChanged: _toggleTheme,
                  activeColor: Colors.red,
                ),
              ),
              
              const Divider(color: Colors.grey, height: 1, thickness: 0.2),

              ListTile(
                leading: Icon(Icons.settings_outlined, color: iconColor),
                title: Text("Settings", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              
              const Spacer(),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Text("Version 1.0.0", style: TextStyle(color: subTextColor, fontSize: 12)),
                ),
              )
            ],
          ),
        ),

        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          titleSpacing: 12.0,
          title: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    isMusicMode = !isMusicMode;
                  });
                },
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                    children: isMusicMode
                    ? [
                        TextSpan(text: 'Pro', style: TextStyle(color: textColor)), 
                        const TextSpan(text: 'Music', style: TextStyle(color: Colors.greenAccent)), 
                      ]
                    : [
                        TextSpan(text: 'Pro', style: TextStyle(color: textColor)), 
                        const TextSpan(text: 'Tube', style: TextStyle(color: Colors.red)), 
                      ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              Expanded(
                child: GestureDetector(
                  onTap: () => showSearch(context: context, delegate: VideoSearchDelegate((q) => _loadResults(q, isRefresh: true))),
                  child: Container(
                    height: 42, 
                    padding: const EdgeInsets.only(left: 12, right: 6),
                    decoration: BoxDecoration(
                      color: searchBgColor, 
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.grey, size: 18),
                        const SizedBox(width: 8),
                        const Text("Search", style: TextStyle(color: Colors.grey, fontSize: 15)),
                        const Spacer(), 
                        
                        GestureDetector(
                          onTap: _startVoiceSearch,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey[800] : Colors.grey[300], 
                              shape: BoxShape.circle,
                            ),
                            child: ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (Rect bounds) {
                                return const LinearGradient(
                                  colors: [Colors.blue, Colors.redAccent, Colors.yellow, Colors.green],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds);
                              },
                              child: const Icon(Icons.mic, size: 20, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0, left: 8.0),
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    _scaffoldKey.currentState?.openEndDrawer();
                  },
                  child: const CircleAvatar(
                    radius: 14, 
                    backgroundColor: Colors.deepPurple, 
                    child: Text("K", style: TextStyle(fontSize: 14, color: Colors.white))
                  ),
                ),
              ),
            )
          ],
        ),
        
        body: isMusicMode ? _buildMusicScreen() : _buildBody(),
        
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: bgColor, 
          selectedItemColor: isDarkMode ? Colors.white : Colors.black, 
          unselectedItemColor: Colors.grey, 
          currentIndex: _selectedIndex, 
          type: BottomNavigationBarType.fixed, 
          onTap: (i) { 
            setState(() {
              _selectedIndex = i;
              isMusicMode = false; 
            }); 
            if (i == 1 && _subscriptionsData.isEmpty) _loadSubscriptions(isRefresh: true); 
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
    if (_selectedIndex == 0) {
      if (isLoading) return const Center(child: CircularProgressIndicator(color: Colors.red));
      return NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (!isLoadingMore && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent * 0.5) {
            _loadResults(currentQuery); 
          }
          return true;
        },
        child: ListView.builder(
          itemCount: searchResults.length + (nextPageToken != null ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == searchResults.length) return const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator(color: Colors.red)));
            final item = searchResults[index];
            if (item['type'] == 'channel') return ListTile(contentPadding: const EdgeInsets.all(16), leading: CircleAvatar(radius: 30, backgroundImage: NetworkImage(item['thumbnail'])), title: Text(item['title'], style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)), subtitle: const Text("SUBSCRIBE", style: TextStyle(color: Colors.red)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ChannelScreen(channelId: item['id']))));
            if (item['type'] == 'playlist') return ListTile(contentPadding: const EdgeInsets.all(8), leading: Stack(alignment: Alignment.centerRight, children: [Image.network(item['thumbnail'], width: 120, height: 80, fit: BoxFit.cover), Container(width: 40, height: 80, color: Colors.black.withOpacity(0.7), child: const Center(child: Icon(Icons.playlist_play, color: Colors.white)))]), title: Text(item['title'], style: TextStyle(color: textColor, fontSize: 16)), subtitle: Text("Playlist • ${item['channel']}", style: TextStyle(color: subTextColor)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => PlaylistScreen(playlistId: item['id'], playlistTitle: item['title']))));
            return _buildVideoCard(item['id'], item['title'], item['thumbnail'], "${item['author']} • ${_formatViews(item['views'])} views • ${_formatExactDate(item['date'])}", item['durationStr'], false, item['channelId'], item['channelLogo']);
          },
        ),
      );
    } 
    else if (_selectedIndex == 1) {
      if (_isLoadingSubscriptions) return const Center(child: CircularProgressIndicator(color: Colors.red));
      if (_subscriptionsData.isEmpty && _subscribedChannelsDetails.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.subscriptions_outlined, size: 60, color: subTextColor), const SizedBox(height: 10), Text("No subscriptions yet", style: TextStyle(color: subTextColor, fontSize: 16))]));
      return Column(
        children: [
          if (_subscribedChannelsDetails.isNotEmpty)
            Container(
              height: 100, padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDarkMode ? Colors.white12 : Colors.black12, width: 1))),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _subscribedChannelsDetails.length,
                itemBuilder: (context, index) {
                  final ch = _subscribedChannelsDetails[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ChannelScreen(channelId: ch['id']))),
                    child: Container(
                      width: 72, margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        children: [
                          CircleAvatar(radius: 28, backgroundImage: NetworkImage(ch['thumbnail']), backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[300]),
                          const SizedBox(height: 6),
                          Text(ch['title'], style: TextStyle(color: textColor, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (!_isLoadingMoreSubs && _hasMoreSubs && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent * 0.5) {
                  _loadSubscriptions(isRefresh: false); 
                }
                return true;
              },
              child: ListView.builder(
                itemCount: _subscriptionsData.length + (_isLoadingMoreSubs ? 1 : 0), 
                itemBuilder: (context, index) { 
                  if (index == _subscriptionsData.length) return const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator(color: Colors.red)));
                  final data = _subscriptionsData[index]; 
                  return _buildVideoCard(data['id'], data['title'], data['thumbnail'], "${data['author']} • ${_formatViews(data['views'])} views • ${_formatExactDate(data['date'])}", data['durationStr'], false, data['channelId'], "");
                }
              ),
            ),
          ),
        ],
      );
    } 
    else if (_selectedIndex == 2) {
      if (_historyData.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history, size: 60, color: subTextColor), const SizedBox(height: 10), Text("History is empty", style: TextStyle(color: subTextColor, fontSize: 16))]));
      return ListView.builder(itemCount: _historyData.length, itemBuilder: (context, index) { final data = _historyData[index]; return _buildVideoCard(data['id'], data['title'], 'https://img.youtube.com/vi/${data['id']}/hqdefault.jpg', "History", _formatDuration(data['position'] ?? 0), true, data['channelId'] ?? '', data['channelLogo'] ?? ''); });
    } 
    else if (_selectedIndex == 3) {
      if (_watchLaterData.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.watch_later_outlined, size: 60, color: subTextColor), const SizedBox(height: 10), Text("No videos in Watch Later", style: TextStyle(color: subTextColor, fontSize: 16))]));
      return ListView.builder(itemCount: _watchLaterData.length, itemBuilder: (context, index) { final data = _watchLaterData[index]; return _buildVideoCard(data['id'], data['title'], 'https://img.youtube.com/vi/${data['id']}/hqdefault.jpg', "Saved in Watch Later", "", false, "", ""); });
    }
    return Container();
  }

  // 🌟 Music Mode का एकदम प्रीमियम Spotify जैसा UI 🌟
  Widget _buildMusicScreen() {
    if (_isLoadingMusic) return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
    if (_musicData.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.music_off, size: 60, color: subTextColor), const SizedBox(height: 10), Text("No music found", style: TextStyle(color: subTextColor, fontSize: 16))]));
    
    return Container(
      color: isDarkMode ? const Color(0xFF0A0A0A) : Colors.grey[100], 
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: Colors.greenAccent, size: 28),
              const SizedBox(width: 8),
              const Text("Top Tracks For You", style: TextStyle(color: Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: _musicData.length,
            itemBuilder: (context, index) {
              final song = _musicData[index];
              return GestureDetector(
                onTap: () {
                  // 🌟 MAGIC FIX: अब गाना वीडियो प्लेयर में नहीं, सीधे नए MP3 प्लेयर में खुलेगा! 🌟
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => MusicPlayerScreen(
                        videoId: song['id'], 
                        title: song['title'],
                        channel: song['channel'],
                        thumbnail: song['thumbnail'],
                      )
                    )
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(song['thumbnail'], width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[900])),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(song['title'], style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(song['channel'], style: TextStyle(color: subTextColor, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(String videoId, String title, String imageUrl, String subtitleText, String durationText, bool isHistory, String channelId, String channelLogoUrl) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VideoPlayerScreen(videoId: videoId, title: title))).then((_) { 
        if (_selectedIndex == 1) _loadSubscriptions(isRefresh: true);
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
                Image.network(imageUrl, height: 220, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(height: 220, color: isDarkMode ? Colors.grey[900] : Colors.grey[300])), 
                if (durationText.isNotEmpty) 
                  Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), color: Colors.black.withOpacity(0.8), child: Text(durationText, style: const TextStyle(color: Colors.white, fontSize: 12)))
              ]
            ), 
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0), 
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () { if (channelId.isNotEmpty) Navigator.push(context, MaterialPageRoute(builder: (c) => ChannelScreen(channelId: channelId))); }, 
                    child: CircleAvatar(backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[300], backgroundImage: channelLogoUrl.isNotEmpty ? NetworkImage(channelLogoUrl) : null, child: channelLogoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white) : null)
                  ), 
                  const SizedBox(width: 12), 
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Text(title, style: TextStyle(color: textColor, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis), 
                        const SizedBox(height: 4), 
                        Text(isHistory ? "आपने $durationText तक देखा" : subtitleText, style: TextStyle(color: subTextColor, fontSize: 12))
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
