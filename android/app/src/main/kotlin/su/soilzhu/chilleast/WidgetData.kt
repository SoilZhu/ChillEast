package su.soilzhu.chilleast

import android.content.Context
import org.json.JSONObject

data class AgendaItem(
    val kind: String,
    val title: String,
    val sub: String,
    val color: Int,
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
            val items = mutableListOf<AgendaItem>()
            val arr = json.optJSONArray("items") ?: return null
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                items.add(
                    AgendaItem(
                        kind = o.optString("kind", "course"),
                        title = o.optString("title", ""),
                        sub = o.optString("sub", ""),
                        color = o.optInt("color", 0xFF09C489.toInt()),
                    ),
                )
            }
            AgendaData(
                title = json.optString("title", ""),
                dateLine = json.optString("dateLine", ""),
                isTomorrow = json.optBoolean("isTomorrow", false),
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
                    ),
                )
            }
            if (items.isEmpty()) return null
            QuickData(
                title = json.optString("title", ""),
                items = items,
            )
        } catch (e: Exception) {
            null
        }
    }
}
