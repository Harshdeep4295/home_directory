package dev.offlinehome.offline_home

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque

/**
 * Runs phone-tier timer jobs while the app may be closed (T3.4c): starts a headless
 * FlutterEngine on the Dart entry point `timerAlarmMain` (lib/main.dart), which pulls job
 * ids over `offline_home/alarm_runner` ("next" → id or null, "finished" → id, "done").
 * LanBindingPlugin is registered so the job's sockets go over Wi-Fi. Stops itself when
 * Dart says "done" or after [TIMEOUT_MS].
 */
class TimerForegroundService : Service() {
    companion object {
        private const val CHANNEL_ID = "timers"
        private const val NOTIFICATION_ID = 38899
        private const val TIMEOUT_MS = 30_000L
    }

    private val queue = ArrayDeque<String>()
    private val main = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private val timeout = Runnable { finish() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startInForeground()
        intent?.getStringExtra(AlarmStore.EXTRA_JOB)?.let { if (!queue.contains(it)) queue.add(it) }
        if (engine == null) startEngine()
        main.removeCallbacks(timeout)
        main.postDelayed(timeout, TIMEOUT_MS)
        return START_NOT_STICKY
    }

    private fun startInForeground() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Timers", NotificationManager.IMPORTANCE_LOW),
        )
        val n: Notification = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Running a timer")
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // VERIFY best FGS type on Android 14/15 (PLAN §10): dataSync for now.
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
    }

    private fun startEngine() {
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)
        val e = FlutterEngine(applicationContext) // registers pubspec plugins automatically
        e.plugins.add(LanBindingPlugin())
        e.plugins.add(AlarmsPlugin())
        MethodChannel(e.dartExecutor.binaryMessenger, "offline_home/alarm_runner")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "next" -> result.success(queue.pollFirst())
                    "finished" -> {
                        (call.arguments as? String)?.let { AlarmStore.remove(this, it) }
                        result.success(null)
                    }
                    "done" -> {
                        result.success(null)
                        main.post { finish() }
                    }
                    else -> result.notImplemented()
                }
            }
        e.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "timerAlarmMain"),
        )
        engine = e
    }

    private fun finish() {
        main.removeCallbacks(timeout)
        engine?.destroy()
        engine = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        engine?.destroy()
        engine = null
        super.onDestroy()
    }
}
