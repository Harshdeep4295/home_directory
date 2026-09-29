package dev.offlinehome.offline_home

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build

/**
 * Phone-tier timer alarms (PSEUDOCODE §10, T3.4). Jobs are kept in SharedPreferences
 * (jobId → fire time) so BootReceiver can re-arm them without starting Dart.
 * Only ids and times are stored here; what to do lives in the Dart database.
 */
object AlarmStore {
    const val ACTION_FIRE = "dev.offlinehome.offline_home.ALARM_FIRE"
    const val EXTRA_JOB = "jobId"
    private const val PREFS = "offline_home_alarms"

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun all(ctx: Context): Map<String, Long> =
        prefs(ctx).all.mapNotNull { (k, v) -> (v as? Long)?.let { k to it } }.toMap()

    fun remove(ctx: Context, jobId: String) {
        prefs(ctx).edit().remove(jobId).apply()
    }

    private fun alarms(ctx: Context) = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    /** Exact alarms need user consent on Android 12+ (SCHEDULE_EXACT_ALARM). */
    fun canScheduleExact(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms(ctx).canScheduleExactAlarms()

    fun pendingIntent(ctx: Context, jobId: String): PendingIntent {
        val intent = Intent(ctx, AlarmReceiver::class.java)
            .setAction(ACTION_FIRE)
            // Distinct data URI → distinct PendingIntent per job (Intent.filterEquals).
            .setData(Uri.parse("offlinehome://alarm/$jobId"))
            .putExtra(EXTRA_JOB, jobId)
        return PendingIntent.getBroadcast(
            ctx, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** Returns true if the alarm is exact, false if it had to fall back to inexact. */
    fun schedule(ctx: Context, jobId: String, fireAtMs: Long): Boolean {
        prefs(ctx).edit().putLong(jobId, fireAtMs).apply()
        return arm(ctx, jobId, fireAtMs)
    }

    private fun arm(ctx: Context, jobId: String, fireAtMs: Long): Boolean {
        val pi = pendingIntent(ctx, jobId)
        return if (canScheduleExact(ctx)) {
            alarms(ctx).setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAtMs, pi)
            true
        } else {
            alarms(ctx).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAtMs, pi)
            false
        }
    }

    fun cancel(ctx: Context, jobId: String) {
        alarms(ctx).cancel(pendingIntent(ctx, jobId))
        remove(ctx, jobId)
    }

    /**
     * After reboot / app update: re-arm future jobs. Jobs whose time passed while the phone
     * was off are dropped, not fired late (same rule as TimerService.reconcile).
     */
    fun rearmAll(ctx: Context, nowMs: Long = System.currentTimeMillis()) {
        for ((jobId, at) in all(ctx)) {
            if (at > nowMs) arm(ctx, jobId, at) else remove(ctx, jobId)
        }
    }
}
