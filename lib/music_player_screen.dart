import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class MusicPlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;
  final String channel;
  final String thumbnail;

  const MusicPlayerScreen({
    super.key,
    required this.videoId,
    required this.title,
    required this.channel,
    required this.thumbnail,
  });

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    // 🌟 हमारा पावरफुल प्लेयर जो अब बैकग्राउंड में चलेगा 🌟
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: true, 
        disableDragSeek: true,
        enableCaption: false,
        loop: false,
        isLive: false,
        forceHD: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String minutes = duration.inMinutes.toString();
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🌟 MAGIC FIX: Stack का इस्तेमाल जिससे Icons गायब नहीं होंगे 🌟
      body: Stack(
        children: [
          // 1. सबसे नीचे: असली यूट्यूब प्लेयर (जो अपना काम करेगा)
          Positioned.fill(
            child: YoutubePlayer(
              controller: _controller,
              onReady: () {
                setState(() {
                  _isPlayerReady = true; 
                });
              },
            ),
          ),

          // 2. बीच में: एक ठोस (Solid) डार्क बैकग्राउंड जो प्लेयर को पूरी तरह छुपा लेगा
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0A0A0A),
            ),
          ),

          // 3. सबसे ऊपर: हमारा असली Premium MP3 UI (अब सारे Icons दिखेंगे!)
          SafeArea(
            child: Column(
              children: [
                // 🌟 कस्टम AppBar 🌟
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text("Pro Music Playing", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 48), // टाइटल को सेंटर में रखने के लिए
                    ],
                  ),
                ),
                
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 🌟 बड़ा वाला Album Art (थंबनेल)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            widget.thumbnail,
                            height: 320,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(height: 320, color: Colors.grey[900]),
                          ),
                        ),
                        const SizedBox(height: 40),
                        
                        // 🌟 गाने का टाइटल और चैनल का नाम
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.title,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.channel,
                            style: const TextStyle(color: Colors.grey, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // 🌟 लोडिंग एनीमेशन या प्लेयर के कंट्रोल्स
                        if (!_isPlayerReady)
                          const CircularProgressIndicator(color: Colors.greenAccent)
                        else
                          _buildPlayerControls(), 
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 Play/Pause और सीक बार (Seekbar) का डिज़ाइन 🌟
  Widget _buildPlayerControls() {
    return ValueListenableBuilder<YoutubePlayerValue>(
      valueListenable: _controller,
      builder: (context, value, child) {
        final position = value.position;
        final duration = _controller.metadata.duration;
        final isPlaying = value.isPlaying;

        return Column(
          children: [
            // सीक बार (Slider)
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.grey[800],
                thumbColor: Colors.white,
              ),
              child: Slider(
                min: 0.0,
                max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0),
                onChanged: (val) {
                  _controller.seekTo(Duration(milliseconds: val.toInt()));
                },
              ),
            ),
            
            // टाइमर टेक्स्ट
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(position), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(_formatDuration(duration), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            
            // Play, Pause, Next, Previous बटन्स
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36),
                  onPressed: () {
                    _controller.seekTo(Duration.zero); // गाना शुरू से चला देगा
                  }, 
                ),
                const SizedBox(width: 20),
                
                // 🌟 असली जादुई Play/Pause बटन 🌟
                GestureDetector(
                  onTap: () {
                    if (isPlaying) {
                      _controller.pause();
                    } else {
                      _controller.play();
                    }
                  },
                  child: Container(
                    width: 70, height: 70,
                    decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow, 
                      color: Colors.black, 
                      size: 40
                    ),
                  ),
                ),
                
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.skip_next, color: Colors.white, size: 36),
                  onPressed: () {}, 
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
