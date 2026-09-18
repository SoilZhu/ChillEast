package su.soilzhu.chilleast

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * AOSP Live Updates（Android 16 / API 36+）最小实现。
 *
 * flutter_local_notifications 17.x 没有 ProgressStyle / setRequestPromotedOngoing，
 * 所以这里手写原生通道。Dart 侧经 MethodChannel("course_live") 调用。
 *
 * 晋升 Live Update 的硬条件（缺一即降级为普通通知）：
 *  Standard/BigText/Call/Progress/Metric 样式 + POST_PROMOTED_NOTIFICATIONS（Manifest）
 *  + setOngoing(true) + setRequestPromotedOngoing(true) + contentTitle + 无 RemoteViews。
 */
object CourseLiveManager {
    const val CHANNEL_ID = "course_live_channel"
    private const val CHANNEL_NAME = "课程实时活动"

    /** API 36 = Android 16，只有这些设备能晋升 Live Update。 */
    fun isSupported(): Boolean = Build.VERSION.SDK_INT >= 36

    private fun manager(ctx: Context): NotificationManager =
        ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val mgr = manager(ctx)
        if (mgr.getNotificationChannel(CHANNEL_ID) != null) return
        val ch = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "上课进行中的实时进度提醒（Android 16 Live Updates）"
        }
        mgr.createNotificationChannel(ch)
    }

    /** 系统总开关（POST_NOTIFICATIONS）是否开。 */
    fun areNotificationsEnabled(ctx: Context): Boolean =
        NotificationManagerCompat.from(ctx).areNotificationsEnabled()

    /**
     * 用户是否允许本 App 发送 promoted（Live Update）通知。
     * 低版本直接返回 false；API 36 方法用 try/catch 包住防 OEM 裁剪。
     */
    fun canPostPromoted(ctx: Context): Boolean {
        if (!isSupported()) return false
        return try {
            manager(ctx).canPostPromotedNotifications()
        } catch (_: Exception) {
            false
        }
    }

    /**
     * 跳系统“允许实时更新/ promoted 通知”设置页。
     * Flyme 等 ROM 根本没有这个页面（startActivity 直接抛 ActivityNotFound），
     * 所以逐级 fallback：promoted 设置 → 应用通知设置 → 应用详情页。
     */
    fun openPromotedSettings(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 36) {
            try {
                // 真机 SDK 36 中的实际常量名（文档曾写作 MANAGE_APP_PROMOTED，经 javap 核对）
                val intent = Intent(Settings.ACTION_APP_NOTIFICATION_PROMOTION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                ctx.startActivity(intent)
                return true
            } catch (_: Exception) {
                // 无此页面（如 Flyme），继续往下走 fallback
            }
        }
        return try {
            val fallback = appNotificationSettings(ctx).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            ctx.startActivity(fallback)
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

    private fun appNotificationSettings(ctx: Context): Intent =
        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName)
        }

    /** 直跳本应用的系统通知设置页（再 fallback 到应用详情页）。 */
    fun openNotificationSettings(ctx: Context): Boolean {
        return try {
            val intent = appNotificationSettings(ctx).apply {
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
     * 创建或更新一条实时活动（同 id 反复 notify 即更新）。
     * @param progress 当前进度（0..total），total 建议传 100
     * @param whenMs 状态栏 chip 的倒计时锚点，一般传下课时间戳；<=0 则不显示时间
     */
    fun upsert(
        ctx: Context,
        id: Int,
        title: String,
        text: String,
        shortText: String,
        progress: Int,
        total: Int,
        whenMs: Long,
    ) {
        ensureChannel(ctx)
        val safeTotal = total.coerceAtLeast(1)
        val safeProgress = progress.coerceIn(0, safeTotal)

        val builder = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(contentIntent(ctx))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(whenMs > 0)
            .setAutoCancel(false)

        if (whenMs > 0) builder.setWhen(whenMs)
        if (shortText.isNotEmpty()) {
            try {
                builder.setShortCriticalText(shortText)
            } catch (_: Exception) {
                // 极少数旧版 core 没有此方法，忽略即可
            }
        }

        if (isSupported()) {
            // ---- Android 16+ Live Updates 路径 ----
            try {
                builder.setRequestPromotedOngoing(true)
            } catch (_: Exception) {
                // core 版本过旧时降级为普通 ongoing 通知
            }
            try {
                // Compat ProgressStyle.setProgress 为单参数（0..总段长），配一段总长 total 的 Segment
                val segment = NotificationCompat.ProgressStyle.Segment(safeTotal)
                    .setColor(0xFF09C489.toInt())
                builder.setStyle(
                    NotificationCompat.ProgressStyle()
                        .setProgress(safeProgress)
                        .setProgressSegments(listOf(segment)),
                )
            } catch (_: Exception) {
                builder.setProgress(safeTotal, safeProgress, false)
            }
        } else {
            // ---- 低版本兜底：经典进度条 ongoing 通知 ----
            builder.setProgress(safeTotal, safeProgress, false)
        }

        try {
            manager(ctx).notify(id, builder.build())
        } catch (_: SecurityException) {
            // 通知权限被关时系统抛 SecurityException，直接吞掉不崩
        }
    }

    fun cancel(ctx: Context, id: Int) {
        try {
            manager(ctx).cancel(id)
        } catch (_: Exception) {
        }
    }
}
