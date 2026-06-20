package com.mehery.sender

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.plugin.common.EventChannel

class MesendEventChannel(private val context: Context) : EventChannel.StreamHandler {

    private var eventSink: EventChannel.EventSink? = null
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            if (intent == null) return

            val token = intent.getStringExtra(MeherySenderNativeBridge.EXTRA_TOKEN)
            val event = intent.getStringExtra(MeherySenderNativeBridge.EXTRA_EVENT)
            val ctaId = intent.getStringExtra(MeherySenderNativeBridge.EXTRA_CTA_ID)

            if (token != null && event != null) {
                eventSink?.success(
                    mapOf(
                        MeherySenderNativeBridge.EXTRA_TOKEN to token,
                        MeherySenderNativeBridge.EXTRA_EVENT to event,
                        MeherySenderNativeBridge.EXTRA_CTA_ID to ctaId,
                    ),
                )
            }
        }
    }

    fun register(channel: EventChannel) {
        channel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        val filter = IntentFilter(MeherySenderNativeBridge.ACTION_NOTIFICATION_EVENT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            context.registerReceiver(receiver, filter)
        }
    }

    override fun onCancel(arguments: Any?) {
        try {
            context.unregisterReceiver(receiver)
        } catch (_: IllegalArgumentException) {
            // Receiver was not registered.
        }
        eventSink = null
    }
}
