package dev.offlinehome.offline_home

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Method channel `offline_home/alarms` (T3.4a):
 *  schedule(jobId, fireAtMs) → bool exact, cancel(jobId), canScheduleExact() → bool,
 *  openExactAlarmSettings().
 */
class AlarmsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var ctx: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ctx = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "offline_home/alarms")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "schedule" -> {
                val jobId = call.argument<String>("jobId")
                val at = call.argument<Number>("fireAtMs")?.toLong()
                if (jobId == null || at == null) {
                    result.error("args", "jobId and fireAtMs required", null)
                } else {
                    result.success(AlarmStore.schedule(ctx, jobId, at))
                }
            }
            "cancel" -> {
                call.argument<String>("jobId")?.let { AlarmStore.cancel(ctx, it) }
                result.success(null)
            }
            "canScheduleExact" -> result.success(AlarmStore.canScheduleExact(ctx))
            "openExactAlarmSettings" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    ctx.startActivity(
                        Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                            .setData(Uri.parse("package:${ctx.packageName}"))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
