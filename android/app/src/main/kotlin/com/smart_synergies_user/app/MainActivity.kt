package com.smart_synergies_user.app

import android.content.Intent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import android.os.PowerManager
import android.provider.Settings
import android.content.Context
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.smart_synergies_user.app/alarm"
    private val NOTIF_CHANNEL_ID = "alarm_channel_v2"
    private val SILENT_CHANNEL_ID = "alarm_channel_silent"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Register plugins
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAlarm" -> {
                    // Stubbed - handled in Dart via flutter_local_notifications and audioplayers
                    result.success(true)
                }
                "stopAlarm" -> {
                    // Stubbed - handled in Dart
                    result.success(true)
                }
                "checkFullScreenPermission" -> {
                    val hasPermission = checkFullScreenPermission()
                    result.success(hasPermission)
                }
                "openFullScreenSettings" -> {
                    openFullScreenSettings()
                    result.success(true)
                }
                "checkBatteryOptimization" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }
                "requestIgnoreBatteryOptimization" -> {
                    requestIgnoreBatteryOptimization()
                    result.success(true)
                }
                "openAutoStartSettings" -> {
                    openAutoStartSettings()
                    result.success(true)
                }
                "closeApp" -> {
                    finishAndRemoveTask()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra("finish", false)) {
            finishAndRemoveTask()
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        val isLauncherIntent = intent != null && 
                               Intent.ACTION_MAIN == intent.action && 
                               intent.hasCategory(Intent.CATEGORY_LAUNCHER)

        if (!isLauncherIntent) {
            val km = getSystemService(Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
            if (!km.isKeyguardLocked) {
                val isNotificationTap = intent?.hasExtra("notificationId") == true || 
                                        intent?.hasExtra("payload") == true || 
                                        intent?.hasExtra("selectNotification") == true ||
                                        intent?.action?.contains("SELECT_NOTIFICATION") == true

                if (!isNotificationTap) {
                    finish()
                    return
                }
            }
        }

        super.onCreate(savedInstanceState)
        
        // Allow the activity to be shown over the lock screen and wake the device
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        
        // Ensure volume buttons control the Alarm stream by default
        volumeControlStream = android.media.AudioManager.STREAM_ALARM
        
        createAlarmNotificationChannel()
    }

    override fun onKeyDown(keyCode: Int, event: android.view.KeyEvent?): Boolean {
        if (keyCode == android.view.KeyEvent.KEYCODE_VOLUME_UP || keyCode == android.view.KeyEvent.KEYCODE_VOLUME_DOWN) {
            val prefs = getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE)
            val isPlaying = prefs.getBoolean("flutter.alarm_playing", false)
            if (isPlaying) {
                // Return true to consume the event and prevent system volume change/silencing
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: android.view.KeyEvent?): Boolean {
        if (keyCode == android.view.KeyEvent.KEYCODE_VOLUME_UP || keyCode == android.view.KeyEvent.KEYCODE_VOLUME_DOWN) {
            val prefs = getSharedPreferences("FlutterSharedPreferences", android.content.Context.MODE_PRIVATE)
            val isPlaying = prefs.getBoolean("flutter.alarm_playing", false)
            if (isPlaying) {
                return true
            }
        }
        return super.onKeyUp(keyCode, event)
    }

    private fun checkFullScreenPermission(): Boolean {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val manager = getSystemService(NotificationManager::class.java)
            return manager?.canUseFullScreenIntent() ?: true
        }
        return true
    }

    private fun openFullScreenSettings() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val intent = Intent(android.provider.Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        }
    }

    private fun createAlarmNotificationChannel() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java) ?: return
            
            // 1. Loud channel
            if (manager.getNotificationChannel(NOTIF_CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    NOTIF_CHANNEL_ID,
                    "Critical Alerts (Loud)",
                    NotificationManager.IMPORTANCE_HIGH
                )
                // Use null for sound and vibration to rely on BackgroundAudioService
                // which uses the ALARM stream correctly.
                channel.setSound(null, null)
                channel.enableVibration(false)
                manager.createNotificationChannel(channel)
            }
            
            // 2. Silent channel
            if (manager.getNotificationChannel(SILENT_CHANNEL_ID) == null) {
                val silentChannel = NotificationChannel(
                    SILENT_CHANNEL_ID,
                    "Critical Alerts (Silent)",
                    NotificationManager.IMPORTANCE_HIGH
                )
                silentChannel.setSound(null, null)
                silentChannel.enableVibration(false)
                manager.createNotificationChannel(silentChannel)
            }
        }
    }



    private fun openAutoStartSettings() {
        val intents = arrayOf(
            Intent().setComponent(android.content.ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
            Intent().setComponent(android.content.ComponentName("com.letv.android.letvsafe", "com.letv.android.letvsafe.AutobootManageActivity")),
            Intent().setComponent(android.content.ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")),
            Intent().setComponent(android.content.ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")),
            Intent().setComponent(android.content.ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity")),
            Intent().setComponent(android.content.ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity")),
            Intent().setComponent(android.content.ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")),
            Intent().setComponent(android.content.ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager")),
            Intent().setComponent(android.content.ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")),
            Intent().setComponent(android.content.ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")),
            Intent().setComponent(android.content.ComponentName("com.htc.pitroad", "com.htc.pitroad.landingpage.activity.LandingPageActivity")),
            Intent().setComponent(android.content.ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.entry.FunctionActivity")).setData(Uri.parse("mobilemanager://function/entry/AutoStart"))
        )

        var found = false
        for (intent in intents) {
            if (packageManager.resolveActivity(intent, android.content.pm.PackageManager.MATCH_DEFAULT_ONLY) != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                found = true
                break
            }
        }

        if (!found) {
            // Fallback to app info page
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    private fun requestIgnoreBatteryOptimization() {
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
        intent.data = Uri.parse("package:$packageName")
        startActivity(intent)
    }
}
