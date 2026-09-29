package dev.offlinehome.offline_home

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address

/**
 * Keeps all app sockets on the home Wi-Fi even when that Wi-Fi has no internet
 * (PSEUDOCODE §3.2). Android otherwise routes new sockets over mobile data when the Wi-Fi
 * is not "validated", so LAN devices become unreachable exactly when the WAN is down.
 *
 * We request a Wi-Fi network WITHOUT the INTERNET capability requirement and bind the whole
 * process to it: dart:io sockets are created by this process, so they follow the binding.
 * VERIFY on a real phone (T1.4 acceptance).
 *
 * Channels:
 *  - method `offline_home/lan`: init, netInfo, acquireMulticastLock, releaseMulticastLock
 *  - event  `offline_home/lan/events`: NetInfo maps on every change
 */
class LanBindingPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private lateinit var cm: ConnectivityManager
    private lateinit var wifi: WifiManager
    private val main = Handler(Looper.getMainLooper())

    private var sink: EventChannel.EventSink? = null
    private var callback: ConnectivityManager.NetworkCallback? = null
    private var multicastLock: WifiManager.MulticastLock? = null

    // Written on the ConnectivityManager callback thread, read on the main thread.
    @Volatile private var wifiNet: Network? = null
    @Volatile private var internet = false
    @Volatile private var ip: String? = null
    @Volatile private var prefix: Int? = null
    @Volatile private var ssid: String? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val ctx = binding.applicationContext
        cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        wifi = ctx.getSystemService(Context.WIFI_SERVICE) as WifiManager
        methods = MethodChannel(binding.binaryMessenger, "offline_home/lan")
        methods.setMethodCallHandler(this)
        events = EventChannel(binding.binaryMessenger, "offline_home/lan/events")
        events.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        stop()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> { start(); result.success(null) }
            "netInfo" -> result.success(netInfo())
            "acquireMulticastLock" -> { lock().acquire(); result.success(null) }
            "releaseMulticastLock" -> {
                multicastLock?.takeIf { it.isHeld }?.release()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        emit()
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    private fun start() {
        if (callback != null) return
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        val cb = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // FLAG_INCLUDE_LOCATION_INFO lets transportInfo carry the SSID (needs location
            // permission; without it the SSID is simply absent).
            object : ConnectivityManager.NetworkCallback(FLAG_INCLUDE_LOCATION_INFO) {
                override fun onAvailable(network: Network) = onUp(network)
                override fun onLost(network: Network) = onDown(network)
                override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) =
                    onCaps(network, caps)
                override fun onLinkPropertiesChanged(network: Network, lp: LinkProperties) =
                    onLink(network, lp)
            }
        } else {
            object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) = onUp(network)
                override fun onLost(network: Network) = onDown(network)
                override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) =
                    onCaps(network, caps)
                override fun onLinkPropertiesChanged(network: Network, lp: LinkProperties) =
                    onLink(network, lp)
            }
        }
        callback = cb
        cm.requestNetwork(request, cb)
    }

    private fun stop() {
        callback?.let { runCatching { cm.unregisterNetworkCallback(it) } }
        callback = null
        cm.bindProcessToNetwork(null)
        multicastLock?.takeIf { it.isHeld }?.release()
        wifiNet = null
    }

    private fun onUp(network: Network) {
        wifiNet = network
        cm.bindProcessToNetwork(network)
        cm.getLinkProperties(network)?.let { onLink(network, it) }
        cm.getNetworkCapabilities(network)?.let { onCaps(network, it) }
        emit()
    }

    private fun onDown(network: Network) {
        if (network != wifiNet) return
        wifiNet = null
        cm.bindProcessToNetwork(null)
        internet = false
        ip = null
        prefix = null
        ssid = null
        emit()
    }

    private fun onCaps(network: Network, caps: NetworkCapabilities) {
        if (network != wifiNet) return
        internet = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val info = caps.transportInfo as? WifiInfo
            ssid = info?.ssid?.trim('"')?.takeUnless { it.isEmpty() || it == WifiManager.UNKNOWN_SSID }
        }
        emit()
    }

    private fun onLink(network: Network, lp: LinkProperties) {
        if (network != wifiNet) return
        val v4 = lp.linkAddresses.firstOrNull { it.address is Inet4Address }
        ip = v4?.address?.hostAddress
        prefix = v4?.prefixLength
        emit()
    }

    private fun netInfo(): Map<String, Any?> = mapOf(
        "wifi" to (wifiNet != null),
        "internet" to internet,
        "ip" to ip,
        "prefix" to prefix,
        "ssid" to ssid,
    )

    private fun emit() {
        val info = netInfo()
        main.post { sink?.success(info) }
    }

    private fun lock(): WifiManager.MulticastLock =
        multicastLock ?: wifi.createMulticastLock("offline_home").also {
            it.setReferenceCounted(true)
            multicastLock = it
        }
}
