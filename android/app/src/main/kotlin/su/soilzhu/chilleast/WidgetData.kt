package su.soilzhu.chilleast

import android.content.Context
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale

data class AgendaItem(
    val kind: String,
    val title: String,
    val room: String,
    val sub: String,
    val color: Int,
    val endTimeMs: Long = 0,
)

data class AgendaData(
    val title: String,
    val dateLine: String,
    val isTomorrow: Boolean,
    val emptyText: String,
    val items: List<AgendaItem>,
)

data class QuickItem(
    val id: String,
    val label: String,
    val emoji: String,
    val color: Int,
)

data class QuickData(
    val title: String,
    val items: List<QuickItem>,
)

/// 读取 Flutter 侧写入 SharedPreferences 的小组件 JSON。
/// shared_preferences 插件约定：文件名为 FlutterSharedPreferences，
/// key 带有 flutter. 前缀（同时兼容无前缀写入，便于调试）。
object WidgetData {
    private const val PREFS = "FlutterSharedPreferences"
    const val AGENDA_KEY = "widget_agenda_json"
    const val QUICK_KEY = "widget_quick_json"

    private fun raw(context: Context, key: String): String? {
        val sp = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return sp.getString("flutter.$key", null) ?: sp.getString(key, null)
    }

    fun readAgenda(context: Context): AgendaData? {
        return try {
            val text = raw(context, AGENDA_KEY) ?: return null
            val json = JSONObject(text)
            val now = System.currentTimeMillis()
            val cal = Calendar.getInstance().apply { timeInMillis = now }
            val hour = cal.get(Calendar.HOUR_OF_DAY)
            val isTomorrow = hour >= 22

            val daysArr = json.optJSONArray("days")
            if (daysArr != null && daysArr.length() > 0) {
                // 多日动态日程逻辑
                if (isTomorrow) {
                    cal.add(Calendar.DAY_OF_YEAR, 1)
                }
                val targetDateStr = String.format(
                    Locale.US,
                    "%04d-%02d-%02d",
                    cal.get(Calendar.YEAR),
                    cal.get(Calendar.MONTH) + 1,
                    cal.get(Calendar.DAY_OF_MONTH),
                )

                var matchedDay: JSONObject? = null
                for (i in 0 until daysArr.length()) {
                    val d = daysArr.optJSONObject(i) ?: continue
                    if (d.optString("date") == targetDateStr) {
                        matchedDay = d
                        break
                    }
                }

                val title = if (isTomorrow) {
                    json.optString("tomorrowTitle", "明日日程")
                } else {
                    json.optString("todayTitle", "今日日程")
                }
                val emptyText = if (isTomorrow) {
                    json.optString("tomorrowEmptyText", "明日暂无日程")
                } else {
                    json.optString("todayEmptyText", "今日暂无日程")
                }

                if (matchedDay == null) {
                    return AgendaData(
                        title = title,
                        dateLine = "",
                        isTomorrow = isTomorrow,
                        emptyText = emptyText,
                        items = emptyList(),
                    )
                }

                val dateLine = matchedDay.optString("dateLine", "")
                val itemsArr = matchedDay.optJSONArray("items")
                val items = mutableListOf<AgendaItem>()
                if (itemsArr != null) {
                    for (i in 0 until itemsArr.length()) {
                        val o = itemsArr.optJSONObject(i) ?: continue
                        val endMs = o.optLong("endTimeMs", 0L)
                        // 若展示的是今天日程，过滤掉已下课的课程
                        if (!isTomorrow && endMs > 0 && endMs <= now) {
                            continue
                        }
                        items.add(
                            AgendaItem(
                                kind = o.optString("kind", "course"),
                                title = o.optString("title", ""),
                                room = o.optString("room", ""),
                                sub = o.optString("sub", ""),
                                color = o.optInt("color", 0xFF09C489.toInt()),
                                endTimeMs = endMs,
                            ),
                        )
                    }
                }

                return AgendaData(
                    title = title,
                    dateLine = dateLine,
                    isTomorrow = isTomorrow,
                    emptyText = emptyText,
                    items = items,
                )
            }

            // 回退兼容：单日老格式 JSON
            val items = mutableListOf<AgendaItem>()
            val arr = json.optJSONArray("items") ?: return null
            val legacyIsTomorrow = json.optBoolean("isTomorrow", false)
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                val endMs = o.optLong("endTimeMs", 0L)
                if (!legacyIsTomorrow && endMs > 0 && endMs <= now) {
                    continue
                }
                items.add(
                    AgendaItem(
                        kind = o.optString("kind", "course"),
                        title = o.optString("title", ""),
                        room = o.optString("room", ""),
                        sub = o.optString("sub", ""),
                        color = o.optInt("color", 0xFF09C489.toInt()),
                        endTimeMs = endMs,
                    ),
                )
            }
            AgendaData(
                title = json.optString("title", ""),
                dateLine = json.optString("dateLine", ""),
                isTomorrow = legacyIsTomorrow,
                emptyText = json.optString("emptyText", ""),
                items = items,
            )
        } catch (e: Exception) {
            null
        }
    }

    fun readQuick(context: Context): QuickData? {
        return try {
            val text = raw(context, QUICK_KEY) ?: return null
            val json = JSONObject(text)
            val items = mutableListOf<QuickItem>()
            val arr = json.optJSONArray("items") ?: return null
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                val id = o.optString("id", "")
                if (id.isEmpty()) continue
                items.add(
                    QuickItem(
                        id = id,
                        label = o.optString("label", id),
                        emoji = o.optString("emoji", ""),
                        color = o.optInt("color", 0xFF09C489.toInt()),
                    ),
                )
            }
            QuickData(
                title = json.optString("title", ""),
                items = items,
            )
        } catch (e: Exception) {
            null
        }
    }
}
