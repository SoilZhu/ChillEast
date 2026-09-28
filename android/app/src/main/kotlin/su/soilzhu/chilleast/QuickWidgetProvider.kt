package su.soilzhu.chilleast

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.util.Log
import android.widget.RemoteViews

/// 「快捷功能」小组件：2x2 四个入口，点击直达对应功能页。
class QuickWidgetProvider : AppWidgetProvider() {
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
        private const val TAG = "QuickWidget"
        private const val REQ_BASE = 9100

        fun updateAll(context: Context) {
            try {
                val ids = HomeWidgets.idsFor(context, QuickWidgetProvider::class.java)
                if (ids.isEmpty()) return
                val manager = AppWidgetManager.getInstance(context)
                val views = try {
                    buildViews(context)
                } catch (e: Exception) {
                    Log.e(TAG, "buildViews failed, using default layout", e)
                    RemoteViews(context.packageName, R.layout.widget_quick)
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
            val views = RemoteViews(context.packageName, R.layout.widget_quick)
            val data = WidgetData.readQuick(context)
            Log.i(TAG, "buildViews: items=${data?.items?.size ?: 0}")

            val btnIds = intArrayOf(
                R.id.widget_quick_btn_0,
                R.id.widget_quick_btn_1,
                R.id.widget_quick_btn_2,
                R.id.widget_quick_btn_3,
            )
            // 默认缺省文案（Flutter 尚未同步时展示）
            val fallbackIds = listOf("payment_code", "library", "empty_classroom", "bus")
            val fallbackLabels = listOf("付款码", "图书馆", "空教室", "实时校车")
            val fallbackEmoji = listOf("💳", "📚", "🚪", "🚌")

            for (i in btnIds.indices) {
                val item = data?.items?.getOrNull(i)
                val action = item?.id ?: fallbackIds[i]
                val label = if (item != null) {
                    val prefix = if (item.emoji.isNotEmpty()) "${item.emoji} " else ""
                    "$prefix${item.label}"
                } else {
                    "${fallbackEmoji[i]} ${fallbackLabels[i]}"
                }
                views.setTextViewText(btnIds[i], label)
                views.setOnClickPendingIntent(
                    btnIds[i],
                    WidgetIntents.launchIntent(context, action, -1, REQ_BASE + i),
                )
            }
            if (data != null && data.title.isNotEmpty()) {
                views.setTextViewText(R.id.widget_quick_title, data.title)
            }
            return views
        }
    }
}
