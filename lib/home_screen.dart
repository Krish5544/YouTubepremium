import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'search_delegate.dart';
import 'video_player_screen.dart';
import 'channel_screen.dart';
import 'playlist_screen.dart';
import 'music_player_screen.dart'; 

class YouTubeHomeScreen extends StatefulWidget {
  const YouTubeHomeScreen({super.key});

  @override
  State<YouTubeHomeScreen> createState() => _YouTubeHomeScreenState();
}

class _YouTubeHomeScreenState extends State<YouTubeHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // 🌟 NAYA ENGINE: Bina API Key ke videos laane ke liye
  final YoutubeExplode _yt = YoutubeExplode();
  
  int _selectedIndex = 0;
  
  List<Map<String, dynamic>> searchResults = [];
  bool isLoading = true;
  String currentQuery = "UPSSSC Lower PCS classes";
  String homeErrorMessage = '';
  
  List<Map<String, dynamic>> _musicData = [];
  bool _isLoadingMusic = false;

  final MethodChannel _platform = const MethodChannel('com.protube_app/voice');

  bool isDarkMode = true;
  bool isMusicMode = false; 

  Color get bgColor => isDarkMode ? const Color(0xFF0F0F0F) : Colors.white;
  Color get textColor => isDarkMode ? Colors.white : Colors.black;
  Color get subTextColor => isDarkMode ? Colors.grey : Colors.grey[700]!;
  Color get searchBgColor => isDarkMode ? Colors.white10 : Colors.grey[200]!;
  Color get iconColor => isDarkMode ? Colors.white : Colors.black;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _loadTheme();
    _loadResults(currentQuery, isRefresh: true);
    _loadMusic(); 
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          isDarkMode = prefs.getBool('isDarkMode') ?? true;
        });
      }
    } catch (e) {
      print("Theme Load Error: $e");
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

  // 🌟 MAGIC FIX: API hata di gayi, ab seedha YoutubeExplode videos layega
  Future<void> _loadResults(String query, {bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() { isLoading = true; searchResults.clear(); currentQuery = query; homeErrorMessage = ''; });
    }
    
    try {
      var searchList = await _yt.search.search(currentQuery);
      List<Map<String, dynamic>> newResults = [];
      
      for (var video in searchList) {
        newResults.add({
          'type': 'video', 
          'id': video.id.value, 
          'title': video.title, 
          'thumbnail': video.thumbnails.highResUrl,
          'author': video.author, 
          'channelId': video.channelId.value,
          'channelLogo': '', 
          'date': video.uploadDate?.toString().substring(0, 10) ?? '',
          'durationStr': _formatDuration(video.duration?.inSeconds ?? 0), 
          'views': video.engagement.viewCount.toString()
        });
      }

      if (mounted) {
        setState(() { 
          searchResults.addAll(newResults); 
          isLoading = false; 
        });
      }
    } catch (e) { 
      if (mounted) setState(() { isLoading = false; homeErrorMessage = "Connection Problem! Please check internet."; });
    }
  }

  Future<void> _loadMusic() async {
    if (mounted) setState(() => _isLoadingMusic = true);
    try {
      var searchList = await _yt.search.search("latest trending hindi songs");
      List<Map<String, dynamic>> newMusic = [];
      for (var video in searchList.take(10)) {
         newMusic.add({
           'id': video.id.value,
           'title': video.title,
           'thumbnail': video.thumbnails.highResUrl,
           'channel': video.author,
         });
      }
      if (mounted) setState(() { _musicData = newMusic; _isLoadingMusic = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingMusic = false);
    }
  }

  String _formatDuration(int totalSeconds) {
    int h = totalSeconds ~/ 3600;
    int m = (totalSeconds % 3600) ~/ 60; 
    int s = totalSeconds % 60;
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}' : '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatViews(String viewsStr) {
    int views = int.tryParse(viewsStr) ?? 0;
    if (views >= 10000000) return '${(views / 10000000).toStringAsFixed(1)} Cr';
    if (views >= 100000) return '${(views / 100000).toStringAsFixed(1)} Lakh';
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
      if (homeErrorMessage.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 70),
                const SizedBox(height: 16),
                Text(homeErrorMessage, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => _loadResults(currentQuery, isRefresh: true),
                  child: const Text("Retry", style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          ),
        );
      }

      return ListView.builder(
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          final item = searchResults[index];
          return _buildVideoCard(item['id'], item['title'], item['thumbnail'], "${item['author']} • ${_formatViews(item['views'])} views • ${item['date']}", item['durationStr']);
        },
      );
    } 
    return Center(child: Text("Coming Soon", style: TextStyle(color: subTextColor)));
  }

  Widget _buildMusicScreen() {
    if (_isLoadingMusic) return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
    if (_musicData.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.music_off, size: 60, color: subTextColor), const SizedBox(height: 10), Text("No music found", style: TextStyle(color: subTextColor, fontSize: 16))]));
    return Container(
      color: isDarkMode ? const Color(0xFF0A0A0A) : Colors.grey[100], 
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Row(
            children: const [
              Icon(Icons.bolt, color: Colors.greenAccent, size: 28),
              SizedBox(width: 8),
              Text("Top Tracks For You", style: TextStyle(color: Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
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

  Widget _buildVideoCard(String videoId, String title, String imageUrl, String subtitleText, String durationText) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VideoPlayerScreen(videoId: videoId, title: title))),
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
                  CircleAvatar(backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[300], child: const Icon(Icons.person, color: Colors.white)), 
                  const SizedBox(width: 12), 
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Text(title, style: TextStyle(color: textColor, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis), 
                        const SizedBox(height: 4), 
                        Text(subtitleText, style: TextStyle(color: subTextColor, fontSize: 12))
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
