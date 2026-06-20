package com.mehery.sender

import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Routes native notification CTA / open events to Dart via
 * [MesendEventChannel] broadcast and [MeherySenderPlugin.METHOD_CHANNEL] fallback.
 */
object MeherySenderNativeBridge {
    private const val TAG = "MeherySenderNativeBridge"

    const val ACTION_NOTIFICATION_EVENT = "MESEND_NOTIFICATION_EVENT"
    const val EXTRA_TOKEN = "token"
    const val EXTRA_EVENT = "event"
    const val EXTRA_CTA_ID = "ctaId"

    fun emitNotificationTrackEvent(
        context: Context,
        token: String,
        event: String,
        ctaId: String? = null,
    ) {
        emitBroadcast(context, token, event, ctaId)
        invokeDartTrackFallback(context, token, event, ctaId)
    }

    private fun emitBroadcast(
        context: Context,
        token: String,
        event: String,
        ctaId: String?,
    ) {
        try {
            val intent = Intent(ACTION_NOTIFICATION_EVENT).apply {
                setPackage(context.packageName)
                putExtra(EXTRA_TOKEN, token)
                putExtra(EXTRA_EVENT, event)
                if (ctaId != null) {
                    putExtra(EXTRA_CTA_ID, ctaId)
                }
            }
            context.sendBroadcast(intent)
            Log.d(TAG, "Broadcast track event: $event")
        } catch (e: Exception) {
            Log.e(TAG, "Broadcast track event failed: ${e.message}", e)
        }
    }

    private fun invokeDartTrackFallback(
        context: Context,
        token: String,
        event: String,
        ctaId: String?,
    ) {
        try {
            val engine = FlutterEngineCache.getInstance().get(context.packageName)
                ?: FlutterEngineCache.getInstance().get("default")
            engine?.let {
                val args = hashMapOf<String, Any?>(
                    EXTRA_TOKEN to token,
                    EXTRA_EVENT to event,
                )
                if (ctaId != null) {
                    args[EXTRA_CTA_ID] = ctaId
                }
                MethodChannel(
                    it.dartExecutor.binaryMessenger,
                    MeherySenderPlugin.METHOD_CHANNEL,
                ).invokeMethod(MeherySenderPlugin.METHOD_TRACK_NOTIFICATION, args)
                Log.d(TAG, "MethodChannel trackNotification invoked")
            } ?: Log.w(TAG, "Flutter engine not available for trackNotification")
        } catch (e: Exception) {
            Log.w(TAG, "MethodChannel track fallback failed: ${e.message}")
        }
    }
}
