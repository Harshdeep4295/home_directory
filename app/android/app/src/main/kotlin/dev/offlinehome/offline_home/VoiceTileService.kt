package dev.offlinehome.offline_home

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.service.quicksettings.TileService

/** Quick-settings tile that opens the voice sheet directly (T5.9). */
class VoiceTileService : TileService() {
    override fun onClick() {
        super.onClick()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(OfflineHomeWidget.launch(this, "offlinehome://voice"))
        } else {
            val intent = Intent(this, MainActivity::class.java)
                .setAction(OfflineHomeWidget.LAUNCH_ACTION)
                .setData(Uri.parse("offlinehome://voice"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
