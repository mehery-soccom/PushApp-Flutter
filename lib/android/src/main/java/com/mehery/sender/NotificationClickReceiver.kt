package com.mehery.admin.mehery_admin

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.plugin.common.EventChannel

class MesendEventChannel(private val context: Context) : EventChannel.StreamHandler {

    private var eventSink: EventChannel.EventSink? = null
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            if (intent == null) return

            val token = intent.getStringExtra("token")
            val event = intent.getStringExtra("event")
            val ctaId = intent.getStringExtra("ctaId")

            if (token != null && event != null) {
                val data = mapOf(
                    "token" to token,
                    "event" to event,
                    "ctaId" to ctaId
                )
                eventSink?.success(data)
            }
        }
    }

    fun register(channel: EventChannel) {
        channel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        context.registerReceiver(receiver, IntentFilter("MESEND_NOTIFICATION_EVENT"))
    }

    override fun onCancel(arguments: Any?) {
        context.unregisterReceiver(receiver)
        eventSink = null
    }
}
