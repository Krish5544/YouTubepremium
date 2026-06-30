package com.example.protube_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.speech.RecognizerIntent
import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.ui.StyledPlayerView
import java.util.Locale

class MainActivity: FlutterActivity() {
    // 🌟 तुम्हारा पुराना वॉयस चैनल
    private val VOICE_CHANNEL = "com.protube_app/voice"
    // 🌟 हमारा नया वीडियो प्लेयर चैनल
    private val PLAYER_CHANNEL = "com.protube.zero/player"
    private var pendingResult: MethodChannel.Result? = null

    // प्लेयर को कंट्रोल करने के लिए ग्लोबल रेफरेंस
    companion object {
        var activePlayer: ExoPlayer? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. ExoPlayer का Native View रजिस्टर करना (ताकि Flutter इसे देख सके)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "native-player-view",
            NativePlayerFactory()
        )

        // 2. तुम्हारा पुराना Voice Search वाला लॉजिक (बिल्कुल सेफ)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startVoiceSearch") {
                pendingResult = result
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
                    putExtra(RecognizerIntent.EXTRA_PROMPT, "Speak to search on ProTube...")
                }
                try {
                    startActivityForResult(intent, 100)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "Voice search not available.", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // 3. हमारा नया Native Player कंट्रोलर (अब असली URL पकड़ेगा!)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLAYER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "playVideo") {
                // 🌟 Flutter (video_player_screen.dart) से भेजा गया असली MP4 लिंक निकालना 🌟
                val url = call.argument<String>("url")
                
                if (activePlayer != null && url != null) {
                    // 🚀 असली YouTube वीडियो स्ट्रीम को ExoPlayer में लोड करना
                    val mediaItem = MediaItem.fromUri(url)
                    activePlayer?.setMediaItem(mediaItem)
                    activePlayer?.prepare()
                    activePlayer?.play()
                    result.success("Playing started natively")
                } else {
                    result.error("ERROR", "Player not ready or URL is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 100) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val results = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                val spokenText = results?.getOrNull(0) ?: ""
                pendingResult?.success(spokenText)
            } else {
                pendingResult?.success("") 
            }
            pendingResult = null
        }
    }
}

// ==========================================
// 🌟 NATIVE PLAYER UI CLASSES (Flutter के लिए) 🌟
// ==========================================

class NativePlayerView(context: Context) : PlatformView {
    private val playerView: StyledPlayerView = StyledPlayerView(context)

    init {
        // प्लेयर बनाना और उसे स्क्रीन (UI) से जोड़ना
        MainActivity.activePlayer = ExoPlayer.Builder(context).build()
        playerView.player = MainActivity.activePlayer
    }

    override fun getView(): View = playerView

    override fun dispose() {
        // मेमोरी लीक से बचने के लिए प्लेयर बंद करना
        MainActivity.activePlayer?.release()
        MainActivity.activePlayer = null
    }
}

class NativePlayerFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return NativePlayerView(context)
    }
}
