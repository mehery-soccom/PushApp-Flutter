package com.mehery.sender

import android.app.PendingIntent
import android.content.Context
import android.graphics.*
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StyleSpan
import android.text.style.UnderlineSpan
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

class CustomNotificationService(private val context: Context) {

    fun createCustomNotification(
        channelId: String,
        title: String,
        message: String,
        tapText: String,
        progress: Int,
        titleColor: String,
        messageColor: String,
        tapTextColor: String,
        progressColor: String,
        backgroundColor: String,
        imageUrl: String,
        bg_color_gradient: String,
        bg_color_gradient_dir: String,
        align: String,
        notificationId: Int,
        message1FontSize: Double = 14.0,
        line1FontTextStyles: List<String> = emptyList(),
        message2FontSize: Double = 14.0,
        line2FontTextStyles: List<String> = emptyList(),
        message3FontSize: Double = 14.0,
        line3FontTextStyles: List<String> = emptyList(),
    ): NotificationCompat.Builder {
        val customView = RemoteViews(context.packageName, R.layout.custom_notification_layout)

        try {
            if (bg_color_gradient.isNotEmpty() && bg_color_gradient_dir.isNotEmpty()) {
                val startColor = Color.parseColor(backgroundColor)
                val endColor = Color.parseColor(bg_color_gradient)
                val isHorizontal = bg_color_gradient_dir.equals("horizontal", ignoreCase = true)
                customView.setImageViewBitmap(
                    R.id.root_background,
                    createGradientBitmap(startColor, endColor, isHorizontal),
                )
            } else {
                customView.setImageViewBitmap(
                    R.id.root_background,
                    createSolidColorBitmap(Color.parseColor(backgroundColor)),
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        customView.setTextViewText(R.id.title, getStyledSpannable(title, line1FontTextStyles))
        customView.setTextViewText(R.id.message, getStyledSpannable(message, line2FontTextStyles))
        customView.setTextViewText(R.id.tap_text, getStyledSpannable(tapText, line3FontTextStyles))

        try {
            customView.setTextColor(R.id.title, Color.parseColor(titleColor))
            customView.setTextColor(R.id.message, Color.parseColor(messageColor))
            customView.setTextColor(R.id.tap_text, Color.parseColor(tapTextColor))
            customView.setFloat(R.id.title, "setTextSize", message1FontSize.toFloat())
            customView.setFloat(R.id.message, "setTextSize", message2FontSize.toFloat())
            customView.setFloat(R.id.tap_text, "setTextSize", message3FontSize.toFloat())
        } catch (e: Exception) {
            e.printStackTrace()
        }

        customView.setProgressBar(R.id.progress_bar, 100, progress, false)

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setCustomContentView(customView)
            .setCustomBigContentView(customView)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentTitle(title)
            .setContentText(message)
            .setSubText(tapText)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        builder.setContentIntent(pendingIntent)

        if (imageUrl.isNotEmpty()) {
            downloadImage(imageUrl) { bitmap ->
                if (bitmap != null) {
                    val updatedView = RemoteViews(context.packageName, R.layout.custom_notification_layout)
                    try {
                        val bgBitmap =
                            if (bg_color_gradient.isNotEmpty() && bg_color_gradient_dir.isNotEmpty()) {
                                val startColor = Color.parseColor(backgroundColor)
                                val endColor = Color.parseColor(bg_color_gradient)
                                val isHorizontal =
                                    bg_color_gradient_dir.equals("horizontal", ignoreCase = true)
                                createGradientBitmap(startColor, endColor, isHorizontal)
                            } else {
                                createSolidColorBitmap(Color.parseColor(backgroundColor))
                            }
                        updatedView.setImageViewBitmap(R.id.root_background, bgBitmap)
                    } catch (_: Exception) {
                    }

                    updatedView.setTextViewText(
                        R.id.title,
                        getStyledSpannable(title, line1FontTextStyles),
                    )
                    updatedView.setTextViewText(
                        R.id.message,
                        getStyledSpannable(message, line2FontTextStyles),
                    )
                    updatedView.setTextViewText(
                        R.id.tap_text,
                        getStyledSpannable(tapText, line3FontTextStyles),
                    )
                    updatedView.setTextColor(R.id.title, Color.parseColor(titleColor))
                    updatedView.setTextColor(R.id.message, Color.parseColor(messageColor))
                    updatedView.setTextColor(R.id.tap_text, Color.parseColor(tapTextColor))
                    updatedView.setFloat(R.id.title, "setTextSize", message1FontSize.toFloat())
                    updatedView.setFloat(R.id.message, "setTextSize", message2FontSize.toFloat())
                    updatedView.setFloat(R.id.tap_text, "setTextSize", message3FontSize.toFloat())
                    updatedView.setProgressBar(R.id.progress_bar, 100, progress, false)
                    updatedView.setImageViewBitmap(R.id.icon, bitmap)

                    val updatedBuilder = NotificationCompat.Builder(context, channelId)
                        .setSmallIcon(R.drawable.ic_notification)
                        .setCustomContentView(updatedView)
                        .setCustomBigContentView(updatedView)
                        .setStyle(NotificationCompat.DecoratedCustomViewStyle())
                        .setPriority(NotificationCompat.PRIORITY_MAX)
                        .setOngoing(true)
                        .setAutoCancel(false)
                        .setContentTitle(title)
                        .setContentText(message)
                        .setSubText(tapText)
                        .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                        .setContentIntent(pendingIntent)

                    val manager =
                        context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                    manager.notify(notificationId, updatedBuilder.build())
                }
            }
        }

        return builder
    }

    private fun getStyledSpannable(text: String, styles: List<String>): CharSequence {
        if (styles.isEmpty()) return text
        val spannable = SpannableString(text)
        styles.forEach { style ->
            when (style.lowercase().trim()) {
                "bold" ->
                    spannable.setSpan(
                        StyleSpan(Typeface.BOLD),
                        0,
                        text.length,
                        Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
                    )
                "italic" ->
                    spannable.setSpan(
                        StyleSpan(Typeface.ITALIC),
                        0,
                        text.length,
                        Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
                    )
                "underline" ->
                    spannable.setSpan(
                        UnderlineSpan(),
                        0,
                        text.length,
                        Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
                    )
            }
        }
        return spannable
    }

    fun createGradientBitmap(
        startColor: Int,
        endColor: Int,
        isHorizontal: Boolean,
        width: Int = 1080,
        height: Int = 300,
    ): Bitmap {
        val orientation =
            if (isHorizontal) GradientDrawable.Orientation.LEFT_RIGHT
            else GradientDrawable.Orientation.TOP_BOTTOM
        val gradient = GradientDrawable(orientation, intArrayOf(startColor, endColor))
        gradient.setBounds(0, 0, width, height)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        gradient.draw(canvas)
        return bitmap
    }

    fun createSolidColorBitmap(color: Int, width: Int = 1080, height: Int = 300): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(color)
        return bitmap
    }

    fun downloadImage(urlString: String, onResult: (Bitmap?) -> Unit) {
        val cleanUrl = if (urlString.startsWith("@")) urlString.substring(1) else urlString
        Thread {
            var bitmap: Bitmap? = null
            try {
                val url = URL(cleanUrl)
                val connection = url.openConnection() as HttpURLConnection
                connection.doInput = true
                connection.connectTimeout = 15000
                connection.readTimeout = 15000
                connection.connect()
                if (connection.responseCode == 200) {
                    val input: InputStream = connection.inputStream
                    bitmap = BitmapFactory.decodeStream(input)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
            Handler(Looper.getMainLooper()).post { onResult(bitmap) }
        }.start()
    }

    fun testImageLoading(imageUrl: String, callback: (Boolean) -> Unit) {
        downloadImage(imageUrl) { bitmap -> callback(bitmap != null) }
    }
}
