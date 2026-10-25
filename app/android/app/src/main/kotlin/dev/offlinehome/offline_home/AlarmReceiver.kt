package dev.offlinehome.offline_home

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/** Exact alarm fired → run the job in TimerForegroundService (T3.4c). */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AlarmStore.ACTION_FIRE) return
        val jobId = intent.getStringExtra(AlarmStore.EXTRA_JOB) ?: return
        // Exact alarms are an allowed exemption for starting a foreground service from
        // the background (Android 12+).
        val service = Intent(context, TimerForegroundService::class.java)
            .putExtra(AlarmStore.EXTRA_JOB, jobId)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(service)
        } else {
            context.startService(service) // Android 7.1: no background-start limits
        }
    }
}
