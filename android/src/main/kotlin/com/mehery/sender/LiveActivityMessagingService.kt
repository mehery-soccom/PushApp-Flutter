package com.mehery.sender

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.net.HttpURLConnection
import java.net.URL

class LiveActivityMessagingService : FirebaseMessagingService() {
    private val tag = "LiveActivityMessaging"

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.d(tag, "From: ${remoteMessage.from}")

        if (remoteMessage.data.isEmpty()) return

        Log.d(tag, "Message data payload: ${remoteMessage.data}")

        try {
            val engineId = packageName
            val flutterEngine = FlutterEngineCache.getInstance().get(engineId)
                ?: FlutterEngineCache.getInstance().get("default")

            flutterEngine?.let {
                val channel = MethodChannel(
                    it.dartExecutor.binaryMessenger,
                    MeherySenderPlugin.METHOD_CHANNEL,
                )
                channel.invokeMethod(MeherySenderPlugin.METHOD_PING, null)
                Log.d(tag, "Ping method called successfully on ${MeherySenderPlugin.METHOD_CHANNEL}")
            } ?: Log.w(tag, "Flutter engine not available for ping method")
        } catch (e: Exception) {
            Log.e(tag, "Error calling ping method: ${e.message}", e)
        }

        try {
            val clickToken = remoteMessage.data["click_token"]

            if (remoteMessage.data.containsKey("message1") &&
                remoteMessage.data.containsKey("message2") &&
                remoteMessage.data.containsKey("message3")
            ) {
                handleLiveActivityNotification(remoteMessage.data)
            } else {
                val title = remoteMessage.data["title"] ?: "Notification"
                val message = remoteMessage.data["body"] ?: "You have a new message"
                val title1 = remoteMessage.data["title1"]
                val url1 = remoteMessage.data["url1"]
                val title2 = remoteMessage.data["title2"]
                val url2 = remoteMessage.data["url2"]

                val notificationManager =
                    getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val channelId = "default_channel_id"
                val channelName = "Default Channel"

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val channel = NotificationChannel(
                        channelId,
                        channelName,
                        NotificationManager.IMPORTANCE_HIGH,
                    )
                    notificationManager.createNotificationChannel(channel)
                }

                val notificationId = System.currentTimeMillis().toInt()

                val builder = NotificationCompat.Builder(this, channelId)
                    .setSmallIcon(R.drawable.ic_notification)
                    .setContentTitle(title)
                    .setContentText(message)
                    .setAutoCancel(true)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)

                val imageUrl =
                    remoteMessage.data["image"]
                        ?: remoteMessage.data["imageUrl"]
                        ?: remoteMessage.data["big_image"]
                        ?: remoteMessage.notification?.imageUrl?.toString()
                imageUrl?.let { image ->
                    try {
                        val url = URL(image)
                        val connection = url.openConnection() as HttpURLConnection
                        connection.doInput = true
                        connection.connectTimeout = 10000
                        connection.readTimeout = 15000
                        connection.connect()
                        val inputStream = connection.inputStream
                        val bitmap = BitmapFactory.decodeStream(inputStream)
                        if (bitmap != null) {
                            builder
                                .setLargeIcon(bitmap)
                                .setStyle(
                                    NotificationCompat.BigPictureStyle()
                                        .bigPicture(bitmap)
                                        .bigLargeIcon(null as android.graphics.Bitmap?),
                                )
                        } else {
                            Log.w(tag, "Image decode returned null for: $image")
                        }
                        inputStream.close()
                    } catch (e: Exception) {
                        Log.e(tag, "Image load failed for $image: ${e.message}")
                    }
                }

                val openIntent = Intent(this, CTATrackingActivity::class.java).apply {
                    putExtra("click_token", clickToken)
                    putExtra("notification_id", notificationId)
                    putExtra(EXTRA_TRACK_EVENT, TRACK_EVENT_OPEN)
                }
                val openPendingIntent = PendingIntent.getActivity(
                    this,
                    notificationId,
                    openIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                builder.setContentIntent(openPendingIntent)

                if (!title1.isNullOrBlank() && !url1.isNullOrBlank()) {
                    val intent1 = Intent(this, CTATrackingActivity::class.java).apply {
                        putExtra("click_token", clickToken)
                        putExtra("cta_id", "action1")
                        putExtra("cta_url", url1)
                        putExtra("notification_id", notificationId)
                        putExtra(EXTRA_TRACK_EVENT, TRACK_EVENT_CTA)
                    }
                    val pending1 = PendingIntent.getActivity(
                        this,
                        notificationId + 1,
                        intent1,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    )
                    builder.addAction(0, title1, pending1)
                }

                if (!title2.isNullOrBlank() && !url2.isNullOrBlank()) {
                    val intent2 = Intent(this, CTATrackingActivity::class.java).apply {
                        putExtra("click_token", clickToken)
                        putExtra("cta_id", "action2")
                        putExtra("cta_url", url2)
                        putExtra("notification_id", notificationId)
                        putExtra(EXTRA_TRACK_EVENT, TRACK_EVENT_CTA)
                    }
                    val pending2 = PendingIntent.getActivity(
                        this,
                        notificationId + 2,
                        intent2,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    )
                    builder.addAction(0, title2, pending2)
                }

                notificationManager.notify(notificationId, builder.build())
            }
        } catch (e: Exception) {
            Log.e(tag, "Error handling FCM message", e)
        }
    }

    private fun handleLiveActivityNotification(data: Map<String, String>) {
        try {
            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val customNotificationService = CustomNotificationService(this)

            val title = data["message1"] ?: ""
            val message = data["message2"] ?: ""
            val tapText = data["message3"] ?: ""
            val progress = (data["progressPercent"]?.toDoubleOrNull() ?: 0.0) * 100

            val titleColor = data["message1FontColorHex"] ?: "#FF0000"
            val messageColor = data["message2FontColorHex"] ?: "#000000"
            val tapTextColor = data["message3FontColorHex"] ?: "#CCCCCC"
            val progressColor = data["progressColorHex"] ?: "#00FF00"
            val backgroundColor = data["backgroundColorHex"] ?: "#FFFFFF"
            val imageUrl = data["imageUrl"] ?: ""
            val bg_color_gradient = data["bg_color_gradient"] ?: ""
            val bg_color_gradient_dir = data["bg_color_gradient_dir"] ?: ""
            val align = data["align"] ?: ""

            val message1FontSize = data["message1FontSize"]?.toDoubleOrNull() ?: 14.0
            val line1FontTextStyles = data["line1_text_styles"]?.split(",") ?: emptyList()
            val message2FontSize = data["message2FontSize"]?.toDoubleOrNull() ?: 14.0
            val line2FontTextStyles = data["line2_text_styles"]?.split(",") ?: emptyList()
            val message3FontSize = data["message3FontSize"]?.toDoubleOrNull() ?: 14.0
            val line3FontTextStyles = data["line3_text_styles"]?.split(",") ?: emptyList()

            val activityId = data["activity_id"] ?: "fcm_activity_${System.currentTimeMillis()}"
            val notificationId = activityId.hashCode()

            val notification = customNotificationService.createCustomNotification(
                channelId = MeherySenderPlugin.LIVE_ACTIVITY_CHANNEL_ID,
                title = title,
                message = message,
                tapText = tapText,
                progress = progress.toInt(),
                titleColor = titleColor,
                messageColor = messageColor,
                tapTextColor = tapTextColor,
                progressColor = progressColor,
                backgroundColor = backgroundColor,
                imageUrl = imageUrl,
                bg_color_gradient = bg_color_gradient,
                bg_color_gradient_dir = bg_color_gradient_dir,
                align = align,
                notificationId = notificationId,
                message1FontSize = message1FontSize,
                line1FontTextStyles = line1FontTextStyles,
                message2FontSize = message2FontSize,
                line2FontTextStyles = line2FontTextStyles,
                message3FontSize = message3FontSize,
                line3FontTextStyles = line3FontTextStyles,
            )

            Log.d(tag, "Showing FCM notification with ID: $notificationId")
            notificationManager.notify(notificationId, notification.build())
            Log.d(tag, "FCM notification posted successfully")
        } catch (e: Exception) {
            Log.e(tag, "Error showing notification from FCM", e)
        }
    }

    override fun onNewToken(token: String) {
        Log.d(tag, "Refreshed FCM token: $token")
    }

    companion object {
        const val EXTRA_TRACK_EVENT = "track_event"
        const val TRACK_EVENT_OPEN = "opened"
        const val TRACK_EVENT_CTA = "cta"
    }
}
