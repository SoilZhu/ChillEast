package su.soilzhu.chilleast

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.util.Log
import android.widget.RemoteViews

/// 「日程 + 快捷」长条小组件：顶部下一条日程 + 底部四个快捷入口。
class ComboWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        try {
            updateAll(context)
        } catch (e: Exception) {
            Log.e(TAG, "onUpdate failed", e)
        }
    }

    companion object {
        private const val TAG = "ComboWidget"
        private const val REQ_TOP = 9200
        private const val REQ_BASE = 9210

        fun updateAll(context: Context) {
            try {
                val ids = HomeWidgets.idsFor(context, ComboWidgetProvider::class.java)
                if (ids.isEmpty()) return
                val manager = AppWidgetManager.getInstance(context)
                val views = try {
                    buildViews(context)
                } catch (e: Exception) {
                    Log.e(TAG, "buildViews failed, using default layout", e)
                    RemoteViews(context.packageName, R.layout.widget_combo)
                }
                for (id in ids) {
                    try {
                        manager.updateAppWidget(id, views)
                    } catch (e: Exception) {
                        Log.e(TAG, "updateAppWidget failed for id=$id", e)
                    }
                }
                Log.i(TAG, "updated ${ids.size} instance(s)")
            } catch (e: Exception) {
                Log.e(TAG, "updateAll failed", e)
            }
        }

        fun buildViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_combo)

            views.setOnClickPendingIntent(
                R.id.widget_combo_top,
                WidgetIntents.launchIntent(
                    context,
                    WidgetIntents.ACTION_AGENDA,
                    1,
                    REQ_TOP,
                ),
            )

            val agenda = WidgetData.readAgenda(context)
            val quick = WidgetData.readQuick(context)
            Log.i(
                TAG,
                "buildViews: agendaItems=${agenda?.items?.size ?: -1} " +
                    "quickItems=${quick?.items?.size ?: -1}",
            )
            if (agenda != null) {
                if (agenda.title.isNotEmpty()) {
                    views.setTextViewText(R.id.widget_combo_title, agenda.title)
                }
                views.setTextViewText(R.id.widget_combo_date, agenda.dateLine)
                val first = agenda.items.firstOrNull()
                if (first != null) {
                    val room = if (first.sub.isNotEmpty()) " · ${first.sub}" else ""
                    views.setTextViewText(
                        R.id.widget_combo_next,
                        "${first.title}$room",
                    )
                    views.setInt(R.id.widget_combo_bar, "setBackgroundColor", first.color)
                } else if (agenda.emptyText.isNotEmpty()) {
                    views.setTextViewText(R.id.widget_combo_next, agenda.emptyText)
                }
            }

            val btnIds = intArrayOf(
                R.id.widget_combo_btn_0,
                R.id.widget_combo_btn_1,
                R.id.widget_combo_btn_2,
                R.id.widget_combo_btn_3,
            )
            val fallbackIds = listOf("payment_code", "library", "empty_classroom", "bus")
            val fallbackLabels = listOf("付款码", "图书馆", "空教室", "实时校车")
            val fallbackEmoji = listOf("💳", "📚", "🚪", "🚌")
            for (i in btnIds.indices) {
                val item = quick?.items?.getOrNull(i)
                val action = item?.id ?: fallbackIds[i]
                val label = if (item != null) {
                    val prefix = if (item.emoji.isNotEmpty()) "${item.emoji}\n" else ""
                    "$prefix${item.label}"
                } else {
                    "${fallbackEmoji[i]}\n${fallbackLabels[i]}"
                }
                views.setTextViewText(btnIds[i], label)
                views.setOnClickPendingIntent(
                    btnIds[i],
                    WidgetIntents.launchIntent(context, action, -1, REQ_BASE + i),
                )
            }
            return views
        }
    }
}
