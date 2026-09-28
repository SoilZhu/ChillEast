package su.soilzhu.chilleast

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray

/**
 * 桌面小组件准实时刷新闹钟调度器。
 *
 * 接收下课时间、每日 22:00（切明日）与 00:00（跨天）的时间戳列表，
 * 使用 AlarmManager 设定精确唤醒闹钟。App 即使在后台或被杀死也能准时触发刷新。
 */
object WidgetAlarmScheduler {
    private const val TAG = "WidgetAlarmScheduler"
    const val ACTION_WIDGET_ALARM = "su.soilzhu.chilleast.WIDGET_ALARM"

    private const val PREFS = "widget_alarms"
    private const val KEY_TIMESTAMPS = "timestamps_v1"

    private fun prefs(ctx: Context) =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun alarmManager(ctx: Context): AlarmManager? =
        try {
            ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        } catch (_: Exception) {
            null
        }

    private fun canExact(am: AlarmManager): Boolean {
        if (Build.VERSION.SDK_INT < 31) return true
        return try {
            am.canScheduleExactAlarms()
        } catch (_: Exception) {
            false
        }
    }

    private fun alarmIntent(ctx: Context, timestamp: Long): Intent =
        Intent(ctx, WidgetAlarmReceiver::class.java).apply {
            action = ACTION_WIDGET_ALARM
            putExtra("triggerAt", timestamp)
        }

    private fun requestCodeFor(timestamp: Long): Int {
        return ((timestamp / 1000) % 2147483647L).toInt()
    }

    /**
     * 全量编排小组件刷新闹钟。
     */
    fun schedule(ctx: Context, timestamps: List<Long>): Int {
        cancelAllAlarmsOnly(ctx)
        val now = System.currentTimeMillis()
        val validTimestamps = timestamps.filter { it > now }.distinct().sorted()

        try {
            val jsonArr = JSONArray()
            for (ts in validTimestamps) {
                jsonArr.put(ts)
            }
            prefs(ctx).edit().putString(KEY_TIMESTAMPS, jsonArr.toString()).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to persist timestamps", e)
        }

        val am = alarmManager(ctx) ?: return 0
        val exact = canExact(am)
        var count = 0

        for (ts in validTimestamps) {
            val code = requestCodeFor(ts)
            val intent = alarmIntent(ctx, ts)
            val pi = PendingIntent.getBroadcast(
                ctx,
                code,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            try {
                if (exact) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, ts, pi)
                } else {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, ts, pi)
                }
                count++
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule alarm at $ts", e)
            }
        }
        Log.i(TAG, "Scheduled $count widget alarm(s)")
        return count
    }

    /**
     * 从本地持久化中恢复未过期的闹钟（开机或应用更新后调用）。
     */
    fun rescheduleFromPrefs(ctx: Context): Int {
        val raw = try {
            prefs(ctx).getString(KEY_TIMESTAMPS, null)
        } catch (_: Exception) {
            null
        } ?: return 0

        val list = mutableListOf<Long>()
        try {
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                list.add(arr.getLong(i))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse persisted timestamps", e)
            return 0
        }
        return schedule(ctx, list)
    }

    private fun cancelAllAlarmsOnly(ctx: Context) {
        val raw = try {
            prefs(ctx).getString(KEY_TIMESTAMPS, null)
        } catch (_: Exception) {
            null
        } ?: return
        val am = alarmManager(ctx) ?: return

        try {
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val ts = arr.getLong(i)
                val code = requestCodeFor(ts)
                val pi = PendingIntent.getBroadcast(
                    ctx,
                    code,
                    alarmIntent(ctx, ts),
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
                )
                if (pi != null) {
                    try {
                        am.cancel(pi)
                    } catch (_: Exception) {}
                    pi.cancel()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel alarms", e)
        }
    }

    fun cancelAll(ctx: Context) {
        cancelAllAlarmsOnly(ctx)
        try {
            prefs(ctx).edit().remove(KEY_TIMESTAMPS).apply()
        } catch (_: Exception) {}
    }
}
