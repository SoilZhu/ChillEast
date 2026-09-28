package su.soilzhu.chilleast

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.util.Log
import android.view.View
import android.widget.RemoteViews

/// 「今日日程」小组件：标题 + 日期 + 最多 3 条日程（作业在前、课程在后）。
class AgendaWidgetProvider : AppWidgetProvider() {
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
        private const val TAG = "AgendaWidget"
        private const val REQ_AGENDA = 9001

        fun updateAll(context: Context) {
            try {
                val ids = HomeWidgets.idsFor(context, AgendaWidgetProvider::class.java)
                if (ids.isEmpty()) return
                val manager = AppWidgetManager.getInstance(context)
                val views = try {
                    buildViews(context)
                } catch (e: Exception) {
                    Log.e(TAG, "buildViews failed, using default layout", e)
                    RemoteViews(context.packageName, R.layout.widget_agenda)
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
            val views = RemoteViews(context.packageName, R.layout.widget_agenda)
            views.setOnClickPendingIntent(
                R.id.widget_agenda_root,
                WidgetIntents.launchIntent(
                    context,
                    WidgetIntents.ACTION_AGENDA,
                    1,
                    REQ_AGENDA,
                ),
            )

            val data = WidgetData.readAgenda(context) ?: run {
                Log.i(TAG, "buildViews: no data, showing default layout")
                return views
            }
            Log.i(TAG, "buildViews: items=${data.items.size}")
            if (data.title.isNotEmpty()) {
                views.setTextViewText(R.id.widget_agenda_title, data.title)
            }
            views.setTextViewText(R.id.widget_agenda_date, data.dateLine)

            if (data.items.isEmpty()) {
                views.setViewVisibility(R.id.widget_agenda_empty, View.VISIBLE)
                if (data.emptyText.isNotEmpty()) {
                    views.setTextViewText(R.id.widget_agenda_empty, data.emptyText)
                }
            } else {
                views.setViewVisibility(R.id.widget_agenda_empty, View.GONE)
            }

            val barIds = intArrayOf(
                R.id.widget_agenda_bar_0,
                R.id.widget_agenda_bar_1,
                R.id.widget_agenda_bar_2,
            )
            val titleIds = intArrayOf(
                R.id.widget_agenda_item_title_0,
                R.id.widget_agenda_item_title_1,
                R.id.widget_agenda_item_title_2,
            )
            val subIds = intArrayOf(
                R.id.widget_agenda_item_sub_0,
                R.id.widget_agenda_item_sub_1,
                R.id.widget_agenda_item_sub_2,
            )
            val itemIds = intArrayOf(
                R.id.widget_agenda_item_0,
                R.id.widget_agenda_item_1,
                R.id.widget_agenda_item_2,
            )
            val click = WidgetIntents.launchIntent(
                context,
                WidgetIntents.ACTION_AGENDA,
                1,
                REQ_AGENDA,
            )
            for (i in barIds.indices) {
                if (i < data.items.size) {
                    val item = data.items[i]
                    views.setViewVisibility(itemIds[i], View.VISIBLE)
                    views.setTextViewText(titleIds[i], item.title)
                    views.setTextViewText(subIds[i], item.sub)
                    views.setInt(barIds[i], "setBackgroundColor", item.color)
                    views.setOnClickPendingIntent(itemIds[i], click)
                } else {
                    views.setViewVisibility(itemIds[i], View.GONE)
                }
            }
            return views
        }
    }
}
