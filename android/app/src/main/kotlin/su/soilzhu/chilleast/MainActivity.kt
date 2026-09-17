package su.soilzhu.chilleast

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val LIVE_CHANNEL = "course_live"
        private const val FLYME_CHANNEL = "flyme_live"
        private const val ALARM_CHANNEL = "live_alarm"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIVE_CHANNEL)
            .setMethodCallHandler { call, result ->
                val ctx = applicationContext
                when (call.method) {
                    "isSupported" ->
                        result.success(CourseLiveManager.isSupported())
                    "areNotificationsEnabled" ->
                        result.success(CourseLiveManager.areNotificationsEnabled(ctx))
                    "canPostPromoted" ->
                        result.success(CourseLiveManager.canPostPromoted(ctx))
                    "openPromotedSettings" ->
                        result.success(CourseLiveManager.openPromotedSettings(ctx))
                    "openNotificationSettings" ->
                        result.success(CourseLiveManager.openNotificationSettings(ctx))
                    "upsert" -> {
                        try {
                            CourseLiveManager.upsert(
                                ctx,
                                (call.argument<Int>("id") ?: 910001),
                                (call.argument<String>("title") ?: ""),
                                (call.argument<String>("text") ?: ""),
                                (call.argument<String>("shortText") ?: ""),
                                (call.argument<Int>("progress") ?: 0),
                                (call.argument<Int>("total") ?: 100),
                                (call.argument<Number>("whenMs")?.toLong() ?: 0L),
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("UPSERT_FAILED", e.message, null)
                        }
                    }
                    "cancel" -> {
                        CourseLiveManager.cancel(ctx, (call.argument<Int>("id") ?: 910001))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLYME_CHANNEL)
            .setMethodCallHandler { call, result ->
                val ctx = applicationContext
                when (call.method) {
                    "isSupported" ->
                        result.success(FlymeLiveManager.isSupported())
                    "flymeLabel" ->
                        result.success(
                            "Flyme ${FlymeLiveManager.flymeMajor()} · ${FlymeLiveManager.displayId()}",
                        )
                    "areNotificationsEnabled" ->
                        result.success(FlymeLiveManager.areNotificationsEnabled(ctx))
                    "openNotificationSettings" ->
                        result.success(FlymeLiveManager.openNotificationSettings(ctx))
                    "upsert" -> {
                        try {
                            FlymeLiveManager.upsert(
                                ctx,
                                (call.argument<Int>("id") ?: 920001),
                                (call.argument<String>("title") ?: ""),
                                (call.argument<String>("text") ?: ""),
                                (call.argument<String>("capsuleText") ?: ""),
                                (call.argument<String>("timeText") ?: ""),
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("UPSERT_FAILED", e.message, null)
                        }
                    }
                    "cancel" -> {
                        FlymeLiveManager.cancel(ctx, (call.argument<Int>("id") ?: 920001))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                val ctx = applicationContext
                when (call.method) {
                    "program" -> {
                        val count = LiveAlarmScheduler.program(
                            ctx, (call.argument<String>("events") ?: "[]"),
                        )
                        result.success(count)
                    }
                    "cancelAll" -> {
                        LiveAlarmScheduler.cancelAll(ctx)
                        result.success(true)
                    }
                    "cancelCard" -> {
                        LiveAlarmScheduler.cancelCard(
                            ctx, (call.argument<Int>("id") ?: 0),
                        )
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
