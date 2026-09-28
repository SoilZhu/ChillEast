package su.soilzhu.chilleast

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews

/// 「今日日程」小组件（2x2）：标题 + 日期 + 可上下滑动的全量未发生日程列表。
/// 数据由 Flutter 侧全量同步（作业在前、课程在后，已过滤已结束课程），
/// 原生侧通过 ListView + RemoteViewsService 展示，支持在小尺寸下滑动查看。
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
                // 先通知集合视图刷新，再逐个更新布局
                try {
                    for (id in ids) {
                        manager.notifyAppWidgetViewDataChanged(id, R.id.widget_agenda_list)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "notifyAppWidgetViewDataChanged failed", e)
                }
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
            val click = WidgetIntents.launchIntent(
                context,
                WidgetIntents.ACTION_AGENDA,
                1,
                REQ_AGENDA,
            )
            // 标题栏点击直达课表
            views.setOnClickPendingIntent(R.id.widget_agenda_root, click)

            val data = WidgetData.readAgenda(context)
            Log.i(TAG, "buildViews: items=${data?.items?.size ?: -1}")
            if (data != null) {
                if (data.title.isNotEmpty()) {
                    views.setTextViewText(R.id.widget_agenda_title, data.title)
                }
                views.setTextViewText(R.id.widget_agenda_date, data.dateLine)
                if (data.emptyText.isNotEmpty()) {
                    views.setTextViewText(R.id.widget_agenda_empty, data.emptyText)
                }
            } else {
                Log.i(TAG, "buildViews: no data, showing default layout")
            }

            // 绑定可滑动的日程列表
            val svcIntent = Intent(context, AgendaWidgetService::class.java)
            views.setRemoteAdapter(R.id.widget_agenda_list, svcIntent)
            views.setEmptyView(R.id.widget_agenda_list, R.id.widget_agenda_empty)
            // 列表行点击模板（行内通过 fillInIntent 透出动作）
            views.setPendingIntentTemplate(R.id.widget_agenda_list, click)
            return views
        }
    }
}
