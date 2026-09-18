package su.soilzhu.chilleast

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray

/**
 * 实时卡（AOSP Live Updates / Flyme 实况）的原生精确闹钟编排。
 *
 * Dart 侧算好所有窗口（发卡/更新/撤卡时刻 + 展示文案要素）一次性 program() 进来；
 * App 被杀时照样准时触发。语义为全量替换：每次 program 先清掉旧的再排新的。
 * 事件列表同时持久化，供开机/覆盖安装后重建闹钟。
 */
object LiveAlarmScheduler {
    const val ACTION_FIRE = "su.soilzhu.chilleast.LIVE_FIRE"
    const val ACTION_END = "su.soilzhu.chilleast.LIVE_END"

    private const val PREFS = "live_alarms"
    private const val KEY_EVENTS = "events_v1"

    fun prefs(ctx: Context) =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun readPersistedEvents(ctx: Context): String? =
        try {
            prefs(ctx).getString(KEY_EVENTS, null)
        } catch (_: Exception) {
            null
        }

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

    private fun alarmIntent(ctx: Context, action: String, code: Int): Intent =
        Intent(ctx, LiveAlarmReceiver::class.java).apply {
            this.action = action
        }

    /** 全量替换式编排，返回成功排入的闹钟数。 */
    fun program(ctx: Context, eventsJson: String): Int {
        cancelAllAlarmsOnly(ctx)
        try {
            prefs(ctx).edit().putString(KEY_EVENTS, eventsJson).apply()
        } catch (_: Exception) {
        }
        val arr = try {
            JSONArray(eventsJson)
        } catch (_: Exception) {
            return 0
        }
        val am = alarmManager(ctx) ?: return 0
        val exact = canExact(am)
        val now = System.currentTimeMillis()
        var count = 0
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            val triggerAt = o.optLong("triggerAt", 0)
            // 已过的触发点不管（Dart 同步时已做即时 reconcile）
            if (triggerAt <= now) continue
            val code = o.optInt("code", 0)
            if (code == 0) continue
            val intent = alarmIntent(ctx, o.optString("action"), code).apply {
                putExtra("code", code)
                putExtra("liveId", o.optInt("liveId"))
                putExtra("kind", o.optString("kind"))
                putExtra("name", o.optString("name"))
                putExtra("location", o.optString("location"))
                putExtra("startTs", o.optLong("startTs"))
                putExtra("leadMin", o.optInt("leadMin"))
                putExtra("channel", o.optString("channel"))
                putExtra("windowEnd", o.optLong("windowEnd"))
            }
            val pi = PendingIntent.getBroadcast(
                ctx, code, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            try {
                if (exact) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
                } else {
                    // 精确闹钟权限被收回时降级为非精确（可能晚几分钟）
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
                }
                count++
            } catch (_: Exception) {
            }
        }
        return count
    }

    private fun cancelAllAlarmsOnly(ctx: Context) {
        val raw = readPersistedEvents(ctx) ?: return
        val am = alarmManager(ctx) ?: return
        try {
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                val code = o.optInt("code", 0)
                if (code == 0) continue
                val pi = PendingIntent.getBroadcast(
                    ctx, code, alarmIntent(ctx, o.optString("action"), code),
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
                )
                if (pi != null) {
                    try {
                        am.cancel(pi)
                    } catch (_: Exception) {
                    }
                    pi.cancel()
                }
            }
        } catch (_: Exception) {
        }
    }

    /** 取消全部闹钟 + 清持久化（关开关时调用）。 */
    fun cancelAll(ctx: Context) {
        cancelAllAlarmsOnly(ctx)
        try {
            prefs(ctx).edit().remove(KEY_EVENTS).apply()
        } catch (_: Exception) {
        }
    }

    /** 双通道撤卡（AOSP + Flyme 各撤一次，无害）。 */
    fun cancelCard(ctx: Context, id: Int) {
        CourseLiveManager.cancel(ctx, id)
        FlymeLiveManager.cancel(ctx, id)
    }
}
