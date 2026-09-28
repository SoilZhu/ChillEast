package su.soilzhu.chilleast

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews

/// 「日程 + 快捷」4x2 组合小组件：左 2 格日程（标题 + 可滑动列表，复用今日日程样式），
/// 右 2 格快捷 2x2（大图标 + 功能名，复用快捷功能样式）。
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
                try {
                    for (id in ids) {
                        manager.notifyAppWidgetViewDataChanged(id, R.id.widget_combo_agenda_list)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "notifyAppWidgetViewDataChanged failed", e)
                }
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

            val agendaClick = WidgetIntents.launchIntent(
                context,
                WidgetIntents.ACTION_AGENDA,
                1,
                REQ_TOP,
            )
            // 左侧日程区点击直达课表
            views.setOnClickPendingIntent(R.id.widget_combo_agenda_panel, agendaClick)

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
                if (agenda.emptyText.isNotEmpty()) {
                    views.setTextViewText(R.id.widget_combo_agenda_empty, agenda.emptyText)
                }
            }

            // 左侧可滑动的日程列表（与今日日程同数据源同样式）
            val svcIntent = Intent(context, AgendaWidgetService::class.java)
            views.setRemoteAdapter(R.id.widget_combo_agenda_list, svcIntent)
            views.setEmptyView(R.id.widget_combo_agenda_list, R.id.widget_combo_agenda_empty)
            views.setPendingIntentTemplate(R.id.widget_combo_agenda_list, agendaClick)

            // 右侧快捷 2x2（与快捷功能同图标同配色）
            val cellIds = intArrayOf(
                R.id.widget_combo_cell_0,
                R.id.widget_combo_cell_1,
                R.id.widget_combo_cell_2,
                R.id.widget_combo_cell_3,
            )
            val iconIds = intArrayOf(
                R.id.widget_combo_icon_0,
                R.id.widget_combo_icon_1,
                R.id.widget_combo_icon_2,
                R.id.widget_combo_icon_3,
            )
            val labelIds = intArrayOf(
                R.id.widget_combo_label_0,
                R.id.widget_combo_label_1,
                R.id.widget_combo_label_2,
                R.id.widget_combo_label_3,
            )
            val fallbackIds = listOf("payment_code", "library", "empty_classroom", "bus")
            val fallbackLabels = listOf("付款码", "图书馆", "空教室", "实时校车")
            val fallbackColors = listOf(
                0xFF00C853.toInt(),
                0xFF795548.toInt(),
                0xFF9C27B0.toInt(),
                0xFF34E676.toInt(),
            )
            for (i in cellIds.indices) {
                val item = quick?.items?.getOrNull(i)
                val action = item?.id ?: fallbackIds[i]
                val label = item?.label ?: fallbackLabels[i]
                views.setImageViewResource(iconIds[i], QuickWidgetProvider.iconResFor(action))
                views.setInt(iconIds[i], "setColorFilter", item?.color ?: fallbackColors[i])
                views.setTextViewText(labelIds[i], label)
                views.setOnClickPendingIntent(
                    cellIds[i],
                    WidgetIntents.launchIntent(context, action, -1, REQ_BASE + i),
                )
            }
            return views
        }
    }
}
