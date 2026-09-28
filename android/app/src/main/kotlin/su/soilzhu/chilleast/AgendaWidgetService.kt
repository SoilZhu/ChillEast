package su.soilzhu.chilleast

import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService

/// 「今日日程」列表数据源：把 Flutter 同步的全量未发生日程逐条展示，
/// 配合 ListView 实现 2x2 小尺寸下的上下滑动。
class AgendaWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return AgendaViewsFactory(applicationContext)
    }
}

private class AgendaViewsFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {
    private var items: List<AgendaItem> = emptyList()

    override fun onCreate() {
        reload()
    }

    override fun onDataSetChanged() {
        reload()
    }

    private fun reload() {
        try {
            items = WidgetData.readAgenda(context)?.items ?: emptyList()
        } catch (e: Exception) {
            Log.e(TAG, "reload failed", e)
            items = emptyList()
        }
    }

    override fun onDestroy() {
        items = emptyList()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews? {
        if (position < 0 || position >= items.size) return null
        val item = items[position]
        return try {
            val row = RemoteViews(context.packageName, R.layout.widget_agenda_row)
            row.setTextViewText(R.id.widget_agenda_row_title, item.title)
            row.setTextViewText(R.id.widget_agenda_row_sub, item.sub)
            if (item.room.isNotEmpty()) {
                row.setViewVisibility(R.id.widget_agenda_row_room, View.VISIBLE)
                row.setTextViewText(R.id.widget_agenda_row_room, "@${item.room}")
            } else {
                row.setViewVisibility(R.id.widget_agenda_row_room, View.GONE)
            }
            if (item.kind == "homework") {
                // 对齐课表日程页的作业卡片：浅黄底 + 深色字 + 橙色竖条（呼应页内橙色图标）
                val night = isNightMode()
                row.setInt(
                    R.id.widget_agenda_row_root,
                    "setBackgroundColor",
                    if (night) HW_BG_DARK else HW_BG_LIGHT,
                )
                row.setTextColor(
                    R.id.widget_agenda_row_title,
                    if (night) HW_TITLE_DARK else HW_TITLE_LIGHT,
                )
                row.setTextColor(
                    R.id.widget_agenda_row_room,
                    if (night) HW_SUB_DARK else HW_SUB_LIGHT,
                )
                row.setTextColor(
                    R.id.widget_agenda_row_sub,
                    if (night) HW_SUB_DARK else HW_SUB_LIGHT,
                )
                row.setViewVisibility(R.id.widget_agenda_row_bar, View.VISIBLE)
                row.setInt(R.id.widget_agenda_row_bar, "setBackgroundColor", item.color)
            } else {
                // 对齐课表日程页的课程卡片：满底色课程色 + 白字（深浅模式同色）
                row.setInt(R.id.widget_agenda_row_root, "setBackgroundColor", item.color)
                row.setTextColor(R.id.widget_agenda_row_title, 0xFFFFFFFF.toInt())
                row.setTextColor(R.id.widget_agenda_row_room, 0xFFFFFFFF.toInt())
                row.setTextColor(R.id.widget_agenda_row_sub, 0xFFFFFFFF.toInt())
                row.setViewVisibility(R.id.widget_agenda_row_bar, View.GONE)
            }
            val fillIn = Intent().apply {
                putExtra(WidgetIntents.EXTRA_ACTION, WidgetIntents.ACTION_AGENDA)
                putExtra(WidgetIntents.EXTRA_TAB, 1)
            }
            row.setOnClickFillInIntent(R.id.widget_agenda_row_bar, fillIn)
            // 整行可点：给标题/副标题同样设置 fillIn，保证点击行内任意位置都响应
            row.setOnClickFillInIntent(R.id.widget_agenda_row_title, fillIn)
            row.setOnClickFillInIntent(R.id.widget_agenda_row_room, fillIn)
            row.setOnClickFillInIntent(R.id.widget_agenda_row_sub, fillIn)
            row.setOnClickFillInIntent(R.id.widget_agenda_row_root, fillIn)
            row
        } catch (e: Exception) {
            Log.e(TAG, "getViewAt($position) failed", e)
            null
        }
    }

    private fun isNightMode(): Boolean {
        val mode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        return mode == Configuration.UI_MODE_NIGHT_YES
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true

    companion object {
        private const val TAG = "AgendaWidgetService"

        // 作业卡片配色与课表日程页一致（浅黄 / 深黄，深浅模式切换）
        private val HW_BG_LIGHT = 0xFFFFF9E6.toInt()
        private val HW_BG_DARK = 0xFF3D3D29.toInt()
        private val HW_TITLE_LIGHT = 0xFF2D3436.toInt()
        private val HW_TITLE_DARK = 0xFFFFFFFF.toInt()
        private val HW_SUB_LIGHT = 0xFF7F8C8D.toInt()
        private val HW_SUB_DARK = 0xFFB3B3B3.toInt()
    }
}
