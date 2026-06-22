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
    // 🌟 हमारा पावरफुल प्लेयर जो बैकग्राउंड में काम करेगा 🌟
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: true, // यूट्यूब के अपने कंट्रोल्स को छुपा दिया
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

  // टाइमर को सही फॉर्मेट में दिखाने के लिए
  String _formatDuration(Duration duration) {
    String minutes = duration.inMinutes.toString();
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // एकदम Spotify जैसा डार्क बैकग्राउंड
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Pro Music Playing", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 🌟 THE MAGIC (खेड़ा सलूशन): छुपा हुआ वीडियो प्लेयर जो सिर्फ आवाज़ देगा 🌟
          Offstage(
            offstage: true, // यह प्लेयर को स्क्रीन से गायब कर देगा, पर गाना बजता रहेगा!
            child: YoutubePlayer(
              controller: _controller,
              onReady: () {
                setState(() {
                  _isPlayerReady = true; // जैसे ही रेडी होगा, गोल-गोल घूमना बंद!
                });
              },
            ),
          ),

          // 🌟 हमारा प्रीमियम MP3 UI 🌟
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. बड़ा वाला Album Art (थंबनेल)
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
                
                // 2. गाने का टाइटल और चैनल का नाम
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

                // 3. लोडिंग एनीमेशन या प्लेयर के कंट्रोल्स
                if (!_isPlayerReady)
                  const CircularProgressIndicator(color: Colors.greenAccent)
                else
                  _buildPlayerControls(), // यह हमारा नया और फ़ास्ट कंट्रोलर है
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 Play/Pause और सीक बार (Seekbar) का नया और मज़बूत डिज़ाइन 🌟
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
                
                // असली जादुई Play/Pause बटन
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
                    child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 40),
                  ),
                ),
                
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.skip_next, color: Colors.white, size: 36),
                  onPressed: () {}, // बाद में काम आएगा
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
