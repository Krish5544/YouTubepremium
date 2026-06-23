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
    // 🌟 THE GHOST ENGINE: यह 100% असली गाना प्ले करेगा बिना ब्लॉक हुए 🌟
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: true, // इसके अपने कंट्रोल्स को हमने मार दिया है
        disableDragSeek: true,
        enableCaption: false,
        loop: false,
        isLive: false,
        forceHD: false,
      ),
    )..addListener(_listener);
  }

  // 🌟 यह लिसनर हमारे कस्टम UI को एकदम रियल-टाइम में अपडेट करेगा 🌟
  void _listener() {
    if (_controller.value.isReady && !_isPlayerReady) {
      if (mounted) setState(() => _isPlayerReady = true);
    }
    // स्लाइडर और बटन्स को हर सेकंड अपडेट करने के लिए
    if (mounted) setState(() {}); 
  }

  @override
  void dispose() {
    _controller.removeListener(_listener);
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
      backgroundColor: const Color(0xFF0A0A0A), // Premium Dark Background
      
      body: Stack(
        children: [
          // 🌟 THE 1x1 PIXEL ENGINE (यह किसी को नहीं दिखेगा) 🌟
          Positioned(
            top: 0,
            left: 0,
            width: 1, 
            height: 1,
            child: YoutubePlayer(
              controller: _controller,
            ),
          ),

          // 🌟 तुम्हारा PREMIUM CUSTOM UI (यह सबको दिखेगा) 🌟
          SafeArea(
            child: Column(
              children: [
                // 1. Custom AppBar
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
                          child: Text("Pro Music Premium", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                        ),
                      ),
                      const SizedBox(width: 48), 
                    ],
                  ),
                ),
                
                // 2. Main Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 🌟 Premium Album Art 🌟
                        Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.greenAccent.withOpacity(0.1),
                                blurRadius: 30,
                                spreadRadius: 10,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              widget.thumbnail,
                              height: 320,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(height: 320, color: Colors.grey[900]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 45),
                        
                        // 🌟 Title & Channel 🌟
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.title,
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.channel,
                            style: TextStyle(color: Colors.grey[400], fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 35),

                        // 🌟 Loading or The Player Controls 🌟
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

  // 🌟 THE PERFECT SPOTIFY-LIKE CONTROLS 🌟
  Widget _buildPlayerControls() {
    final position = _controller.value.position;
    final duration = _controller.metadata.duration;
    final isPlaying = _controller.value.isPlaying;

    return Column(
      children: [
        // 🌟 Premium Seekbar (Slider) 🌟
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
            activeTrackColor: Colors.greenAccent, // Spotify Green Feel
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.greenAccent,
            overlayColor: Colors.greenAccent.withOpacity(0.2), // टच करने पर इफ़ेक्ट
          ),
          child: Slider(
            min: 0.0,
            max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0,
            value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0),
            onChanged: (val) {
              // स्लाइडर खींचने पर तुरंत गाना वहीं से बजेगा
              _controller.seekTo(Duration(milliseconds: val.toInt()));
            },
          ),
        ),
        
        // 🌟 Timer Texts 🌟
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(position), style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w500)),
            Text(_formatDuration(duration), style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 15),
        
        // 🌟 Buttons Row 🌟
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ⏪ 10 सेकंड पीछे जाने का बटन
            IconButton(
              icon: const Icon(Icons.replay_10, color: Colors.white, size: 32),
              onPressed: () {
                final newPosition = position - const Duration(seconds: 10);
                _controller.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
              }, 
            ),
            
            // ⏯️ Premium Play/Pause Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(50), // टच करने पर गोल इफ़ेक्ट
                onTap: () {
                  if (isPlaying) {
                    _controller.pause();
                  } else {
                    _controller.play();
                  }
                },
                child: Container(
                  width: 75, 
                  height: 75,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent, 
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow, 
                    color: Colors.black, 
                    size: 45
                  ),
                ),
              ),
            ),
            
            // ⏩ 10 सेकंड आगे जाने का बटन
            IconButton(
              icon: const Icon(Icons.forward_10, color: Colors.white, size: 32),
              onPressed: () {
                final newPosition = position + const Duration(seconds: 10);
                _controller.seekTo(newPosition > duration ? duration : newPosition);
              }, 
            ),
          ],
        ),
      ],
    );
  }
}
