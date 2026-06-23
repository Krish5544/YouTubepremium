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

  // 🌟 THE GOD-LEVEL FIX: ExoPlayer को बायपास करने का लॉजिक 🌟
  Future<void> _initAudio() async {
    try {
      var manifest = await _ytExplode.videos.streamsClient.getManifest(widget.videoId);
      
      var audioStreams = manifest.audioOnly;
      yt.AudioOnlyStreamInfo? audioStream;
      
      try {
        // सबसे स्टेबल MP4 फॉर्मेट ढूँढना
        audioStream = audioStreams.firstWhere((a) => a.codec.mimeType.contains('mp4') || a.codec.mimeType.contains('m4a'));
      } catch (_) {
        audioStream = audioStreams.withHighestBitrate();
      }

      // 🌟 जादू यहाँ है: हम URL सीधा प्लेयर को नहीं दे रहे, बल्कि Custom Proxy Source को दे रहे हैं
      final source = YoutubeAudioSource(audioStream.url.toString());
      
      await _audioPlayer.setAudioSource(source);
      _audioPlayer.play();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
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

// 🌟 THE MASTER PROXY SOURCE (यह YouTube को चकमा देकर सीधा गाना उठाएगा) 🌟
class YoutubeAudioSource extends StreamAudioSource {
  final String url;
  YoutubeAudioSource(this.url);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    
    // एकदम स्टैंडर्ड ब्राउज़र हेडर्स जो ब्लॉक नहीं होते
    final headers = {
      'Range': 'bytes=$start-${end ?? ''}',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };

    var request = http.Request('GET', Uri.parse(url));
    request.headers.addAll(headers);
    
    var response = await http.Client().send(request);

    if (response.statusCode >= 400) {
      throw Exception("YouTube Server Blocked Request: ${response.statusCode}");
    }

    int? sourceLength;
    String? contentRange = response.headers['content-range'];
    if (contentRange != null && contentRange.contains('/')) {
      sourceLength = int.tryParse(contentRange.split('/').last);
    }

    return StreamAudioResponse(
      sourceLength: sourceLength,
      contentLength: response.contentLength,
      offset: start,
      stream: response.stream,
      contentType: response.headers['content-type'] ?? 'audio/mp4',
    );
  }
}
