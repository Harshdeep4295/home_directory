package dev.offlinehome.offline_home

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews

/**
 * Home-screen widget (T5.9): a mic button and up to 4 favourite devices. Taps open the app
 * with `offlinehome://voice` or `offlinehome://toggle/<id>`; the Dart side (home_widget's
 * widgetClicked stream) acts on them, so no second Flutter engine is started here.
 *
 * Data comes from the home_widget plugin's SharedPreferences ("HomeWidgetPreferences"),
 * written by lib/widgets/home_widget_sync.dart: fav{i}_id, fav{i}_name, fav{i}_on.
 */
class OfflineHomeWidget : AppWidgetProvider() {
    companion object {
        /** home_widget HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION */
        const val LAUNCH_ACTION = "es.antonborri.home_widget.action.LAUNCH"
        private const val PREFS = "HomeWidgetPreferences"

        fun launch(context: Context, uri: String): PendingIntent {
            val intent = Intent(context, MainActivity::class.java)
                .setAction(LAUNCH_ACTION)
                .setData(Uri.parse(uri))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            return PendingIntent.getActivity(
                context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private val SLOTS = intArrayOf(R.id.fav0, R.id.fav1, R.id.fav2, R.id.fav3)
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.offline_home_widget)
            views.setOnClickPendingIntent(R.id.widget_mic, launch(context, "offlinehome://voice"))
            for ((i, slot) in SLOTS.withIndex()) {
                val deviceId = prefs.getString("fav${i}_id", null)
                if (deviceId.isNullOrEmpty()) {
                    views.setViewVisibility(slot, View.GONE)
                    continue
                }
                val name = prefs.getString("fav${i}_name", deviceId) ?: deviceId
                val on = prefs.getBoolean("fav${i}_on", false)
                views.setViewVisibility(slot, View.VISIBLE)
                views.setTextViewText(slot, if (on) "● $name" else "○ $name")
                views.setOnClickPendingIntent(
                    slot,
                    launch(context, "offlinehome://toggle/${Uri.encode(deviceId)}"),
                )
            }
            manager.updateAppWidget(id, views)
        }
    }
}
