package dev.offlinehome.offline_home

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Exact alarm fired → run the job in TimerForegroundService (T3.4c). */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AlarmStore.ACTION_FIRE) return
        val jobId = intent.getStringExtra(AlarmStore.EXTRA_JOB) ?: return
        // Exact alarms are an allowed exemption for starting a foreground service from
        // the background (Android 12+).
        context.startForegroundService(
            Intent(context, TimerForegroundService::class.java)
                .putExtra(AlarmStore.EXTRA_JOB, jobId),
        )
    }
}
