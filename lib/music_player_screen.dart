import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:http/http.dart' as http;

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

  // 🌟 THE ViMusic ENGINE: Bypassing YouTube Web DRM Completely 🌟
  Future<void> _initAudio() async {
    // ViMusic और RiMusic जैसी Open-Source APIs की लिस्ट (इन पर YouTube का कोई DRM लॉक नहीं होता)
    List<String> apis = [
      'https://pipedapi.kavin.rocks/streams/',
      'https://api.piped.projectsegfau.lt/streams/',
      'https://pipedapi.syncpundit.io/streams/'
    ];

    bool success = false;

    // यह लूप एक-एक करके सर्वर चेक करेगा, गाना मिलते ही प्ले कर देगा
    for (String api in apis) {
      try {
        var response = await http.get(Uri.parse('$api${widget.videoId}')).timeout(const Duration(seconds: 7));
        
        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);
          List audioStreams = data['audioStreams'] ?? [];
          
          String streamUrl = '';
          // Android के लिए MP4 फॉर्मेट सबसे फ़ास्ट और बेस्ट होता है
          for (var stream in audioStreams) {
            if (stream['mimeType'].toString().contains('mp4')) {
              streamUrl = stream['url'];
              break;
            }
          }
          if (streamUrl.isEmpty && audioStreams.isNotEmpty) {
            streamUrl = audioStreams.first['url'];
          }

          if (streamUrl.isNotEmpty) {
            await _audioPlayer.setUrl(streamUrl);
            _audioPlayer.play();
            if (mounted) setState(() => _isLoading = false);
            success = true;
            break; // गाना प्ले हो गया, तो लूप से बाहर आ जाओ!
          }
        }
      } catch (e) {
        continue; // अगर एक सर्वर डाउन हो, तो चुपचाप दूसरे पर चले जाओ
      }
    }

    // अगर दुनिया के सारे Open-Source सर्वर्स डाउन हो जाएँ, तब अपना Explode ज़िंदाबाद!
    if (!success) {
      try {
         var manifest = await _ytExplode.videos.streamsClient.getManifest(widget.videoId);
         var stream = manifest.audioOnly.withHighestBitrate();
         await _audioPlayer.setUrl(stream.url.toString());
         _audioPlayer.play();
         if (mounted) setState(() => _isLoading = false);
      } catch (e) {
         if (mounted) {
           setState(() {
              _isLoading = false;
              _errorMessage = "DRM Error: YouTube ने यह ऑफिशियल गाना ब्लॉक कर दिया है।";
           });
         }
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
