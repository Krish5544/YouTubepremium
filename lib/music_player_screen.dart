import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

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
  final AudioPlayer _audioPlayer = AudioPlayer();
  final yt.YoutubeExplode _ytExplode = yt.YoutubeExplode();
  
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  // 🌟 100% PURE EXPLODE AUDIO FETCHER (No Headers, No Tricks) 🌟
  Future<void> _initAudio() async {
    try {
      // 1. YouTube से गाने का डेटा निकालो
      var manifest = await _ytExplode.videos.streamsClient.getManifest(widget.videoId);
      
      // 2. Android के लिए सबसे बेस्ट MP4 ऑडियो ढूंढो
      yt.AudioOnlyStreamInfo audioStream;
      var mp4Streams = manifest.audioOnly.where((a) => a.codec.mimeType.contains('mp4') || a.container.name == 'mp4');
      
      if (mp4Streams.isNotEmpty) {
        audioStream = mp4Streams.first; // सबसे स्टेबल MP4 फॉर्मेट
      } else {
        audioStream = manifest.audioOnly.withHighestBitrate(); // अगर MP4 ना मिले तो बेस्ट क्वालिटी
      }

      // 3. बिना किसी Custom Header के डायरेक्ट URL प्ले करो
      await _audioPlayer.setUrl(audioStream.url.toString());
      
      _audioPlayer.play();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Real Audio Error: $e"); // कंसोल में एरर प्रिंट होगी
      if (mounted) {
        setState(() {
          _isLoading = false;
          // 🌟 MAGIC FIX: अब तुम्हें स्क्रीन पर असली एरर दिखेगी! 🌟
          _errorMessage = "Error: $e"; 
        });
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _ytExplode.close();
    super.dispose();
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return "0:00";
    String minutes = duration.inMinutes.toString();
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Pro Music Premium", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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

            if (_isLoading)
              const CircularProgressIndicator(color: Colors.greenAccent)
            else if (_errorMessage != null)
              // 🌟 असली एरर यहाँ प्रिंट होगी 🌟
              Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center)
            else
              _buildPlayerControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerControls() {
    return Column(
      children: [
        StreamBuilder<Duration>(
          stream: _audioPlayer.positionStream,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final duration = _audioPlayer.duration ?? Duration.zero;
            
            return Column(
              children: [
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
                    onChanged: (value) {
                      _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(position), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(_formatDuration(duration), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36),
              onPressed: () => _audioPlayer.seek(Duration.zero), 
            ),
            const SizedBox(width: 20),
            
            StreamBuilder<PlayerState>(
              stream: _audioPlayer.playerStateStream,
              builder: (context, snapshot) {
                final playerState = snapshot.data;
                final processingState = playerState?.processingState;
                final playing = playerState?.playing;

                if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
                  return Container(
                    margin: const EdgeInsets.all(8.0),
                    width: 64.0,
                    height: 64.0,
                    child: const CircularProgressIndicator(color: Colors.greenAccent),
                  );
                } else if (playing != true) {
                  return GestureDetector(
                    onTap: _audioPlayer.play,
                    child: Container(
                      width: 70, height: 70,
                      decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow, color: Colors.black, size: 40),
                    ),
                  );
                } else if (processingState != ProcessingState.completed) {
                  return GestureDetector(
                    onTap: _audioPlayer.pause,
                    child: Container(
                      width: 70, height: 70,
                      decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.pause, color: Colors.black, size: 40),
                    ),
                  );
                } else {
                  return GestureDetector(
                    onTap: () => _audioPlayer.seek(Duration.zero),
                    child: Container(
                      width: 70, height: 70,
                      decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.replay, color: Colors.black, size: 40),
                    ),
                  );
                }
              },
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
  }
}
