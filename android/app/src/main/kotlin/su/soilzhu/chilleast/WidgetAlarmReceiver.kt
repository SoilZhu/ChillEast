package su.soilzhu.chilleast

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 桌面小组件定时刷新与开机恢复广播接收器。
 */
class WidgetAlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "WidgetAlarmReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val appCtx = context.applicationContext
        val action = intent.action
        Log.i(TAG, "onReceive action=$action")

        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            -> {
                WidgetAlarmScheduler.rescheduleFromPrefs(appCtx)
                HomeWidgets.updateAll(appCtx)
            }
            WidgetAlarmScheduler.ACTION_WIDGET_ALARM -> {
                HomeWidgets.updateAll(appCtx)
            }
            else -> {
                HomeWidgets.updateAll(appCtx)
            }
        }
    }
}
