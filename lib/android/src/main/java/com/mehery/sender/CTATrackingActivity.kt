package com.mehery.admin.mehery_admin

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

        // Use explicit extra from the PendingIntent — do not infer from cta_id (can be wrong with
        // FLAG_UPDATE_CURRENT / stale notification PendingIntent reuse).
        val trackEvent = intent.getStringExtra(LiveActivityMessagingService.EXTRA_TRACK_EVENT)
        val eventType = when (trackEvent) {
            LiveActivityMessagingService.TRACK_EVENT_CTA -> "cta"
            else -> "opened"
        }
        val ctaIdForTrack = if (eventType == "cta") ctaId else null

        // 1️⃣ Track (HTTP from native so cold start still hits the API — broadcast runs before Flutter listens)
        if (!clickToken.isNullOrEmpty()) {
            LiveActivityMessagingService.trackNotificationEvent(
                clickToken,
                eventType,
                ctaIdForTrack,
                ctaUrl
            )
        }

        // 2️⃣ Open browser for CTA, otherwise bring the Flutter app to the foreground
        if (!ctaUrl.isNullOrBlank()) {
            try {
                startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse(ctaUrl)).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                )
            } catch (e: Exception) {
                Log.e("CTATrackingActivity", "Failed to open URL: $ctaUrl", e)
            }
        } else {
            val launch = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
            }
            if (launch != null) {
                startActivity(launch)
            } else {
                Log.e("CTATrackingActivity", "getLaunchIntentForPackage returned null")
            }
        }

        // 3️⃣ Cancel notification
        val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (notificationId != -1) notificationManager.cancel(notificationId)

        // 4️⃣ Close this activity
        finish()
    }
}
