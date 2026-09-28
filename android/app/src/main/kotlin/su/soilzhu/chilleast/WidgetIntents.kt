package su.soilzhu.chilleast

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/// 小组件点击意图：统一拉起 MainActivity 并透出动作，
/// Flutter 侧经 home_widget 通道取走后路由到对应 tab / 功能页。
object WidgetIntents {
    const val EXTRA_ACTION = "widget_action"
    const val EXTRA_TAB = "widget_tab"

    /** 日程主体点击：打开课表 tab（1） */
    const val ACTION_AGENDA = "agenda"

    fun launchIntent(
        context: Context,
        action: String,
        tab: Int,
        requestCode: Int,
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            putExtra(EXTRA_ACTION, action)
            putExtra(EXTRA_TAB, tab)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

/// 统一刷新三个小组件（供 MainActivity 的 home_widget 通道调用）。
object HomeWidgets {
    fun updateAll(context: Context) {
        AgendaWidgetProvider.updateAll(context)
        QuickWidgetProvider.updateAll(context)
        ComboWidgetProvider.updateAll(context)
    }

    fun idsFor(
        context: Context,
        provider: Class<*>,
    ): IntArray {
        val manager = AppWidgetManager.getInstance(context)
        return manager.getAppWidgetIds(ComponentName(context, provider))
    }
}
