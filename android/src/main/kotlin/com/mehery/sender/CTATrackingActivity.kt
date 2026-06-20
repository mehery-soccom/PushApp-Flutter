package com.mehery.sender

import android.app.Activity
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log

class CTATrackingActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val clickToken = intent.getStringExtra("click_token")
        val ctaId = intent.getStringExtra("cta_id")
        val ctaUrl = intent.getStringExtra("cta_url")
        val notificationId = intent.getIntExtra("notification_id", -1)

        Log.d("CTATrackingActivity", "CTA Tracking Activity started: $ctaId, $ctaUrl")

        val trackEvent = intent.getStringExtra(LiveActivityMessagingService.EXTRA_TRACK_EVENT)
        val eventType = when (trackEvent) {
            LiveActivityMessagingService.TRACK_EVENT_CTA -> "cta"
            else -> "opened"
        }
        val ctaIdForTrack = if (eventType == "cta") ctaId else null

        if (!clickToken.isNullOrEmpty()) {
            MeherySenderNativeBridge.emitNotificationTrackEvent(
                this,
                clickToken,
                eventType,
                ctaIdForTrack,
            )
        }

        if (!ctaUrl.isNullOrBlank()) {
            try {
                startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse(ctaUrl)).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    },
                )
            } catch (e: Exception) {
                Log.e("CTATrackingActivity", "Failed to open URL: $ctaUrl", e)
            }
        } else {
            val launch = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                )
            }
            if (launch != null) {
                startActivity(launch)
            } else {
                Log.e("CTATrackingActivity", "getLaunchIntentForPackage returned null")
            }
        }

        val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (notificationId != -1) notificationManager.cancel(notificationId)

        finish()
    }
}
