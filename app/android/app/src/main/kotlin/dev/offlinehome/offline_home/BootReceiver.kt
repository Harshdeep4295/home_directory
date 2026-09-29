package dev.offlinehome.offline_home

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Re-arms phone-tier timers after reboot or app update (T3.4d). Runs after the first unlock
 * (BOOT_COMPLETED): the SharedPreferences store is credential-encrypted.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> AlarmStore.rearmAll(context)
        }
    }
}
