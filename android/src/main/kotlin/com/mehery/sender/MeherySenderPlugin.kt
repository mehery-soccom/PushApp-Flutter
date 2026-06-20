package com.mehery.sender

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.net.HttpURLConnection
import java.net.URL

class MeherySenderPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var liveActivityChannel: MethodChannel
    private lateinit var applicationContext: Context
    private lateinit var customNotificationService: CustomNotificationService
    private lateinit var notificationManager: NotificationManager
    private var mesendEventChannel: MesendEventChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        customNotificationService = CustomNotificationService(applicationContext)
        notificationManager =
            applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        ensureNotificationChannel()

        liveActivityChannel = MethodChannel(
            binding.binaryMessenger,
            LIVE_ACTIVITY_CHANNEL,
        )
        liveActivityChannel.setMethodCallHandler(this)

        val eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        mesendEventChannel = MesendEventChannel(applicationContext).also {
            it.register(eventChannel)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        liveActivityChannel.setMethodCallHandler(null)
        mesendEventChannel = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "showLiveActivity" -> handleShowLiveActivity(call, result)
            "endLiveActivity" -> {
                val activityId = call.arguments as String
                notificationManager.cancel(activityId.hashCode())
                result.success(null)
            }
            "testImageNotification" -> {
                val activityId = call.arguments as String
                testImageNotification(activityId)
                result.success(null)
            }
            "testImageLoading" -> {
                val imageUrl = call.arguments as String
                customNotificationService.testImageLoading(imageUrl) { success ->
                    result.success(success)
                }
            }
            "testDirectImageLoading" -> handleTestDirectImageLoading(call.arguments as String, result)
            else -> result.notImplemented()
        }
    }

    private fun ensureNotificationChannel() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            notificationManager.deleteNotificationChannel(LIVE_ACTIVITY_CHANNEL_ID)
            val channel = NotificationChannel(
                LIVE_ACTIVITY_CHANNEL_ID,
                "Live Activities",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                enableLights(true)
                enableVibration(true)
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setAllowBubbles(true)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun handleShowLiveActivity(call: MethodCall, result: Result) {
        try {
            val args = call.arguments as Map<*, *>
            val activityId = args["activity_id"] as String
            val notificationId = activityId.hashCode()

            val notification = customNotificationService.createCustomNotification(
                channelId = LIVE_ACTIVITY_CHANNEL_ID,
                title = args["title"] as String,
                message = args["message"] as String,
                tapText = args["tap_text"] as String,
                progress = (args["progress"] as Double).toInt(),
                titleColor = args["title_color"] as String,
                messageColor = args["message_color"] as String,
                tapTextColor = args["tap_text_color"] as String,
                progressColor = args["progress_color"] as String,
                backgroundColor = args["background_color"] as String,
                imageUrl = args["imageUrl"] as String,
                bg_color_gradient = args["bg_color_gradient"] as String,
                bg_color_gradient_dir = args["bg_color_gradient_dir"] as String,
                align = args["align"] as String,
                notificationId = notificationId,
            )
            notification.extras.putInt("notification_id", notificationId)
            result.success(null)
        } catch (e: Exception) {
            result.error("NOTIFICATION_ERROR", e.message, null)
        }
    }

    private fun handleTestDirectImageLoading(imageUrl: String, result: Result) {
        Thread {
            try {
                val url = URL(imageUrl)
                val connection = url.openConnection() as HttpURLConnection
                connection.doInput = true
                connection.connectTimeout = 15000
                connection.readTimeout = 15000
                connection.connect()

                val success = if (connection.responseCode == 200) {
                    connection.inputStream.use { input ->
                        BitmapFactory.decodeStream(input) != null
                    }
                } else {
                    false
                }
                Handler(Looper.getMainLooper()).post { result.success(success) }
            } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post { result.success(false) }
            }
        }.start()
    }

    private fun testImageNotification(activityId: String) {
        val imageUrl = "https://samplelib.com/lib/preview/png/sample-boat-400x300.png"
        val notificationId = activityId.hashCode()
        val notification = customNotificationService.createCustomNotification(
            channelId = LIVE_ACTIVITY_CHANNEL_ID,
            title = "Test Image",
            message = "This is a test notification with image",
            tapText = "Tap to open",
            progress = 50,
            titleColor = "#FF0000",
            messageColor = "#000000",
            tapTextColor = "#CCCCCC",
            progressColor = "#00FF00",
            backgroundColor = "#FFFFFF",
            imageUrl = imageUrl,
            bg_color_gradient = "#F00000",
            bg_color_gradient_dir = "horizontal",
            align = "left",
            notificationId = notificationId,
        )
        notification.extras.putInt("notification_id", notificationId)
    }

    companion object {
        private const val LIVE_ACTIVITY_CHANNEL = "com.mehery.admin/live_activity"

        /** Must match Dart [meherySenderEventChannel]. */
        const val EVENT_CHANNEL = "mesend_event_channel"

        /** Must match Dart [meherySenderMethodChannel]. */
        const val METHOD_CHANNEL = "mehery_channel"
        const val METHOD_PING = "ping"
        const val METHOD_TRACK_NOTIFICATION = "trackNotification"

        const val LIVE_ACTIVITY_CHANNEL_ID = "live_activity_channel"
    }
}
