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
import com.google.android.exoplayer2.upstream.DefaultHttpDataSource
import com.google.android.exoplayer2.source.DefaultMediaSourceFactory
import java.util.Locale

class MainActivity: FlutterActivity() {
    private val VOICE_CHANNEL = "com.protube_app/voice"
    private val PLAYER_CHANNEL = "com.protube.zero/player"
    private var pendingResult: MethodChannel.Result? = null

    companion object {
        var activePlayer: ExoPlayer? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "native-player-view",
            NativePlayerFactory()
        )

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLAYER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "playVideo") {
                val url = call.argument<String>("url")
                
                if (activePlayer != null && url != null) {
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
        // 🌟 THE ULTIMATE BYPASS: Encoder/Encrypted Server Spoofer 🌟
        // यह YouTube को बेवकूफ बनाएगा कि हम असली वेबसाइट से आये हैं
        val dataSourceFactory = DefaultHttpDataSource.Factory()
            .setUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
            .setAllowCrossProtocolRedirects(true)
            .setDefaultRequestProperties(
                mapOf(
                    "Referer" to "https://www.youtube.com/",
                    "Origin" to "https://www.youtube.com/",
                    "Accept" to "*/*"
                )
            )

        // नए बाईपास इंजन के साथ प्लेयर को बनाना
        MainActivity.activePlayer = ExoPlayer.Builder(context)
            .setMediaSourceFactory(DefaultMediaSourceFactory(dataSourceFactory))
            .build()
            
        playerView.player = MainActivity.activePlayer
    }

    override fun getView(): View = playerView

    override fun dispose() {
        MainActivity.activePlayer?.release()
        MainActivity.activePlayer = null
    }
}

class NativePlayerFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return NativePlayerView(context)
    }
}
