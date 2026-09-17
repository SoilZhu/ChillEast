package su.soilzhu.chilleast

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import java.util.Calendar

/**
 * 实时卡闹钟触发 + 开机/覆盖安装后重建。
 *
 * FIRE：按 startTs 算剩余分钟后渲染（与 Dart 侧文案保持一致）；
 *   若触发时已过开始时间，直接撤卡不发过期倒计时。
 * END：双通道撤卡。
 */
class LiveAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val appCtx = context.applicationContext
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            -> {
                reprogram(appCtx)
                return
            }
        }
        handleEvent(appCtx, intent)
    }

    private fun handleEvent(
        ctx: Context,
        action: String,
        liveId: Int,
        kind: String,
        name: String,
        location: String,
        startTs: Long,
        leadMin: Int,
        channel: String,
    ) {
        if (liveId == 0) return
        if (action == LiveAlarmScheduler.ACTION_END) {
            LiveAlarmScheduler.cancelCard(ctx, liveId)
            return
        }
        if (action != LiveAlarmScheduler.ACTION_FIRE) return
        val now = System.currentTimeMillis()
        if (startTs <= now) {
            // 触发晚了（Doze 延迟等）：已开课/已开始，不发过期卡直接撤
            LiveAlarmScheduler.cancelCard(ctx, liveId)
            return
        }
        val remaining = ((startTs - now + 59999) / 60000).toInt().coerceAtLeast(1)
        val elapsed = (leadMin - remaining).coerceAtLeast(0)
        val cal = Calendar.getInstance().apply { timeInMillis = startTs }
        val hh = cal.get(Calendar.HOUR_OF_DAY).toString().padStart(2, '0')
        val mm = cal.get(Calendar.MINUTE).toString().padStart(2, '0')
        if (kind == "library") {
            val title = "$name · $location"
            val text = "还有 $remaining 分钟开始 · 请按时签到"
            val time = "${hh}:${mm}开始"
            if (channel == "flyme") {
                FlymeLiveManager.upsert(ctx, liveId, title, text, location, time)
            } else {
                CourseLiveManager.upsert(ctx, liveId, title, text, location, elapsed, leadMin, startTs)
            }
        } else {
            val title = "$name · $location"
            val text = "还有 $remaining 分钟上课"
            val time = "${hh}:${mm}开课"
            if (channel == "flyme") {
                FlymeLiveManager.upsert(ctx, liveId, title, text, location, time)
            } else {
                CourseLiveManager.upsert(ctx, liveId, title, text, location, elapsed, leadMin, startTs)
            }
        }
    }

    private fun handleEvent(ctx: Context, intent: Intent) {
        handleEvent(
            ctx,
            intent.action ?: return,
            intent.getIntExtra("liveId", 0),
            intent.getStringExtra("kind") ?: "course",
            intent.getStringExtra("name") ?: "",
            intent.getStringExtra("location") ?: "",
            intent.getLongExtra("startTs", 0),
            intent.getIntExtra("leadMin", 15),
            intent.getStringExtra("channel") ?: "aosp",
        )
    }

    /**
     * 开机/覆盖安装后：用持久化的事件列表重建。
     * 已过触发点但窗口未结束的：FIRE 立即执行一次（补卡），END 忽略等 Dart 同步；
     * 未来的重新排闹钟；已结束的丢弃。
     */
    private fun reprogram(ctx: Context) {
        val raw = LiveAlarmScheduler.readPersistedEvents(ctx) ?: return
        val arr = try {
            JSONArray(raw)
        } catch (_: Exception) {
            return
        }
        val am = try {
            ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        } catch (_: Exception) {
            return
        }
        val exact = try {
            if (android.os.Build.VERSION.SDK_INT < 31) true else am.canScheduleExactAlarms()
        } catch (_: Exception) {
            false
        }
        val now = System.currentTimeMillis()
        val future = JSONArray()
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            val windowEnd = o.optLong("windowEnd", 0)
            if (windowEnd <= now) continue
            val triggerAt = o.optLong("triggerAt", 0)
            val action = o.optString("action")
            if (triggerAt > now) {
                future.put(o)
                val code = o.optInt("code", 0)
                if (code == 0) continue
                val piIntent = Intent(ctx, LiveAlarmReceiver::class.java).apply {
                    this.action = action
                    putExtra("code", code)
                    putExtra("liveId", o.optInt("liveId"))
                    putExtra("kind", o.optString("kind"))
                    putExtra("name", o.optString("name"))
                    putExtra("location", o.optString("location"))
                    putExtra("startTs", o.optLong("startTs"))
                    putExtra("leadMin", o.optInt("leadMin"))
                    putExtra("channel", o.optString("channel"))
                    putExtra("windowEnd", windowEnd)
                }
                val pi = PendingIntent.getBroadcast(
                    ctx, code, piIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                try {
                    if (exact) {
                        am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
                    } else {
                        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
                    }
                } catch (_: Exception) {
                }
            } else if (action == LiveAlarmScheduler.ACTION_FIRE) {
                // 错过的发卡点：窗口还活着就立刻补一张
                handleEvent(
                    ctx,
                    action,
                    o.optInt("liveId"),
                    o.optString("kind"),
                    o.optString("name"),
                    o.optString("location"),
                    o.optLong("startTs"),
                    o.optInt("leadMin"),
                    o.optString("channel"),
                )
            }
        }
        try {
            LiveAlarmScheduler.prefs(ctx).edit()
                .putString("events_v1", future.toString()).apply()
        } catch (_: Exception) {
        }
    }
}
