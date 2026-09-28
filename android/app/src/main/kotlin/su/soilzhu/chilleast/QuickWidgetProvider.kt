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

        /// 功能 id → 与 App 内 Material 图标一致的矢量图。
        fun iconResFor(id: String): Int {
            return when (id) {
                "sunshine" -> R.drawable.widget_ic_sunshine
                "questionnaire" -> R.drawable.widget_ic_questionnaire
                "leave" -> R.drawable.widget_ic_leave
                "payment_code" -> R.drawable.widget_ic_payment_code
                "recharge" -> R.drawable.widget_ic_recharge
                "library" -> R.drawable.widget_ic_library
                "empty_classroom" -> R.drawable.widget_ic_empty_classroom
                "xgxt" -> R.drawable.widget_ic_xgxt
                "repairs" -> R.drawable.widget_ic_repairs
                "gym" -> R.drawable.widget_ic_gym
                "teaching_eval" -> R.drawable.widget_ic_teaching_eval
                "score" -> R.drawable.widget_ic_score
                "vpn" -> R.drawable.widget_ic_vpn
                "campus_card" -> R.drawable.widget_ic_campus_card
                "ele_recharge" -> R.drawable.widget_ic_ele_recharge
                "bus" -> R.drawable.widget_ic_bus
                "cs_bus" -> R.drawable.widget_ic_cs_bus
                "campus_bus_route" -> R.drawable.widget_ic_campus_bus_route
                else -> R.drawable.widget_ic_payment_code
            }
        }

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

            val cellIds = intArrayOf(
                R.id.widget_quick_cell_0,
                R.id.widget_quick_cell_1,
                R.id.widget_quick_cell_2,
                R.id.widget_quick_cell_3,
            )
            val iconIds = intArrayOf(
                R.id.widget_quick_icon_0,
                R.id.widget_quick_icon_1,
                R.id.widget_quick_icon_2,
                R.id.widget_quick_icon_3,
            )
            val labelIds = intArrayOf(
                R.id.widget_quick_label_0,
                R.id.widget_quick_label_1,
                R.id.widget_quick_label_2,
                R.id.widget_quick_label_3,
            )
            // 默认缺省文案（Flutter 尚未同步时展示）
            val fallbackIds = listOf("payment_code", "library", "empty_classroom", "bus")
            val fallbackLabels = listOf("付款码", "图书馆", "空教室", "实时校车")
            val fallbackColors = listOf(
                0xFF00C853.toInt(),
                0xFF795548.toInt(),
                0xFF9C27B0.toInt(),
                0xFF34E676.toInt(),
            )

            for (i in cellIds.indices) {
                val item = data?.items?.getOrNull(i)
                val action = item?.id ?: fallbackIds[i]
                val label = item?.label ?: fallbackLabels[i]
                views.setImageViewResource(iconIds[i], iconResFor(action))
                views.setInt(iconIds[i], "setColorFilter", item?.color ?: fallbackColors[i])
                views.setTextViewText(labelIds[i], label)
                views.setOnClickPendingIntent(
                    cellIds[i],
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
