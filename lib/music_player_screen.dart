import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'native_player_bridge.dart';

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
  bool _isPlaying = true;
  double _currentPosition = 0; // 🌟 (अभी के लिए डमी टाइमर)
  double _totalDuration = 100;

  @override
  void initState() {
    super.initState();
    // 🌟 THE GHOST ENGINE: नेटिव ऑडियो प्लेयर को बैकग्राउंड में शुरू करना 🌟
    _startNativeAudio();
  }

  Future<void> _startNativeAudio() async {
    await NativePlayerBridge.playVideo(widget.videoId);
  }

  @override
  void dispose() {
    // 🌟 प्लेयर को रोकने का कोड हम नेटिव ब्रिज में जोड़ेंगे
    super.dispose();
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    String mins = duration.inMinutes.toString();
    String secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$mins:$secs";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Premium Dark Background
      
      body: Stack(
        children: [
          // 🌟 THE 1x1 PIXEL ENGINE (यह किसी को नहीं दिखेगा पर गाना बजाएगा) 🌟
          const Positioned(
            top: 0,
            left: 0,
            width: 1, 
            height: 1,
            child: AndroidView(
              viewType: 'native-player-view',
              creationParamsCodec: StandardMessageCodec(),
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

                        // 🌟 Player Controls 🌟
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
    return Column(
      children: [
        // 🌟 Premium Seekbar (Slider) 🌟
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
            activeTrackColor: Colors.greenAccent, 
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.greenAccent,
            overlayColor: Colors.greenAccent.withOpacity(0.2), 
          ),
          child: Slider(
            min: 0.0,
            max: _totalDuration > 0 ? _totalDuration : 1.0,
            value: _currentPosition.clamp(0.0, _totalDuration > 0 ? _totalDuration : 1.0),
            onChanged: (val) {
              setState(() {
                _currentPosition = val;
              });
              // 🌟 यहाँ हम बाद में Native Player को Seek करने का कमांड जोड़ेंगे 🌟
            },
          ),
        ),
        
        // 🌟 Timer Texts 🌟
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(_currentPosition), style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w500)),
            Text(_formatDuration(_totalDuration), style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w500)),
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
              onPressed: () {}, 
            ),
            
            // ⏯️ Premium Play/Pause Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(50), 
                onTap: () {
                  setState(() {
                    _isPlaying = !_isPlaying;
                  });
                  // 🌟 यहाँ हम बाद में Play/Pause का Native कमांड जोड़ेंगे 🌟
                },
                child: Container(
                  width: 75, 
                  height: 75,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent, 
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow, 
                    color: Colors.black, 
                    size: 45
                  ),
                ),
              ),
            ),
            
            // ⏩ 10 सेकंड आगे जाने का बटन
            IconButton(
              icon: const Icon(Icons.forward_10, color: Colors.white, size: 32),
              onPressed: () {}, 
            ),
          ],
        ),
      ],
    );
  }
}
