package dev.offlinehome.offline_home

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import java.io.File
import java.util.concurrent.Executors

/**
 * Offline speech fallback for devices without an on-device recogniser (the LineageOS wall
 * tablet). Thin bridge over the official Vosk Android library: the model ships in the APK
 * assets (`vosk-en-in`, see tools/fetch_vosk_model.sh), audio stays on the device.
 *
 * Methods: available() → Bool, start({timeoutMs}) → Bool, stop(), cancel().
 * Events: {"partial": text} | {"final": text} | {"timeout": true} | {"error": message}.
 */
class VoskPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler,
    RecognitionListener {

    private lateinit var ctx: Context
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private var model: Model? = null
    private var service: SpeechService? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ctx = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, "offline_home/vosk")
        methods.setMethodCallHandler(this)
        events = EventChannel(binding.binaryMessenger, "offline_home/vosk/events")
        events.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        shutdown()
        model?.close()
        model = null
        io.shutdown()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
    override fun onCancel(arguments: Any?) { sink = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "available" -> result.success(hasModel())
            "start" -> {
                val timeout = call.argument<Int>("timeoutMs") ?: 8000
                io.execute {
                    val ok = runCatching { startListening(timeout) }
                        .onFailure { emit(mapOf("error" to (it.message ?: it.javaClass.simpleName))) }
                        .getOrDefault(false)
                    main.post { result.success(ok) }
                }
            }
            "stop" -> { service?.stop(); result.success(null) }
            "cancel" -> { shutdown(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    private fun hasModel(): Boolean =
        runCatching { ctx.assets.list(ASSET)?.contains("uuid") == true }.getOrDefault(false)

    /** Copies the model out of the APK once (and again when its uuid changes). */
    private fun modelDir(): File {
        val dest = File(ctx.filesDir, ASSET)
        val want = ctx.assets.open("$ASSET/uuid").bufferedReader().readText().trim()
        val have = File(dest, "uuid").takeIf { it.exists() }?.readText()?.trim()
        if (have != want) {
            dest.deleteRecursively()
            copyAssets(ASSET, dest)
        }
        return dest
    }

    private fun copyAssets(path: String, dest: File) {
        val children = ctx.assets.list(path).orEmpty()
        if (children.isEmpty()) {
            dest.parentFile?.mkdirs()
            ctx.assets.open(path).use { input -> dest.outputStream().use { input.copyTo(it) } }
            return
        }
        dest.mkdirs()
        for (c in children) copyAssets("$path/$c", File(dest, c))
    }

    private fun startListening(timeoutMs: Int): Boolean {
        if (!hasModel()) return false
        shutdown()
        val m = model ?: Model(modelDir().absolutePath).also { model = it }
        val svc = SpeechService(Recognizer(m, SAMPLE_RATE), SAMPLE_RATE)
        service = svc
        return svc.startListening(this, timeoutMs)
    }

    private fun shutdown() {
        service?.let { it.stop(); it.shutdown() }
        service = null
    }

    private fun emit(e: Map<String, Any>) {
        main.post { sink?.success(e) }
    }

    private fun textOf(json: String?, key: String) =
        runCatching { JSONObject(json ?: "{}").optString(key) }.getOrDefault("")

    override fun onPartialResult(hypothesis: String?) {
        emit(mapOf("partial" to textOf(hypothesis, "partial")))
    }

    // End of an utterance (Vosk endpointer).
    override fun onResult(hypothesis: String?) {
        val t = textOf(hypothesis, "text")
        if (t.isNotBlank()) { emit(mapOf("final" to t)); shutdown() }
    }

    override fun onFinalResult(hypothesis: String?) {
        emit(mapOf("final" to textOf(hypothesis, "text")))
        shutdown()
    }

    override fun onError(exception: Exception?) {
        emit(mapOf("error" to (exception?.message ?: "recogniser error")))
        shutdown()
    }

    override fun onTimeout() {
        emit(mapOf("timeout" to true))
        shutdown()
    }

    companion object {
        private const val ASSET = "vosk-en-in"
        private const val SAMPLE_RATE = 16000.0f
    }
}
