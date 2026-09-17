package su.soilzhu.chilleast

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.RemoteViews
import androidx.core.app.NotificationManagerCompat

/**
 * Flyme 实况通知（Flyme 12+），实现照抄
 * Ruyue-Kinsenka/Flyme-Live-Notification-Demo 的 LiveNotificationManager：
 * 标准通知 + notification.live.* extras + RemoteViews 胶囊。
 *
 * 与 AOSP Live Updates（CourseLiveManager）互斥，Dart 侧开关保证不同开。
 */
object FlymeLiveManager {
    const val CHANNEL_ID = "flyme_live_channel"
    private const val CHANNEL_NAME = "实况通知"

    // demo 实测可用的固定参数
    private const val CAPSULE_STATUS_ON = 1
    private const val CAPSULE_TYPE = 5
    private const val OPERATION_SHOW = 0
    private const val LIVE_TYPE = 2

    private const val CAPSULE_BG = 0xFF09C489.toInt()
    private const val CAPSULE_TEXT_COLOR = 0xFFFFFFFF.toInt()

    // ---------------- 设备判定 ----------------

    private fun systemProperty(key: String, def: String): String {
        return try {
            val c = Class.forName("android.os.SystemProperties")
            val m = c.getMethod("get", String::class.java, String::class.java)
            m.invoke(null, key, def) as? String ?: def
        } catch (_: Exception) {
            def
        }
    }

    /** ro.build.display.id（如 "Flyme 12.2.0.0A"），拿不到则退回 Build.DISPLAY。 */
    fun displayId(): String {
        val prop = systemProperty("ro.build.display.id", "")
        if (prop.isNotEmpty()) return prop
        return try {
            Build.DISPLAY ?: ""
        } catch (_: Exception) {
            ""
        }
    }

    /** 从 "Flyme 12.x" 解析主版本号，解析失败返回 0。 */
    fun flymeMajor(): Int {
        return try {
            Regex("Flyme\\s*(\\d+)", RegexOption.IGNORE_CASE)
                .find(displayId())
                ?.groupValues?.get(1)?.toInt() ?: 0
        } catch (_: Exception) {
            0
        }
    }

    fun isMeizu(): Boolean {
        val manufacturer = try {
            Build.MANUFACTURER ?: ""
        } catch (_: Exception) {
            ""
        }
        val brand = try {
            Build.BRAND ?: ""
        } catch (_: Exception) {
            ""
        }
        return manufacturer.contains("meizu", true) ||
            brand.contains("meizu", true) ||
            displayId().contains("flyme", true)
    }

    /** 魅族设备 + Flyme 主版本 >= 12 才展示“实况通知”入口。 */
    fun isSupported(): Boolean = isMeizu() && flymeMajor() >= 12

    // ---------------- 通知 ----------------

    private fun manager(ctx: Context): NotificationManager =
        ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    fun areNotificationsEnabled(ctx: Context): Boolean =
        NotificationManagerCompat.from(ctx).areNotificationsEnabled()

    /** 直跳本应用的系统通知设置页（再 fallback 到应用详情页）。 */
    fun openNotificationSettings(ctx: Context): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            ctx.startActivity(intent)
            true
        } catch (_: Exception) {
            try {
                val details = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:${ctx.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                ctx.startActivity(details)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val mgr = manager(ctx)
        if (mgr.getNotificationChannel(CHANNEL_ID) != null) return
        val ch = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "课前倒计时 / 座位预约实况通知（Flyme）"
        }
        mgr.createNotificationChannel(ch)
    }

    private fun contentIntent(ctx: Context): PendingIntent {
        val intent = Intent(ctx, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            ctx, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * 发一条实况通知（静态卡片，不更新）。
     * @param capsuleText 胶囊小条文案，只放地点，如 "教3-201"
     * @param timeText 卡片右上角时间行，如 "10:05开课"
     */
    fun upsert(
        ctx: Context,
        id: Int,
        title: String,
        text: String,
        capsuleText: String,
        timeText: String,
    ) {
        ensureChannel(ctx)

        // 胶囊
        val capsuleViews = RemoteViews(ctx.packageName, R.layout.flyme_live_capsule)
        capsuleViews.setTextViewText(R.id.capsule_content, capsuleText)
        val capsuleBundle = Bundle().apply {
            putInt("notification.live.capsuleStatus", CAPSULE_STATUS_ON)
            putInt("notification.live.capsuleType", CAPSULE_TYPE)
            putString("notification.live.capsuleContent", capsuleText)
            putParcelable(
                "notification.live.capsuleIcon",
                Icon.createWithResource(ctx, R.mipmap.ic_launcher),
            )
            putInt("notification.live.capsuleBgColor", CAPSULE_BG)
            putInt("notification.live.capsuleContentColor", CAPSULE_TEXT_COLOR)
            putParcelable("notification.live.capsule.content.remote.view", capsuleViews)
        }
        val liveBundle = Bundle().apply {
            putBoolean("is_live", true)
            putInt("notification.live.operation", OPERATION_SHOW)
            putInt("notification.live.type", LIVE_TYPE)
            putBundle("notification.live.capsule", capsuleBundle)
        }

        // 主卡片（Live Updates 样式；应用名不要，只留图标+时间）
        val cardViews = RemoteViews(ctx.packageName, R.layout.flyme_live_card)
        cardViews.setTextViewText(R.id.flyme_card_app, "")
        cardViews.setTextViewText(R.id.flyme_card_title, title)
        cardViews.setTextViewText(R.id.flyme_card_text, text)
        cardViews.setTextViewText(R.id.flyme_card_time, timeText)

        val notification = Notification.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(contentIntent(ctx))
            .setShowWhen(true)
            .setAutoCancel(false)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .addExtras(liveBundle)
            .build()
        notification.contentView = cardViews

        try {
            manager(ctx).notify(id, notification)
        } catch (_: SecurityException) {
            // 通知权限被关时直接吞掉不崩
        }
    }

    fun cancel(ctx: Context, id: Int) {
        try {
            manager(ctx).cancel(id)
        } catch (_: Exception) {
        }
    }
}
